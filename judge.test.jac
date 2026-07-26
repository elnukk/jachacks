"""Tests for judge_candidate - writes Judgment fields + rank_score onto the edge."""

import from jaclang.byllm.lib { MockLLM }
import from schema { Product, Component, has_component, requires_function }

test "judge_candidate writes fields and computes rank_score" {
    judge_llm = MockLLM(model_name="mockllm", config={"outputs": [
        Judgment(
            functional_relevance=0.8, maturity="applied/prototype stage",
            transfer_difficulty="moderate", surprise_flag=True,
            translation="This could inform a better seal design."
        ),
    ]});

    product = root ++> Product(name="p");
    component = Component(name="c");
    product +>:has_component:+> component;
    fn = Function(name="fn", domain_neutral_desc="desc");
    component +>:requires_function:+> fn;

    work = ResearchWork(title="t", abstract="a");
    work +>:serves_function(field_distance=2):+> fn;

    ok = judge_candidate(jid(work));
    assert ok;

    edges = [edge work ->:serves_function:->];
    e = edges[0];
    assert e.functional_relevance == 0.8;
    assert e.surprise_flag == True;
    assert e.rank_score == 1.6;
}

test "judge_candidate on an unknown work id returns False" {
    assert judge_candidate("not-a-real-id") == False;
}
