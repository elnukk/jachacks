"""Crosswalk - Discovery: query OpenAlex for a function's domain-neutral
description, create ResearchWork candidates + serves_function edges, and
score field distance against the owning product's home field.

No walker here either: candidates come from an external API call keyed off
one Function, not a traversal of existing graph structure.
"""

import openalex_client;
import from schema { Function, ResearchWork, serves_function }
import from distance { field_distance }
import from views { find_owning_product }

glob CANDIDATES_PER_FUNCTION: int = 6;

"""Pure graph-building + scoring step, split out from the network call so
it's directly testable with fixture data (see discovery.test.jac)."""
def create_candidates(fn: Function, results: list[dict]) -> list[ResearchWork] {
    product = find_owning_product(fn);
    home_domain = product.home_domain_id if product is not None else "";
    home_field = product.home_field_id if product is not None else "";
    home_subfield = product.home_subfield_id if product is not None else "";

    created: list[ResearchWork] = [];
    for r in results {
        work = ResearchWork(
            title=r["title"] as str, abstract=r["abstract"] as str, oa_id=r["oa_id"] as str,
            year=r["year"] as int, citation_count=r["citation_count"] as int,
            domain_id=r["domain_id"] as str, domain_name=r["domain_name"] as str,
            field_id=r["field_id"] as str, field_name=r["field_name"] as str,
            subfield_id=r["subfield_id"] as str, subfield_name=r["subfield_name"] as str,
            topic_id=r["topic_id"] as str, topic_name=r["topic_name"] as str,
        );
        dist = field_distance(
            work.domain_id, work.field_id, work.subfield_id,
            home_domain, home_field, home_subfield
        );
        work +>:serves_function(field_distance=dist):+> fn;
        created.append(work);
    }
    return created;
}

def:pub discover_candidates(function_id: str) -> list[ResearchWork] {
    try {
        fn = jobj(function_id);
    } except Exception {
        return [];
    }
    if not isinstance(fn, Function) {
        return [];
    }

    query = fn.domain_neutral_desc if len(fn.domain_neutral_desc) > 0 else fn.name;

    try {
        raw = openalex_client.search_works(query, per_page=CANDIDATES_PER_FUNCTION);
        results = raw as list[dict];
    } except Exception {
        return [];
    }

    return create_candidates(fn, results);
}
