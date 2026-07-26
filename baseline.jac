"""Crosswalk - keyword-search baseline: the "boring" side-by-side comparison
for the wow beat. Plain relevance-sorted OpenAlex search on the literal,
unabstracted function text - no distance weighting, no judge/verify pass.
This is what makes the gap between Crosswalk and plain search the pitch.
"""

import openalex_client;
import from schema { Function }

glob BASELINE_RESULTS: int = 5;

obj BaselineHit {
    has title: str, year: int, citation_count: int, field_name: str;
}

def:pub get_keyword_baseline(function_id: str) -> list[BaselineHit] {
    try {
        fn = jobj(function_id);
    } except Exception {
        return [];
    }
    if not isinstance(fn, Function) {
        return [];
    }

    try {
        raw = openalex_client.search_works(fn.name, per_page=BASELINE_RESULTS);
        results = raw as list[dict];
    } except Exception {
        return [];
    }

    return [
        BaselineHit(
            title=r["title"] as str, year=r["year"] as int,
            citation_count=r["citation_count"] as int, field_name=r["field_name"] as str
        )
        for r in results
    ];
}
