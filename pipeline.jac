"""Crosswalk - orchestrates abstract -> discover -> judge -> verify per
selected Function, fanning out across the whole selection at once. This is
where the demo's "no human monitors 40 subsystems, a walker does it at once"
line actually lives - the user multi-selects functions in the UI and every
one explores concurrently, not in a serial loop.

Plain (non-streaming) async endpoint, NOT a Generator/SSE stream: empirically
verified against this server that graph writes made inside a streaming
(Generator-returning) endpoint never durably commit - confirmed even with a
single sequential write and zero threading involved, so it isn't a
flow/asyncio concurrency issue, it's streaming responses specifically. A
plain async def:pub's writes commit normally (also verified). This costs the
incremental live progress log; the client instead shows one "exploring"
spinner for the whole batch, then the completed results all at once. Genuine
concurrency (asyncio.to_thread) is kept for wall-clock speed - that's still
what proves the "no human babysits N subsystems" line, just without a
per-function progress trickle.
"""

import asyncio;
import from schema { Function, ResearchWork }
import from abstract { abstract_function }
import from discovery { discover_candidates }
import from judge { judge_candidate }
import from verify { verify_function }

def process_one_function(function_id: str) -> str {
    try {
        fn = jobj(function_id);
    } except Exception {
        return function_id;
    }
    if not isinstance(fn, Function) {
        return function_id;
    }

    fn.deep_status = "exploring";

    try {
        leaves = abstract_function(function_id);
        deepest_id = jid(leaves[-1]) if len(leaves) > 0 else function_id;

        works = discover_candidates(deepest_id);
        for w in works {
            judge_candidate(jid(w));
        }
        verify_function(deepest_id);

        fn.deep_status = "done";
    } except Exception {
        fn.deep_status = "failed";
    }

    return function_id;
}

async def:pub explore_functions(function_ids: list[str]) -> list[str] {
    results = await asyncio.gather(*[
        asyncio.to_thread(process_one_function, fid) for fid in function_ids
    ]);
    return list(results);
}
