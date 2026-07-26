"""Tests for discovery.jac - graph/scoring logic, no live network calls.

Exercises create_candidates() directly with fixture data rather than
monkeypatching openalex_client (a typed Python import doesn't type-check
cleanly as a reassignment target - see jac-python-interop).
"""

import from schema { Product, Component, has_component, requires_function }

glob fixture_results: list[dict] = [
    {
        "oa_id": "W1", "title": "same-subfield paper", "abstract": "a1",
        "year": 2020, "citation_count": 5,
        "domain_id": "D1", "domain_name": "Physical Sciences",
        "field_id": "F1", "field_name": "Materials Science",
        "subfield_id": "S1", "subfield_name": "Ceramics",
        "topic_id": "T1", "topic_name": "Brittle fracture",
    },
    {
        "oa_id": "W2", "title": "far-field paper", "abstract": "a2",
        "year": 2021, "citation_count": 12,
        "domain_id": "D2", "domain_name": "Life Sciences",
        "field_id": "F2", "field_name": "Biology",
        "subfield_id": "S2", "subfield_name": "Marine biology",
        "topic_id": "T2", "topic_name": "Shark skin",
    },
];

test "create_candidates scores field distance and links candidates" {
    product = root ++> Product(name="p", home_domain_id="D1", home_field_id="F1", home_subfield_id="S1");
    component = Component(name="c");
    product +>:has_component:+> component;
    fn = Function(name="won't crack in cold", domain_neutral_desc="energy absorption in brittle materials");
    component +>:requires_function:+> fn;

    created = create_candidates(fn, fixture_results);

    assert len(created) == 2;
    assert created[0].title == "same-subfield paper";
    assert created[1].title == "far-field paper";

    edges = [edge fn <-:serves_function:<-];
    assert len(edges) == 2;
    distances = [e.field_distance for e in edges];
    assert distances[0] == 0;   # same subfield as home -> 0
    assert distances[1] == 3;   # different domain entirely -> 3
}

test "discover_candidates on an unknown function id returns empty" {
    assert discover_candidates("not-a-real-id") == [];
}
