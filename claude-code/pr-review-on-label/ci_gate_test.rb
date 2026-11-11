# frozen_string_literal: true

require 'json'
require 'minitest/autorun'
require 'open3'
require 'tmpdir'
require 'yaml'

# Exercise the actual composite step without calling GitHub or Claude.
class CiGateTest < Minitest::Test
  def setup
    @action = YAML.safe_load(File.read(File.join(__dir__, 'action.yml')))
    @step = @action.fetch('runs').fetch('steps').find { |step| step['id'] == 'ci-gate' }
    @pr = { 'number' => 42, 'head' => { 'sha' => 'abc123' }, 'base' => { 'ref' => 'main' } }
    @run = {
      'run_number' => 100, 'status' => 'completed', 'conclusion' => 'success',
      'pull_requests' => [@pr]
    }
  end

  def run_gate(pages: [{ 'workflow_runs' => [@run] }], current_pr: @pr,
               workflow: 'checks.yml', runs_exit: 0, pr_exit: 0)
    Dir.mktmpdir do |directory|
      stub = File.join(directory, 'gh')
      File.write(stub, <<~'SH')
        #!/bin/sh
        case "$*" in
          "api repos/example/project/actions/workflows/$CI_WORKFLOW/runs --method GET --paginate --slurp -f event=pull_request -f head_sha=abc123")
            printf '%s' "$CI_PAGES"
            exit "$RUNS_EXIT"
            ;;
          "api repos/example/project/pulls/42")
            printf '%s' "$CURRENT_PR"
            exit "$PR_EXIT"
            ;;
          *) exit 2 ;;
        esac
      SH
      File.chmod(0o755, stub)
      env = {
        'PATH' => "#{directory}:#{ENV.fetch('PATH')}",
        'GITHUB_REPOSITORY' => 'example/project',
        'PR_NUMBER' => '42',
        'PR_HEAD_SHA' => 'abc123',
        'PR_BASE_REF' => 'main',
        'CI_WORKFLOW' => workflow,
        'CI_PAGES' => pages.to_json,
        'CURRENT_PR' => current_pr.to_json,
        'RUNS_EXIT' => runs_exit.to_s,
        'PR_EXIT' => pr_exit.to_s
      }
      Open3.capture2e(env, RbConfig.ruby, '-e', @step.fetch('run'))
    end
  end

  def assert_blocked(message, **options)
    output, status = run_gate(**options)
    refute status.success?, output
    assert_includes output, message
  end

  def test_ci_check_is_opt_in_and_precedes_checkout_and_claude
    assert_equal '', @action.fetch('inputs').fetch('ci_workflow').fetch('default')
    assert_equal "inputs.ci_workflow != ''", @step.fetch('if')
    assert_equal @step, @action.fetch('runs').fetch('steps').first
    assert_equal '${{ inputs.github_token }}', @step.fetch('env').fetch('GH_TOKEN')
    assert_equal '${{ inputs.ci_workflow }}', @step.fetch('env').fetch('CI_WORKFLOW')
  end

  def test_success_for_configured_workflow
    output, status = run_gate
    assert status.success?, output
  end

  def test_workflow_id
    output, status = run_gate(workflow: '123456')
    assert status.success?, output
  end

  def test_latest_run_across_pages_is_used
    latest = @run.merge('run_number' => 101, 'status' => 'in_progress', 'conclusion' => nil)
    assert_blocked('未完了または未実行', pages: [{ 'workflow_runs' => [@run] }, { 'workflow_runs' => [latest] }])
  end

  def test_successful_latest_run_supersedes_failure
    latest = @run.merge('run_number' => 101)
    output, status = run_gate(pages: [{ 'workflow_runs' => [latest, @run.merge('conclusion' => 'failure')] }])
    assert status.success?, output
  end

  def test_rerun_in_progress_is_blocked_even_with_previous_success_conclusion
    assert_blocked('未完了または未実行',
                   pages: [{ 'workflow_runs' => [@run.merge('status' => 'in_progress')] }])
  end

  def test_failure
    assert_blocked('failure', pages: [{ 'workflow_runs' => [@run.merge('conclusion' => 'failure')] }])
  end

  def test_cancelled
    assert_blocked('cancelled', pages: [{ 'workflow_runs' => [@run.merge('conclusion' => 'cancelled')] }])
  end

  def test_skipped
    assert_blocked('skipped', pages: [{ 'workflow_runs' => [@run.merge('conclusion' => 'skipped')] }])
  end

  def test_no_runs
    assert_blocked('未完了または未実行', pages: [{ 'workflow_runs' => [] }])
  end

  def test_other_pr
    unrelated = @run.merge('pull_requests' => [@pr.merge('number' => 43)])
    assert_blocked('未完了または未実行', pages: [{ 'workflow_runs' => [unrelated] }])
  end

  def test_other_base_branch
    unrelated = @run.merge('pull_requests' => [@pr.merge('base' => { 'ref' => 'release' })])
    assert_blocked('未完了または未実行', pages: [{ 'workflow_runs' => [unrelated] }])
  end

  def test_run_without_associated_pr
    assert_blocked('未完了または未実行', pages: [{ 'workflow_runs' => [@run.merge('pull_requests' => [])] }])
  end

  def test_new_head_after_ci
    assert_blocked('ラベル付与後に PR が更新されました', current_pr: @pr.merge('head' => { 'sha' => 'def456' }))
  end

  def test_new_base_after_ci
    assert_blocked('ラベル付与後に PR が更新されました', current_pr: @pr.merge('base' => { 'ref' => 'release' }))
  end

  def test_ci_api_failure
    assert_blocked('CI の実行結果を取得できませんでした', runs_exit: 1)
  end

  def test_pr_api_failure
    assert_blocked('PR の最新状態を取得できませんでした', pr_exit: 1)
  end
end
