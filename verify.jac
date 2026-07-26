"""Crosswalk - Verify: independent second-pass confirmation before a candidate
surfaces (README §6.5). Genuinely independent prompt from Judge - receives
only the raw claim + raw abstract, never Judge's output/translation/score.

Retry/drop policy: try candidates in rank_score order; confirm -> verified,
stop. Reject -> rejected, try next. After 3 total candidates tried with no
confirmation (1 original + 2 retries) -> every remaining edge dropped.
"""

import from jaclang.byllm.lib { Model }
import from schema { Function, ResearchWork, serves_function }

glob verify_llm: any = Model(model_name="claude-sonnet-5");
glob MAX_VERIFY_RETRIES: int = 2;

obj VerifyResult {
    has confirmed: bool;
    has reason: str;
}
sem VerifyResult.confirmed = "True only if the abstract genuinely supports the claimed function-serving relationship. Be skeptical - this is an independent check, not agreement with a prior judgment you have not seen.";
sem VerifyResult.reason = "One sentence explaining the confirm/reject decision.";

def verify(function_desc: str, work_title: str, work_abstract: str) -> VerifyResult by verify_llm();
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

    attempts = 0;
    confirmed = False;
    for pair in ranked {
        work = pair[0];
        e = pair[1];
        if confirmed or attempts > MAX_VERIFY_RETRIES {
            e.verify_status = "dropped";
            continue;
        }
        try {
            result = verify(desc, work.title, work.abstract);
        } except Exception {
            e.verify_status = "rejected";
            attempts = attempts + 1;
            continue;
        }
        if result.confirmed {
            e.verify_status = "verified";
            confirmed = True;
        } else {
            e.verify_status = "rejected";
            attempts = attempts + 1;
        }
    }
}
