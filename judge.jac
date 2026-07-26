"""Crosswalk - Judge: score each discovered candidate's functional relevance.

Fields are written directly onto the serves_function edge (see schema.jac) -
that's what the client sorts/colors/renders by, so there's no separate
free-floating Judgment record to keep in sync.
"""

import from jaclang.byllm.lib { Model }
import from schema { Function, ResearchWork, serves_function }
import from distance { compute_rank_score }

glob judge_llm: any = Model(model_name="claude-sonnet-5");

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

def judge(function_desc: str, work_title: str, work_abstract: str) -> Judgment by judge_llm();
sem judge = "Judge whether this research work genuinely serves the stated function, and how significant, usable, and surprising the connection is.";
sem judge.function_desc = "The domain-neutral function this candidate is being evaluated against.";
sem judge.work_title = "The candidate research work's title.";
sem judge.work_abstract = "The candidate research work's abstract.";

def:pub judge_candidate(work_id: str) -> bool {
    try {
        work = jobj(work_id);
    } except Exception {
        return False;
    }
    if not isinstance(work, ResearchWork) {
        return False;
    }

    functions = [work ->:serves_function:->][?:Function];
    if len(functions) == 0 {
        return False;
    }
    fn = functions[0];
    desc = fn.domain_neutral_desc if len(fn.domain_neutral_desc) > 0 else fn.name;

    try {
        result = judge(desc, work.title, work.abstract);
    } except Exception {
        return False;
    }

    edges = [edge work ->:serves_function:->];
    if len(edges) == 0 {
        return False;
    }
    e = edges[0];
    e.functional_relevance = result.functional_relevance;
    e.maturity = result.maturity;
    e.transfer_difficulty = result.transfer_difficulty;
    e.surprise_flag = result.surprise_flag;
    e.translation = result.translation;
    e.rank_score = compute_rank_score(result.functional_relevance, e.field_distance);
    return True;
}
