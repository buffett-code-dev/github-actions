"""課金や GitHub への投稿を伴わず、レビューの実行条件を検証する。"""

import base64
import copy
import unittest

from claude_agent_sdk import ResultMessage
from review import (
    actor_allowed,
    result_text,
    source_content,
    source_endpoint,
    target,
    verify_pr,
)


class ReviewTest(unittest.TestCase):
    def test_mentions_resolve_pr_and_issue_targets(self):
        events = [
            (
                "issue_comment",
                {"issue": {"number": 42}, "comment": {"body": "@claude 質問"}},
                False,
            ),
            (
                "issue_comment",
                {
                    "issue": {"number": 42, "pull_request": {}},
                    "comment": {"body": "@claude レビュー"},
                },
                True,
            ),
            (
                "pull_request_review_comment",
                {
                    "pull_request": {"number": 42},
                    "comment": {"body": "@claude この行を確認"},
                },
                True,
            ),
            (
                "pull_request_review",
                {"pull_request": {"number": 42}, "review": {"body": "@claude 再確認"}},
                True,
            ),
            ("issues", {"issue": {"number": 42, "body": "@claude 質問"}}, False),
        ]
        for event_name, event, is_pr in events:
            with self.subTest(event_name=event_name, is_pr=is_pr):
                number, actual_pr, request = target(event, event_name)
                self.assertEqual((42, is_pr), (number, actual_pr))
                self.assertIn("@claude", request)

    def test_label_resolves_pr(self):
        self.assertEqual(
            (42, True, "PR をレビューしてください。"),
            target(
                {"action": "labeled", "pull_request": {"number": 42}}, "pull_request"
            ),
        )

    def test_missing_mention_and_unsupported_event_fail(self):
        for event_name, event in [
            ("issue_comment", {"comment": {"body": "レビュー"}}),
            ("pull_request_review", {"review": {"body": None}}),
            ("push", {}),
        ]:
            with self.subTest(event_name=event_name), self.assertRaises(ValueError):
                target(event, event_name)

    def test_only_users_with_write_access_can_request(self):
        sender = {"type": "User", "login": "contributor"}
        for permission in ["read", "triage", "none", None]:
            with self.subTest(permission=permission):
                self.assertFalse(actor_allowed(sender, permission, "contributor"))
        for permission in ["write", "maintain", "admin"]:
            with self.subTest(permission=permission):
                self.assertTrue(actor_allowed(sender, permission, ""))

    def test_bots_require_explicit_allowlist_even_with_write_access(self):
        sender = {"type": "Bot", "login": "yamori-ai-integration[bot]"}
        self.assertFalse(actor_allowed(sender, "admin", ""))
        self.assertFalse(actor_allowed(sender, None, "another-bot"))
        for pattern in [
            "yamori-ai-integration",
            "yamori-ai-integration[bot]",
            "yamori-*",
            "*",
        ]:
            with self.subTest(pattern=pattern):
                self.assertTrue(actor_allowed(sender, None, pattern))

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
