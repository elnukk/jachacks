"""Crosswalk - Discovery: search OpenAlex with pre-generated query variants
(from abstract.jac's merged abstract+query call), create ResearchWork
candidates + serves_function edges, and score field distance against the
owning product's home field.

Multi-query fan-out: OpenAlex's search= is pure keyword matching, so a
single abstracted phrase only finds papers that happen to share its exact
vocabulary. Genuinely non-obvious cross-domain matches often describe the
same mechanism in completely different terminology (a coffee machine
gasket's "thermal seal fatigue" vs. a bike valve's "elastomer degradation
under cyclic pressure"). Searching several differently-worded reformulations
in parallel counters that. flow/wait is safe here (unlike in pipeline.jac's
graph writes) because fetch_variant_results only calls the plain Python HTTP
client, never touches the graph.

Free pre-filter before any model call: OpenAlex calls are cheap/free, so we
can afford to pull a bigger raw pool, then use a zero-cost text-similarity
ranking (similarity.py) to narrow it down to the few candidates actually
worth a Judge call - shrinking candidate count without spending a single
model call to do it.

No walker here either: candidates come from an external API call keyed off
one Function, not a traversal of existing graph structure.
"""

import openalex_client;
import similarity;
import from schema { Function, ResearchWork, serves_function }
import from distance { field_distance }
import from views { find_owning_product }

glob RESULTS_PER_VARIANT: int = 5;
glob MAX_POOLED_CANDIDATES: int = 12;
glob SIMILARITY_TOP_N: int = 5;

"""Pure graph-building + scoring step, split out from the network call so
it's directly testable with fixture data (see discovery.test.jac). Same-field
(distance=0) candidates are skipped entirely, not just downranked - rank_score
= functional_relevance * field_distance is always 0 for them regardless of
how relevant they are, so spending a Judge (and possibly Verify) call on one
is pure waste."""
def create_candidates(fn: Function, results: list[dict]) -> list[ResearchWork] {
    product = find_owning_product(fn);
    home_domain = product.home_domain_id if product is not None else "";
    home_field = product.home_field_id if product is not None else "";
    home_subfield = product.home_subfield_id if product is not None else "";

    created: list[ResearchWork] = [];
    for r in results {
        domain_id = r["domain_id"] as str;
        field_id = r["field_id"] as str;
        subfield_id = r["subfield_id"] as str;
        dist = field_distance(domain_id, field_id, subfield_id, home_domain, home_field, home_subfield);
        if dist == 0 {
            continue;
        }

        work = ResearchWork(
            title=r["title"] as str, abstract=r["abstract"] as str, oa_id=r["oa_id"] as str,
            year=r["year"] as int, citation_count=r["citation_count"] as int,
            domain_id=domain_id, domain_name=r["domain_name"] as str,
            field_id=field_id, field_name=r["field_name"] as str,
            subfield_id=subfield_id, subfield_name=r["subfield_name"] as str,
            topic_id=r["topic_id"] as str, topic_name=r["topic_name"] as str,
        );
        work +>:serves_function(field_distance=dist):+> fn;
        created.append(work);
    }
    return created;
}

"""Dedupe candidates pooled from multiple query variants (by oa_id, falling
back to title if oa_id is ever empty), capped at max_total - pure function,
directly testable with fixture data, no network/LLM needed."""
def dedupe_pool(result_lists: list[list[dict]], max_total: int) -> list[dict] {
    pooled: list[dict] = [];
    seen: list[str] = [];
    for results in result_lists {
        for r in results {
            oa_id = r["oa_id"] as str;
            key = oa_id if len(oa_id) > 0 else (r["title"] as str);
            if key in seen {
                continue;
            }
            seen.append(key);
            pooled.append(r);
            if len(pooled) >= max_total {
                return pooled;
            }
        }
    }
    return pooled;
}

def fetch_variant_results(query: str) -> list[dict] {
    try {
        raw = openalex_client.search_works(query, per_page=RESULTS_PER_VARIANT);
        return raw as list[dict];
    } except Exception {
        return [];
    }
}

def:pub discover_candidates(function_id: str, queries: list[str]) -> list[ResearchWork] {
    try {
        fn = jobj(function_id);
    } except Exception {
        return [];
    }
    if not isinstance(fn, Function) {
        return [];
    }
    if len(queries) == 0 {
        return [];
    }

    futures = [flow fetch_variant_results(q) for q in queries];
    result_lists: list[list[dict]] = [wait f for f in futures];

    pooled = dedupe_pool(result_lists, MAX_POOLED_CANDIDATES);

    query_text = fn.domain_neutral_desc if len(fn.domain_neutral_desc) > 0 else fn.name;
    top_pool = similarity.rank_by_similarity(pooled, query_text, SIMILARITY_TOP_N) as list[dict];

    return create_candidates(fn, top_pool);
}
