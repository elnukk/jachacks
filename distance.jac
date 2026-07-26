"""Crosswalk - field-distance scoring (README §4: the core ranking mechanism).

rank_score = functional_relevance x field_distance, NEVER relevance alone -
this is what protects the pitch from being "just a semantic search box".
Same-subfield hits score 0 and sort to the bottom automatically.
"""

def field_distance(
    work_domain_id: str, work_field_id: str, work_subfield_id: str,
    home_domain_id: str, home_field_id: str, home_subfield_id: str
) -> int {
    if len(home_subfield_id) > 0 and work_subfield_id == home_subfield_id {
        return 0;
    }
    if len(home_field_id) > 0 and work_field_id == home_field_id {
        return 1;
    }
    if len(home_domain_id) > 0 and work_domain_id == home_domain_id {
        return 2;
    }
    return 3;
}

def compute_rank_score(functional_relevance: float, distance: int) -> float {
    return functional_relevance * (distance as float);
}
