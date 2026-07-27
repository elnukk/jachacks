"""Tests for verify_function - checks ONLY the single top-ranked candidate,
everything else is dropped without a model call."""

import from jaclang.byllm.lib { MockLLM }
import from schema { Product, Component, has_component, requires_function }

def make_candidate(fn: Function, title: str, rank_score: float) -> ResearchWork {
    work = ResearchWork(title=title, abstract="abstract for " + title);
    work +>:serves_function(rank_score=rank_score):+> fn;
    return work;
}

test "top candidate rejected - everything else dropped, no retry" {
    shared_llm = MockLLM(model_name="mockllm", config={"outputs": [
        VerifyResult(confirmed=False, reason="no"),
    ]});

    product = root ++> Product(name="p");
    component = Component(name="c");
    product +>:has_component:+> component;
    fn = Function(name="fn", domain_neutral_desc="desc");
    component +>:requires_function:+> fn;

    _best = make_candidate(fn, "best", 3.0);
    _second = make_candidate(fn, "second", 2.0);

    verify_function(jid(fn));

    edges = [edge fn <-:serves_function:<-];
    statuses = {e.rank_score: e.verify_status for e in edges};
    assert statuses[3.0] == "rejected";
    assert statuses[2.0] == "dropped";
}

test "top candidate confirmed - verified, rest dropped" {
    shared_llm = MockLLM(model_name="mockllm", config={"outputs": [
        VerifyResult(confirmed=True, reason="yes"),
    ]});

    product = root ++> Product(name="p2");
    component = Component(name="c2");
    product +>:has_component:+> component;
    fn = Function(name="fn2", domain_neutral_desc="desc2");
    component +>:requires_function:+> fn;

    _best = make_candidate(fn, "best2", 3.0);
    _second = make_candidate(fn, "second2", 2.0);

    verify_function(jid(fn));

    edges = [edge fn <-:serves_function:<-];
    statuses = {e.rank_score: e.verify_status for e in edges};
    assert statuses[3.0] == "verified";
    assert statuses[2.0] == "dropped";
}

test "verify_function on an unknown function id does nothing" {
    verify_function("not-a-real-id");
}
