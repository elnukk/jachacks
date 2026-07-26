"""Tests for verify_function's retry/cap/drop policy - no real API key needed."""

import from jaclang.byllm.lib { MockLLM }
import from schema { Product, Component, has_component, requires_function }

def make_candidate(fn: Function, title: str, rank_score: float) -> ResearchWork {
    work = ResearchWork(title=title, abstract="abstract for " + title);
    work +>:serves_function(rank_score=rank_score):+> fn;
    return work;
}

test "rejects exhaust after 1 original + 2 retries, remaining candidates dropped" {
    verify_llm = MockLLM(model_name="mockllm", config={"outputs": [
        VerifyResult(confirmed=False, reason="no"),
        VerifyResult(confirmed=False, reason="no"),
        VerifyResult(confirmed=False, reason="no"),
    ]});

    product = root ++> Product(name="p");
    component = Component(name="c");
    product +>:has_component:+> component;
    fn = Function(name="fn", domain_neutral_desc="desc");
    component +>:requires_function:+> fn;

    _best = make_candidate(fn, "best", 3.0);
    _second = make_candidate(fn, "second", 2.0);
    _third = make_candidate(fn, "third", 1.0);
    _fourth = make_candidate(fn, "fourth", 0.5);

    verify_function(jid(fn));

    edges = [edge fn <-:serves_function:<-];
    statuses = {e.rank_score: e.verify_status for e in edges};
    assert statuses[3.0] == "rejected";
    assert statuses[2.0] == "rejected";
    assert statuses[1.0] == "rejected";
    assert statuses[0.5] == "dropped";
}

test "confirms on the second candidate and drops the rest" {
    verify_llm = MockLLM(model_name="mockllm", config={"outputs": [
        VerifyResult(confirmed=False, reason="no"),
        VerifyResult(confirmed=True, reason="yes"),
    ]});

    product = root ++> Product(name="p2");
    component = Component(name="c2");
    product +>:has_component:+> component;
    fn = Function(name="fn2", domain_neutral_desc="desc2");
    component +>:requires_function:+> fn;

    _best = make_candidate(fn, "best2", 3.0);
    _second = make_candidate(fn, "second2", 2.0);
    _third = make_candidate(fn, "third2", 1.0);

    verify_function(jid(fn));

    edges = [edge fn <-:serves_function:<-];
    statuses = {e.rank_score: e.verify_status for e in edges};
    assert statuses[3.0] == "rejected";
    assert statuses[2.0] == "verified";
    assert statuses[1.0] == "dropped";
}
