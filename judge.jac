"""Crosswalk - Judge: score every discovered candidate's functional relevance
in ONE batched model call, not one call per candidate. Judge is a triage
step - the model already sees every candidate's title/abstract together, so
there's no reason to pay for N separate round-trips when one structured
response listing N judgments does the same job.

Candidates are passed as one formatted string, not list[CandidateInput] - a
custom object type as a by-llm() INPUT parameter breaks local-model schema
introspection (NameError resolving the nested type's forward reference,
specific to input position - nested custom types as a RETURN type, like
Decomposition's component/function tree, work fine). Plain text sidesteps it
entirely and is simpler regardless.

Fields are written directly onto the serves_function edge (see schema.jac) -
that's what the client sorts/colors/renders by, so there's no separate
free-floating Judgment record to keep in sync.
"""

import from schema { Function, ResearchWork, serves_function }
import from distance { compute_rank_score }
import from models { shared_llm }

obj Judgment {
    has functional_relevance: float;
    has maturity: str;
    has transfer_difficulty: str;
    has surprise_flag: bool;
    has translation: str;
}
sem Judgment.functional_relevance = "0.0-1.0: how directly this research serves the stated function, independent of field distance.";
sem Judgment.maturity = "How developed this research direction is - e.g. \"early lab research\", \"applied/prototype stage\", \"commercially deployed\".";
sem Judgment.transfer_difficulty = "How hard it would be to adapt this research into the product's domain - e.g. \"low\", \"moderate\", \"high\".";
sem Judgment.surprise_flag = "True if a domain expert in the product's own field would likely already know this connection - False if it's a genuinely non-obvious cross-domain link.";
sem Judgment.translation = "One plain-language sentence translating this research into what it would mean for the product.";

obj BatchJudgment {
    has judgments: list[Judgment] = [];
}
sem BatchJudgment.judgments = "Exactly one Judgment per candidate, in the SAME ORDER the candidates were given.";

def judge_batch(function_desc: str, candidates_text: str) -> BatchJudgment by shared_llm();
sem judge_batch = "Judge every candidate research work for how well it serves the stated function, in one pass. Return judgments in the exact same order the candidates appear in candidates_text - one per candidate, no more, no fewer.";
sem judge_batch.function_desc = "The domain-neutral function every candidate is being evaluated against.";
sem judge_batch.candidates_text = "Every candidate, numbered, as 'N. Title: ...' followed by 'Abstract: ...' blocks, in order.";

def format_candidates(works: list[ResearchWork]) -> str {
    lines: list[str] = [];
    for i in range(len(works)) {
        w = works[i];
        lines.append(f"{i + 1}. Title: {w.title}\nAbstract: {w.abstract}");
    }
    return "\n\n".join(lines);
}

def:pub judge_candidates(function_id: str, work_ids: list[str]) -> int {
    if len(work_ids) == 0 {
        return 0;
    }

    works: list[ResearchWork] = [];
    for wid in work_ids {
        try {
            w = jobj(wid);
        } except Exception {
            continue;
        }
        if isinstance(w, ResearchWork) {
            works.append(w);
        }
    }
    if len(works) == 0 {
        return 0;
    }

    functions = [works[0] ->:serves_function:->][?:Function];
    if len(functions) == 0 {
        return 0;
    }
    fn = functions[0];
    desc = fn.domain_neutral_desc if len(fn.domain_neutral_desc) > 0 else fn.name;

    print(f"[judge] calling judge_batch for {len(works)} candidates");
    try {
        result = judge_batch(desc, format_candidates(works));
    } except Exception as e {
        print(f"[judge] judge_batch raised: {str(e)}");
        return 0;
    }
    print(f"[judge] judge_batch returned {len(result.judgments)} judgments");

    judged = 0;
    count = min(len(works), len(result.judgments));
    for i in range(count) {
        work = works[i];
        j = result.judgments[i];
        edges = [edge work ->:serves_function:->];
        if len(edges) == 0 {
            continue;
        }
        e = edges[0];
        e.functional_relevance = j.functional_relevance;
        e.maturity = j.maturity;
        e.transfer_difficulty = j.transfer_difficulty;
        e.surprise_flag = j.surprise_flag;
        e.translation = j.translation;
        e.rank_score = compute_rank_score(j.functional_relevance, e.field_distance);
        judged += 1;
    }
    return judged;
}
