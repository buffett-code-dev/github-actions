# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'yaml'
require_relative 'review_status'

class CiGateTest < Minitest::Test
  class FakeStatus < ReviewStatus
    attr_accessor :prs, :pages, :fail_endpoint
    attr_reader :calls, :comments

    def initialize(**options)
      super
      @calls = []
      @comments = []
    end

    private

    def request(endpoint, body = nil, options = [], method: nil)
      @calls << [endpoint, body, options + (method ? [method] : [])]
      raise Error, 'GitHub API の呼び出しに失敗しました' if endpoint.include?(@fail_endpoint || 'never-match')

      if body
        @comments << body.fetch('body')
        { 'id' => 99 }
      elsif endpoint.end_with?('/pulls/42')
        @prs.size > 1 ? @prs.shift : @prs.first
      else
        @pages.size > 1 ? @pages.shift : @pages.first
      end
    end
  end

  def setup
    @directory = Dir.mktmpdir
    @env = {
      'GITHUB_REPOSITORY' => 'example/project', 'GITHUB_SERVER_URL' => 'https://github.com',
      'GITHUB_RUN_ID' => '123', 'GITHUB_OUTPUT' => File.join(@directory, 'output'),
      'PR_NUMBER' => '42', 'PR_HEAD_SHA' => 'abc123', 'PR_BASE_REF' => 'development',
      'CI_WORKFLOW' => 'ci.yml', 'CI_WAIT_TIMEOUT_SECONDS' => '90',
      'CI_START_TIMEOUT_SECONDS' => '60', 'CI_POLL_INTERVAL_SECONDS' => '30',
      'CI_BASE_BRANCHES' => 'development, master',
      'REVIEW_OUTCOME' => 'success', 'REVIEW_CONCLUSION' => 'success'
    }
    @pr = {
      'number' => 42, 'head' => { 'sha' => 'abc123' }, 'base' => { 'ref' => 'development' },
      'state' => 'open', 'labels' => [{ 'name' => 'claude-review' }]
    }
    @run = {
      'run_number' => 100, 'status' => 'completed', 'conclusion' => 'success',
      'html_url' => 'https://github.com/example/project/actions/runs/456', 'pull_requests' => [@pr]
    }
    @now = 0
    @sleeps = []
    @status = FakeStatus.new(env: @env, clock: -> { @now }, sleeper: ->(seconds) { @sleeps << seconds; @now += seconds })
    @status.prs = [@pr]
    @status.pages = [pages(@run)]
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def pages(*runs)
    [{ 'workflow_runs' => runs }]
  end

  def wait
    capture_io { @status.wait }
  end

  def blocked(message)
    capture_io do
      error = assert_raises(ReviewStatus::Error) { @status.wait }
      assert_includes error.message, message
    end
    assert_includes @status.comments.last, message
  end

  def test_already_successful_ci_starts_review_without_sleep
    wait
    assert_empty @sleeps
    assert_includes @status.comments.last, 'レビュー中'
    assert_includes @status.comments.last, @run['html_url']
    assert_equal "comment_id=99\nci_url=#{@run['html_url']}\n", File.read(@env['GITHUB_OUTPUT'])
    assert_equal 1, @status.calls.count { |endpoint, body, _| endpoint.end_with?('/42/comments') && body }
    assert @status.calls.any? { |_, _, options| options.include?('PATCH') }
  end

  def test_running_ci_waits_until_success
    @status.pages = [pages(@run.merge('status' => 'queued')), pages(@run.merge('status' => 'in_progress')), pages(@run)]
    wait
    assert_equal [30, 30], @sleeps
    assert_equal 1, @status.comments.count { |body| body.include?('CI 完了待ちです') }
    assert_includes @status.comments.last, 'レビュー中'
  end

  def test_ci_creation_can_be_delayed
    @status.pages = [pages, pages(@run)]
    wait
    assert_equal [30], @sleeps
    assert @status.comments.any? { |body| body.include?('CI の開始待ち') }
  end

  def test_running_rerun_with_previous_success_does_not_pass
    @status.pages = [pages(@run.merge('status' => 'in_progress'))]
    blocked('タイムアウト')
    assert_equal [30, 30, 30], @sleeps
  end

  def test_latest_run_across_pages_is_used
    latest = @run.merge('run_number' => 101, 'conclusion' => 'failure')
    @status.pages = [[{ 'workflow_runs' => [@run] }, { 'workflow_runs' => [latest] }]]
    blocked('failure')
  end

  def test_successful_latest_run_supersedes_failure
    @status.pages = [pages(@run.merge('conclusion' => 'failure'), @run.merge('run_number' => 101))]
    wait
    assert_includes @status.comments.last, 'レビュー中'
  end

  %w[failure cancelled skipped timed_out action_required neutral stale].each do |conclusion|
    define_method("test_ci_#{conclusion}_is_reported") do
      @status.pages = [pages(@run.merge('conclusion' => conclusion))]
      blocked(conclusion)
      assert_empty @sleeps
    end
  end

  def test_missing_ci_has_bounded_start_grace
    @status.pages = [pages]
    blocked('CI が開始されませんでした')
    assert_equal [30, 30], @sleeps
  end

  def test_wait_timeout_can_be_shorter_than_start_grace
    @env['CI_WAIT_TIMEOUT_SECONDS'] = '10'
    @status.pages = [pages]
    blocked('タイムアウト')
    assert_equal [10], @sleeps
  end

  def test_unrelated_runs_cannot_satisfy_gate
    @status.pages = [pages(
      @run.merge('pull_requests' => []),
      @run.merge('pull_requests' => [@pr.merge('number' => 43)]),
      @run.merge('pull_requests' => [@pr.merge('base' => { 'ref' => 'other' })])
    )]
    blocked('CI が開始されませんでした')
  end

  def test_unsupported_base_does_not_wait
    @env['CI_BASE_BRANCHES'] = 'master'
    blocked('CI の対象外')
    assert_empty @sleeps
  end

  def test_no_branch_restriction_and_workflow_id
    @env['CI_BASE_BRANCHES'] = ''
    @env['CI_WORKFLOW'] = '1234'
    wait
    assert @status.calls.any? { |endpoint, _, _| endpoint.include?('/workflows/1234/runs') }
  end

  def test_ci_is_optional_but_notifications_are_not
    @env['CI_WORKFLOW'] = ''
    wait
    refute @status.calls.any? { |endpoint, _, _| endpoint.end_with?('/runs') }
    assert_includes @status.comments.last, 'レビュー中'
  end

  def test_head_change_while_waiting_stops_request
    @status.pages = [pages(@run.merge('status' => 'in_progress'))]
    @status.prs = [@pr, @pr.merge('head' => { 'sha' => 'new-sha' })]
    blocked('PR が更新されました')
    assert_equal [30], @sleeps
  end

  def test_base_change_after_ci_stops_request
    @status.prs = [@pr, @pr.merge('base' => { 'ref' => 'master' })]
    blocked('PR が更新されました')
  end

  def test_closed_pr
    @status.prs = [@pr.merge('state' => 'closed')]
    blocked('クローズ')
  end

  def test_removed_label
    @status.prs = [@pr.merge('labels' => [])]
    blocked('ラベルが外された')
  end

  def test_api_failure_is_reported_on_pr
    @status.fail_endpoint = '/workflows/'
    blocked('GitHub API')
    assert_includes @status.comments.last, '/actions/runs/123'
  end

  def test_notification_failure_stops_review_and_prints_warning
    @status.fail_endpoint = '/comments'
    output, errors = capture_io do
      assert_raises(ReviewStatus::Error) { @status.wait }
    end
    assert_includes output, '::error::'
    assert_includes errors, 'PR への状態通知に失敗'
    refute @status.calls.any? { |endpoint, _, _| endpoint.end_with?('/runs') }
  end

  def test_invalid_timeout_is_reported
    @env['CI_WAIT_TIMEOUT_SECONDS'] = '0'
    blocked('正の整数')
  end

  def test_review_success_updates_existing_comment
    @env['COMMENT_ID'] = '99'
    @env['CI_URL'] = @run['html_url']
    status = FakeStatus.new(env: @env)
    status.prs = [@pr]
    capture_io { status.finish }
    assert_includes status.comments.last, 'レビュー処理が完了'
    assert_includes status.comments.last, '結果が投稿されていない場合は Actions のログを確認'
    assert_includes status.comments.last, @run['html_url']
    assert status.calls.any? { |endpoint, _, _| endpoint.end_with?('/comments/99') }
  end

  def test_review_failure_and_setup_failure_are_reported
    %w[failure skipped].each do |outcome|
      @env['REVIEW_OUTCOME'] = outcome
      capture_io { assert_raises(ReviewStatus::Error) { @status.finish } }
      assert_includes @status.comments.last, 'レビューの実行に失敗'
    end
  end

  def test_claude_failure_conclusion_is_not_reported_as_success
    @env['REVIEW_CONCLUSION'] = 'failure'
    capture_io { assert_raises(ReviewStatus::Error) { @status.finish } }
    assert_includes @status.comments.last, 'レビューの実行に失敗'
  end

  def test_review_cancelled
    @env['JOB_CANCELLED'] = 'true'
    capture_io { assert_raises(ReviewStatus::Error) { @status.finish } }
    assert_includes @status.comments.last, 'キャンセル'
  end

  def test_head_changed_during_review
    @status.prs = [@pr.merge('head' => { 'sha' => 'new-sha' })]
    capture_io { assert_raises(ReviewStatus::Error) { @status.finish } }
    assert_includes @status.comments.last, 'PR が更新されました'
  end

  def test_wait_interrupt_is_reported
    @status = FakeStatus.new(env: @env, clock: -> { @now }, sleeper: ->(_) { raise Interrupt })
    @status.prs = [@pr]
    @status.pages = [pages(@run.merge('status' => 'in_progress'))]
    capture_io { assert_raises(Interrupt) { @status.wait } }
    assert_includes @status.comments.last, 'キャンセル'
  end

  def test_current_label_name_is_used
    @env['REVIEW_LABEL'] = 'custom-review'
    @pr['labels'] = [{ 'name' => 'custom-review' }]
    @status = FakeStatus.new(env: @env)
    @status.prs = [@pr]
    @status.pages = [pages(@run)]
    wait
    assert_includes @status.comments.last, 'レビュー中'
  end

  def test_api_updates_comment_with_json_and_one_patch_method
    success = Minitest::Mock.new
    success.expect(:success?, true)
    api = lambda do |*args, **options|
      assert_equal ['gh', 'api', 'repos/example/project/issues/comments/99', '--method', 'PATCH', '--input', '-'], args
      assert_equal({ 'body' => "改行\n`引用`" }, JSON.parse(options.fetch(:stdin_data)))
      ['{"id":99}', success]
    end
    Open3.stub(:capture2, api) do
      status = ReviewStatus.new(env: @env)
      assert_equal({ 'id' => 99 }, status.send(:request, 'repos/example/project/issues/comments/99',
                                            { 'body' => "改行\n`引用`" }, method: 'PATCH'))
    end
    success.verify
  end

  def test_action_wires_wait_before_checkout_and_final_notification_always
    action = YAML.safe_load(File.read(File.join(__dir__, 'action.yml')))
    steps = action.fetch('runs').fetch('steps')
    assert_equal 'ci-gate', steps.first.fetch('id')
    assert_includes steps.first.fetch('run'), 'review_status.rb" wait'
    assert_equal '${{ inputs.ci_wait_timeout_seconds }}', steps.first.fetch('env').fetch('CI_WAIT_TIMEOUT_SECONDS')
    assert_equal '${{ steps.ci-gate.outputs.comment_id }}', steps.last.fetch('env').fetch('COMMENT_ID')
    normal = steps.find { |step| step['id'] == 'notify-finished' }
    cancelled = steps.find { |step| step['id'] == 'notify-cancelled' }
    assert_includes normal.fetch('if'), 'always() && !cancelled()'
    assert_equal 'false', normal.fetch('env').fetch('JOB_CANCELLED')
    assert_includes cancelled.fetch('if'), 'cancelled()'
    assert_equal 'true', cancelled.fetch('env').fetch('JOB_CANCELLED')
    assert_equal 'claude', steps[-3].fetch('id')
    steps.each do |step|
      step.fetch('env', {}).each_value do |value|
        refute_match(/\b(always|failure|cancelled|success)\s*\(/, value, 'Status functions are only allowed in step-if')
      end
    end
  end
end
