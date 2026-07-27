"""Crosswalk - Verify: independent second-pass confirmation before a candidate
surfaces (README §6.5). Genuinely independent prompt from Judge - receives
only the raw claim + raw abstract, never Judge's output/translation/score.

Verifies ONLY the single top-ranked candidate - one model call, period. This
is deliberately the tightest budget in the whole pipeline: "verify only what
you're about to display" means exactly one candidate per function gets this
check, not a ranked retry chain. If the best candidate doesn't hold up,
nothing surfaces for that function - it doesn't fall back to the second-best.
"""

import from schema { Function, ResearchWork, serves_function }
import from models { shared_llm }

obj VerifyResult {
    has confirmed: bool;
    has reason: str;
}
sem VerifyResult.confirmed = "True only if the abstract genuinely supports the claimed function-serving relationship. Be skeptical - this is an independent check, not agreement with a prior judgment you have not seen.";
sem VerifyResult.reason = "One sentence explaining the confirm/reject decision.";

def verify(function_desc: str, work_title: str, work_abstract: str) -> VerifyResult by shared_llm();
sem verify = "Independently confirm whether this research work's abstract actually supports serving the stated function.";
sem verify.function_desc = "The domain-neutral function being checked.";
sem verify.work_title = "The candidate research work's title.";
sem verify.work_abstract = "The candidate research work's abstract - the only evidence that should drive this decision.";

def rank_key(pair: tuple[ResearchWork, serves_function]) -> float {
    return pair[1].rank_score;
}

def:pub verify_function(function_id: str) -> None {
    try {
        fn = jobj(function_id);
    } except Exception {
        return;
    }
    if not isinstance(fn, Function) {
        return;
    }

    works = [fn <-:serves_function:<-][?:ResearchWork];
    edges = [edge fn <-:serves_function:<-];
    if len(works) != len(edges) {
        return;
    }

    ranked: list[tuple[ResearchWork, serves_function]] = sorted(list(zip(works, edges)), key=rank_key, reverse=True);
    desc = fn.domain_neutral_desc if len(fn.domain_neutral_desc) > 0 else fn.name;

    top = ranked[0];
    top_work = top[0];
    top_edge = top[1];

    print(f"[verify] calling verify for '{top_work.title}'");
    try {
        result = verify(desc, top_work.title, top_work.abstract);
        print(f"[verify] verify returned: confirmed={result.confirmed}");
        top_edge.verify_status = "verified" if result.confirmed else "rejected";
    } except Exception as e {
        print(f"[verify] verify raised: {str(e)}");
        top_edge.verify_status = "rejected";
    }

    for pair in ranked[1:] {
        pair[1].verify_status = "dropped";
    }
}
