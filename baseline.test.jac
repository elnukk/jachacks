"""Tests for get_keyword_baseline's guard clauses (no live network calls)."""

test "get_keyword_baseline on an unknown function id returns empty" {
    assert get_keyword_baseline("not-a-real-id") == [];
}
