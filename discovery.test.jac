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

test "create_candidates scores field distance and skips same-field candidates" {
    product = root ++> Product(name="p", home_domain_id="D1", home_field_id="F1", home_subfield_id="S1");
    component = Component(name="c");
    product +>:has_component:+> component;
    fn = Function(name="won't crack in cold", domain_neutral_desc="energy absorption in brittle materials");
    component +>:requires_function:+> fn;

    created = create_candidates(fn, fixture_results);

    # the same-subfield candidate is skipped entirely (never worth a Judge
    # call - rank_score would always be 0), only the far-field one remains
    assert len(created) == 1;
    assert created[0].title == "far-field paper";

    edges = [edge fn <-:serves_function:<-];
    assert len(edges) == 1;
    assert edges[0].field_distance == 3;
}

test "discover_candidates on an unknown function id returns empty" {
    assert discover_candidates("not-a-real-id", ["some query"]) == [];
}

test "discover_candidates with no queries returns empty" {
    fn = root ++> Function(name="fn");
    assert discover_candidates(jid(fn), []) == [];
}

test "similarity.rank_by_similarity ranks closer text higher" {
    candidates: list[dict] = [
        {"title": "Riblet surfaces inspired by shark denticles reduce drag", "abstract": "turbulent boundary layer"},
        {"title": "A history of 19th century pottery glazing techniques", "abstract": "ceramic art history"},
    ];
    ranked = similarity.rank_by_similarity(candidates, "drag reduction via riblet surface texture", 2) as list[dict];
    assert (ranked[0]["title"] as str) == "Riblet surfaces inspired by shark denticles reduce drag";
}

test "dedupe_pool drops duplicate oa_ids across variant result lists" {
    list_a: list[dict] = [
        {"oa_id": "W1", "title": "paper one"},
        {"oa_id": "W2", "title": "paper two"},
    ];
    list_b: list[dict] = [
        {"oa_id": "W2", "title": "paper two"},   # duplicate of list_a's W2
        {"oa_id": "W3", "title": "paper three"},
    ];

    pooled = dedupe_pool([list_a, list_b], 10);

    assert len(pooled) == 3;
    ids = [p["oa_id"] as str for p in pooled];
    assert ids == ["W1", "W2", "W3"];
}

test "dedupe_pool caps the pooled total" {
    list_a: list[dict] = [
        {"oa_id": "W1", "title": "a"}, {"oa_id": "W2", "title": "b"}, {"oa_id": "W3", "title": "c"},
    ];

    pooled = dedupe_pool([list_a], 2);

    assert len(pooled) == 2;
}

test "dedupe_pool falls back to title when oa_id is empty" {
    list_a: list[dict] = [{"oa_id": "", "title": "untitled work"}];
    list_b: list[dict] = [{"oa_id": "", "title": "untitled work"}];

    pooled = dedupe_pool([list_a, list_b], 10);

    assert len(pooled) == 1;
}
