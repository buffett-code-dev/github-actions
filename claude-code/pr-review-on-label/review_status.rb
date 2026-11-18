# frozen_string_literal: true

require 'json'
require 'open3'

# This script lives in the downloaded Action, outside the PR checkout.
class ReviewStatus
  class Error < StandardError; end

  def initialize(env: ENV, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }, sleeper: ->(seconds) { sleep seconds })
    @env = env
    @clock = clock
    @sleeper = sleeper
    @repo = env.fetch('GITHUB_REPOSITORY')
    @pr_number = Integer(env.fetch('PR_NUMBER'))
    @head = env.fetch('PR_HEAD_SHA')
    @base = env.fetch('PR_BASE_REF')
    @comment_id = env['COMMENT_ID']
    @ci_url = env['CI_URL']
    @label = env.fetch('REVIEW_LABEL', 'claude-review')
    @run_url = "#{env.fetch('GITHUB_SERVER_URL')}/#{@repo}/actions/runs/#{env.fetch('GITHUB_RUN_ID')}"
  end

  def wait
    notify('レビュー依頼を受け付けました。')
    output('comment_id', @comment_id)
    workflow = @env.fetch('CI_WORKFLOW')
    unless workflow.empty?
      timeout = positive_integer('CI_WAIT_TIMEOUT_SECONDS')
      start_timeout = positive_integer('CI_START_TIMEOUT_SECONDS')
      interval = positive_integer('CI_POLL_INTERVAL_SECONDS')
      branches = @env.fetch('CI_BASE_BRANCHES').split(',').map(&:strip).reject(&:empty?)
      unless branches.empty? || branches.include?(@base)
        raise Error, 'このベースブランチは CI の対象外です。CI 対象のブランチへの PR で再依頼してください。'
      end

      started = @clock.call
      seen_run = false
      loop do
        verify_pr!
        pages = request(
          "repos/#{@repo}/actions/workflows/#{workflow}/runs", nil,
          ['--paginate', '--slurp', '-f', 'event=pull_request', '-f', "head_sha=#{@head}"]
        )
        runs = pages.flat_map { |page| page.fetch('workflow_runs') }
        latest = runs.select do |run|
          run.fetch('pull_requests').any? { |pr| pr.fetch('number') == @pr_number && pr.dig('base', 'ref') == @base }
        end.max_by { |run| run.fetch('run_number') }
        if latest
          seen_run = true
          @ci_url = latest.fetch('html_url')
          if latest.fetch('status') == 'completed'
            conclusion = latest.fetch('conclusion')
            raise Error, "対象コミットの CI が成功しませんでした（#{conclusion}）。" unless conclusion == 'success'

            break
          end
        end
        elapsed = @clock.call - started
        raise Error, "CI 完了待ちがタイムアウトしました（上限 #{timeout} 秒）。" if elapsed >= timeout
        if !seen_run && elapsed >= start_timeout
          raise Error, "対象コミットの CI が開始されませんでした（開始猶予 #{start_timeout} 秒）。CI の起動条件を確認してください。"
        end

        notify(latest ? 'CI 完了待ちです。成功後に自動でレビューを開始します。' : '対象コミットの CI の開始待ちです。')
        remaining = timeout - elapsed
        remaining = [remaining, start_timeout - elapsed].min unless seen_run
        @sleeper.call([interval, remaining].min)
      end
    end
    verify_pr!
    output('ci_url', @ci_url) if @ci_url
    notify(workflow.empty? ? 'レビュー中です（CI 確認は設定されていません）。' : 'CI の確認が完了し、レビュー中です。')
  rescue StandardError, Interrupt => e
    report_error(e)
    raise
  end

  def finish
    if @env['JOB_CANCELLED'] == 'true'
      raise Error, 'レビューの実行がキャンセルされました。'
    end
    unless @env['REVIEW_OUTCOME'] == 'success' && @env['REVIEW_CONCLUSION'] == 'success'
      raise Error, 'レビューの実行に失敗しました（準備処理の失敗を含みます）。Actions のログを確認してください。'
    end

    verify_pr!
    notify('レビュー処理が完了しました。別途投稿されたレビュー結果と対象コミット SHA を確認してください。結果が投稿されていない場合は Actions のログを確認してください。')
  rescue StandardError, Interrupt => e
    report_error(e)
    raise
  end

  private

  def request(endpoint, body = nil, options = [], method: nil)
    args = ['gh', 'api', endpoint, '--method', method || (body ? 'POST' : 'GET')] + options
    args += ['--input', '-'] if body
    json, status = Open3.capture2(*args, stdin_data: body ? JSON.generate(body) : '')
    raise Error, "GitHub API の呼び出しに失敗しました（#{endpoint}）。" unless status.success?

    JSON.parse(json)
  end

  def notify(message)
    # Suppress identical progress updates while polling. Use one comment per request
    # so a cancelled older run cannot overwrite the status of a newer request.
    body = "<!-- claude-review-status -->\n#{message}\n\n対象コミット: `#{@head}`\n[Actions の実行ログ](#{@run_url})"
    body += " / [対象 CI](#{@ci_url})" if @ci_url
    return if @last_body == body

    if @comment_id
      request("repos/#{@repo}/issues/comments/#{Integer(@comment_id)}", { 'body' => body }, method: 'PATCH')
    else
      @comment_id = request("repos/#{@repo}/issues/#{@pr_number}/comments", { 'body' => body }).fetch('id')
    end
    @last_body = body
    puts message
  end

  def report_error(error)
    message = error.is_a?(Interrupt) ? 'レビューの実行がキャンセルされました。' : error.message
    puts "::error::#{message}"
    notify("#{message}\n再依頼する場合は原因を確認・解消し、最新の PR で #{@label} ラベルを外して付け直してください。CI 成功を手元で待つ必要はありません。")
  rescue StandardError => notification_error
    warn "::warning::PR への状態通知に失敗しました: #{notification_error.message}"
  end

  def verify_pr!
    pr = request("repos/#{@repo}/pulls/#{@pr_number}")
    raise Error, 'PR は既にクローズされています。' unless pr.fetch('state') == 'open'
    unless pr.dig('head', 'sha') == @head && pr.dig('base', 'ref') == @base
      raise Error, 'ラベル付与後に PR が更新されました。対象コミットまたはベースブランチが異なるため終了します。'
    end
    unless pr.fetch('labels').any? { |label| label.fetch('name') == @label }
      raise Error, "#{@label} ラベルが外されたため、レビュー依頼を終了します。"
    end
  end

  def positive_integer(key)
    value = Integer(@env.fetch(key), 10)
    raise ArgumentError unless value.positive?

    value
  rescue ArgumentError
    raise Error, "#{key} は正の整数で指定してください。"
  end

  def output(key, value)
    File.open(@env.fetch('GITHUB_OUTPUT'), 'a') { |file| file.puts "#{key}=#{value}" }
  end
end

if $PROGRAM_NAME == __FILE__
  Signal.trap('TERM') { raise Interrupt }
  Signal.trap('INT') { raise Interrupt }
  begin
    status = ReviewStatus.new
    case ARGV.fetch(0)
    when 'wait' then status.wait
    when 'finish' then status.finish
    else abort 'Unknown command'
    end
  rescue StandardError, Interrupt => e
    warn e.message
    exit 1
  end
end
