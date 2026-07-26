"""Crosswalk - Interactive Abstract (per-function, on demand).

Triggered when the user selects a Function in the UI and sends it deep -
never automatic across the whole ~40-node decomposition (see README non-goal
"no recursive depth on every node"). No walker: this only creates new nodes
and connects them, it never visits pre-existing graph structure - the
walker-patterns rule is "no visit = def:pub function".
"""

import from jaclang.byllm.lib { Model }
import from schema { Function, abstracts_to }

glob fast_llm: any = Model(model_name="claude-haiku-4-5-20251001");
glob MAX_ABSTRACTION_HOPS: int = 3;

obj AbstractResult {
    has name: str;
    has domain_neutral_desc: str;
}
sem AbstractResult.name = "A more general, domain-neutral restatement of the function - what underlying principle does it serve? E.g. \"impact resistance at low temperature\" for \"won't crack in cold\".";
sem AbstractResult.domain_neutral_desc = "The same idea phrased the way a researcher in a completely unrelated field would describe it, with no product-specific vocabulary - e.g. \"energy absorption in brittle materials\".";

def abstract_one(function_desc: str, current_level: int) -> AbstractResult by fast_llm();
sem abstract_one = "Restate a concrete product function as ONE level more general, domain-neutral principle - climb only as high as still validates, don't overshoot into something the original function no longer implies.";
sem abstract_one.function_desc = "The current function description to generalize.";
sem abstract_one.current_level = "How many abstraction hops have already been taken (0 = the original concrete function).";

def:pub abstract_function(function_id: str) -> list[Function] {
    try {
        target = jobj(function_id);
    } except Exception {
        return [];
    }
    if not isinstance(target, Function) {
        return [];
    }

    created: list[Function] = [];
    current = target;
    hop = current.abstraction_level;

    while hop < MAX_ABSTRACTION_HOPS {
        desc = current.domain_neutral_desc if len(current.domain_neutral_desc) > 0 else current.name;
        try {
            result = abstract_one(desc, hop);
        } except Exception {
            break;
        }
        hop = hop + 1;
        next_fn = Function(
            name=result.name,
            abstraction_level=hop,
            domain_neutral_desc=result.domain_neutral_desc
        );
        current +>:abstracts_to:+> next_fn;
        created.append(next_fn);
        current = next_fn;
    }

    return created;
}
