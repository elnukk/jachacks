"""Crosswalk - Interactive Abstract (per-function, on demand).

Triggered when the user selects a Function in the UI and sends it deep -
never automatic across the whole ~40-node decomposition (see README non-goal
"no recursive depth on every node"). No walker: this only creates new nodes
and connects them, it never visits pre-existing graph structure - the
walker-patterns rule is "no visit = def:pub function".

Exactly ONE abstraction hop per Send Deep, not a multi-level climb: each
additional level used to mean a full discover+judge+verify pass, and with
several candidates and retries that multiplied into dozens of model calls
per function - genuinely too slow/expensive to be usable, especially once
running on local inference where each call costs real wall-clock time, not
just money. A single hop keeps the whole pipeline fast and predictable.

Abstraction and search-query generation are ONE model call, not two - the
model already has to understand the function's domain-neutral principle to
do either job, so it does both in the same structured response.
"""

import from schema { Function, abstracts_to }
import from models { shared_llm }

glob QUERY_VARIANTS_CAP: int = 2;

obj AbstractAndQueries {
    has name: str;
    has domain_neutral_desc: str;
    has search_queries: list[str];
}
sem AbstractAndQueries.name = "A more general, domain-neutral restatement of the function - what underlying principle does it serve? E.g. \"impact resistance at low temperature\" for \"won't crack in cold\".";
sem AbstractAndQueries.domain_neutral_desc = "The same idea phrased the way a researcher in a completely unrelated field would describe it, with no product-specific vocabulary - e.g. \"energy absorption in brittle materials\".";
sem AbstractAndQueries.search_queries = "Exactly 2 differently-worded literature-search queries for that domain-neutral principle, each using vocabulary characteristic of a DIFFERENT field or discipline - genuinely different disciplinary framings, not paraphrases in the same register.";

def abstract_and_queries(function_desc: str, current_level: int) -> AbstractAndQueries by shared_llm();
sem abstract_and_queries = "Restate a concrete product function as ONE level more general, domain-neutral principle - climb only as high as still validates - AND generate 2 differently-worded literature-search queries for that principle, each phrased like a different field's literature. Do both in one response.";
sem abstract_and_queries.function_desc = "The current function description to generalize.";
sem abstract_and_queries.current_level = "How many abstraction hops have already been taken (0 = the original concrete function).";

obj AbstractStepResult {
    has next_function: Function;
    has search_queries: list[str];
}

def:pub abstract_one_level(function_id: str) -> AbstractStepResult | None {
    try {
        target = jobj(function_id);
    } except Exception {
        return None;
    }
    if not isinstance(target, Function) {
        return None;
    }

    desc = target.domain_neutral_desc if len(target.domain_neutral_desc) > 0 else target.name;
    print(f"[abstract] calling abstract_and_queries for '{desc}'");
    try {
        result = abstract_and_queries(desc, target.abstraction_level);
    } except Exception as e {
        print(f"[abstract] abstract_and_queries raised: {str(e)}");
        return None;
    }
    print(f"[abstract] abstract_and_queries returned: {result.name}");

    next_fn = Function(
        name=result.name,
        abstraction_level=target.abstraction_level + 1,
        domain_neutral_desc=result.domain_neutral_desc
    );
    target +>:abstracts_to:+> next_fn;

    queries = result.search_queries[:QUERY_VARIANTS_CAP] if len(result.search_queries) > 0 else [result.domain_neutral_desc];
    return AbstractStepResult(next_function=next_fn, search_queries=queries);
}
