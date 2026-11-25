"""課金や GitHub への投稿を伴わず、レビューの実行条件を検証する。"""

import base64
import copy
import unittest

from claude_agent_sdk import ResultMessage
from review import (
    build_prompt,
    result_text,
    review_target,
    source_content,
    source_endpoint,
    verify_pr,
)


class ReviewTest(unittest.TestCase):
    def test_label_keeps_its_existing_instructions(self):
        instructions = (
            "不具合、回帰、テスト不足を優先してください。\n"
            "冒頭に pass、changes_requested、needs_human を示してください。\n"
            "セルフマージの事前判定を記載してください。"
        )
        context = {"diff": "+new code", "self_merge_policy": "既存の規約"}
        prompt = build_prompt(context, instructions)
        self.assertTrue(prompt.startswith(instructions + "\n\n"))
        self.assertEqual(1, prompt.count("不具合、回帰、テスト不足"))
        self.assertIn("既存の規約", prompt)

    def event(self, sender=None):
        return {
            "action": "labeled",
            "pull_request": {"number": 42, "head": {"repo": {"full_name": "org/repo"}}},
            "label": {"name": "claude-review-sdk"},
            "sender": sender or {"type": "User", "login": "maintainer"},
        }

    def test_label_resolves_pr_and_custom_label(self):
        event = self.event()
        self.assertEqual(
            (event["pull_request"], "claude-review-sdk"),
            review_target(event, "pull_request", "org/repo"),
        )

    def test_mention_and_other_events_cannot_start_the_experiment(self):
        for event_name, action in [
            ("issue_comment", "created"),
            ("issues", "opened"),
            ("pull_request", "synchronize"),
        ]:
            with (
                self.subTest(event=event_name, action=action),
                self.assertRaises(ValueError),
            ):
                review_target(self.event() | {"action": action}, event_name, "org/repo")

    def test_fork_pr_cannot_start_the_experiment(self):
        event = self.event()
        event["pull_request"]["head"]["repo"]["full_name"] = "external/repo"
        with self.assertRaises(ValueError):
            review_target(event, "pull_request", "org/repo")

    def test_only_devin_can_start_a_bot_label_review(self):
        event = self.event({"type": "Bot", "login": "devin-ai-integration[bot]"})
        review_target(event, "pull_request", "org/repo")
        event["sender"]["login"] = "another-bot[bot]"
        with self.assertRaises(PermissionError):
            review_target(event, "pull_request", "org/repo")

    def test_stale_closed_and_unlabelled_reviews_are_rejected(self):
        expected = {
            "state": "open",
            "head": {"sha": "head-sha"},
            "base": {"sha": "base-sha", "ref": "main"},
            "labels": [{"name": "claude-review"}],
        }
        verify_pr(expected, expected, "claude-review")
        changes = [
            ("state", "closed"),
            ("head", {"sha": "new-head"}),
            ("base", {"sha": "new-base", "ref": "main"}),
            ("base", {"sha": "base-sha", "ref": "release"}),
            ("labels", []),
        ]
        for key, value in changes:
            with self.subTest(change=(key, value)), self.assertRaises(ValueError):
                current = copy.deepcopy(expected)
                current[key] = value
                verify_pr(current, expected, "claude-review")

    def result(self, **changes):
        fields = {
            "subtype": "success",
            "duration_ms": 1,
            "duration_api_ms": 1,
            "is_error": False,
            "num_turns": 1,
            "session_id": "session",
            "result": "pass\n問題なし。",
        }
        return ResultMessage(**(fields | changes))

    def test_sdk_api_error_is_not_a_successful_review(self):
        failures = [
            {
                "is_error": True,
                "result": "Credit balance is too low",
                "api_error_status": 400,
            },
            {"is_error": True, "stop_reason": "refusal"},
            {"subtype": "error_max_turns", "is_error": True},
            {"subtype": "error_during_execution", "is_error": True},
            {"result": None},
            {"result": "  "},
        ]
        for fields in failures:
            with self.subTest(fields=fields), self.assertRaises(RuntimeError):
                result_text(self.result(**fields))
        self.assertEqual("pass\n問題なし。", result_text(self.result()))

    def test_source_reads_are_pinned_and_paths_are_url_encoded(self):
        refs = {"base": "base-sha", "head": "head-sha"}
        self.assertEqual(
            "repos/org/repo/contents/a%3Fref%3Dmain%26x%3D.txt?ref=head-sha",
            source_endpoint("org/repo", "a?ref=main&x=.txt", "head", refs),
        )
        with self.assertRaises(ValueError):
            source_endpoint("org/repo", "README.md", "main", refs)

    def test_source_paths_cannot_escape_the_repository(self):
        for path in ["../user", "src/../../user", "/user", "src\\..\\user"]:
            with self.subTest(path=path), self.assertRaises(ValueError):
                source_endpoint("org/repo", path, "base", {"base": "base-sha"})

    def test_source_files_and_directories_decode_without_execution(self):
        content = "# 規約\n日本語のファイル"
        self.assertEqual(
            content,
            source_content(
                {
                    "encoding": "base64",
                    "content": base64.b64encode(content.encode()).decode(),
                }
            ),
        )
        self.assertEqual(
            "file README.md\ndir src",
            source_content(
                [
                    {"type": "file", "path": "README.md"},
                    {"type": "dir", "path": "src"},
                ]
            ),
        )
        with self.assertRaises(ValueError):
            source_content({"encoding": "none", "content": ""})


if __name__ == "__main__":
    unittest.main()
