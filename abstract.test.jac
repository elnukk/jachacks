"""Tests for abstract_function - hop cap + abstracts_to chain, no real API key needed."""

import from jaclang.byllm.lib { MockLLM }

test "abstraction climbs to the hop cap and stops" {
    fast_llm = MockLLM(model_name="mockllm", config={"outputs": [
        AbstractResult(name="level-1", domain_neutral_desc="desc-1"),
        AbstractResult(name="level-2", domain_neutral_desc="desc-2"),
        AbstractResult(name="level-3", domain_neutral_desc="desc-3"),
    ]});

    base = root ++> Function(name="won't crack in cold", abstraction_level=0);
    created = abstract_function(jid(base));

    assert len(created) == 3;
    assert created[0].name == "level-1";
    assert created[2].abstraction_level == 3;

    chain = [base ->:abstracts_to:->][?:Function];
    assert len(chain) == 1;
    assert chain[0].name == "level-1";
}

test "abstract_function on an unknown id returns empty" {
    fast_llm = MockLLM(model_name="mockllm", config={"outputs": []});
    assert abstract_function("not-a-real-id") == [];
}
