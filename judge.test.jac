"""Tests for judge_candidates - one batched call judges all candidates,
writing Judgment fields + rank_score onto each edge in order."""

import from jaclang.byllm.lib { MockLLM }
import from schema { Product, Component, has_component, requires_function }

test "judge_candidates batch-judges every work and computes rank_score" {
    shared_llm = MockLLM(model_name="mockllm", config={"outputs": [
        BatchJudgment(judgments=[
            Judgment(
                functional_relevance=0.8, maturity="applied/prototype stage",
                transfer_difficulty="moderate", surprise_flag=True,
                translation="This could inform a better seal design."
            ),
            Judgment(
                functional_relevance=0.3, maturity="early lab research",
                transfer_difficulty="high", surprise_flag=False,
                translation="Weak connection."
            ),
        ]),
    ]});

    product = root ++> Product(name="p");
    component = Component(name="c");
    product +>:has_component:+> component;
    fn = Function(name="fn", domain_neutral_desc="desc");
    component +>:requires_function:+> fn;

    work_a = ResearchWork(title="a", abstract="abstract a");
    work_a +>:serves_function(field_distance=2):+> fn;
    work_b = ResearchWork(title="b", abstract="abstract b");
    work_b +>:serves_function(field_distance=3):+> fn;

    judged = judge_candidates(jid(fn), [jid(work_a), jid(work_b)]);
    assert judged == 2;

    edges_a = [edge work_a ->:serves_function:->];
    assert edges_a[0].functional_relevance == 0.8;
    assert edges_a[0].surprise_flag == True;
    assert edges_a[0].rank_score == 1.6;

    edges_b = [edge work_b ->:serves_function:->];
    assert edges_b[0].functional_relevance == 0.3;
    assert abs(edges_b[0].rank_score - 0.9) < 0.0001;
}

test "judge_candidates with no work ids returns 0" {
    assert judge_candidates("some-function-id", []) == 0;
}

test "judge_candidates skips unresolvable work ids" {
    assert judge_candidates("some-function-id", ["not-a-real-id"]) == 0;
}
