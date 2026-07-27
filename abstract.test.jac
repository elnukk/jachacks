"""Tests for abstract_one_level - single merged abstract+query-generation
hop, no real API key/model needed."""

import from jaclang.byllm.lib { MockLLM }

test "abstract_one_level produces a new function and search queries" {
    shared_llm = MockLLM(model_name="mockllm", config={"outputs": [
        AbstractAndQueries(
            name="level-1", domain_neutral_desc="desc-1",
            search_queries=["materials science phrasing", "biology phrasing"]
        ),
    ]});

    base = root ++> Function(name="won't crack in cold", abstraction_level=0);
    step = abstract_one_level(jid(base));

    assert step is not None;
    assert step.next_function.name == "level-1";
    assert step.next_function.abstraction_level == 1;
    assert step.search_queries == ["materials science phrasing", "biology phrasing"];

    chain = [base ->:abstracts_to:->][?:Function];
    assert len(chain) == 1;
    assert chain[0].name == "level-1";
}

test "abstract_one_level falls back to the domain_neutral_desc when no queries returned" {
    shared_llm = MockLLM(model_name="mockllm", config={"outputs": [
        AbstractAndQueries(name="level-1", domain_neutral_desc="desc-1", search_queries=[]),
    ]});

    base = root ++> Function(name="fn", abstraction_level=0);
    step = abstract_one_level(jid(base));

    assert step is not None;
    assert step.search_queries == ["desc-1"];
}

test "abstract_one_level on an unknown id returns None" {
    shared_llm = MockLLM(model_name="mockllm", config={"outputs": []});
    assert abstract_one_level("not-a-real-id") is None;
}
