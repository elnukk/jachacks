"""Tests for has_verified_result - the stop condition for the per-level
abstract -> discover -> judge -> verify retry loop."""

import from schema { Product, Component, has_component, requires_function }

test "has_verified_result is true once any edge is verified" {
    product = root ++> Product(name="p");
    component = Component(name="c");
    product +>:has_component:+> component;
    fn = Function(name="fn");
    component +>:requires_function:+> fn;

    work_a = ResearchWork(title="a");
    work_a +>:serves_function(verify_status="rejected"):+> fn;
    work_b = ResearchWork(title="b");
    work_b +>:serves_function(verify_status="dropped"):+> fn;

    assert has_verified_result(jid(fn)) == False;

    work_c = ResearchWork(title="c");
    work_c +>:serves_function(verify_status="verified"):+> fn;

    assert has_verified_result(jid(fn)) == True;
}

test "has_verified_result on an unknown function id returns False" {
    assert has_verified_result("not-a-real-id") == False;
}
