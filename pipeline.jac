"""Crosswalk - orchestrates abstract -> discover -> judge -> verify per
selected Function.

Fixed-cost pipeline per function: exactly one abstraction hop (merged with
query-variant generation), one free similarity pre-filter, one batched Judge
call, one Verify call on the top candidate only. No multi-level retry climb -
that was tried and produced a combinatorial explosion of model calls (up to
~24 per function), both expensive and, on local inference, too slow to use.

SEQUENTIAL, not concurrent - a deliberate change from an earlier version of
this file. Multiple functions used to fan out via asyncio.to_thread for true
parallelism, which is fine and desirable against a stateless cloud API (each
call is an independent HTTP request). Against the local model (llama.cpp via
llama-cpp-python) it is not just slower, it SEGFAULTS - confirmed with a
minimal repro: two calls to the same model instance from two different
threads crashes deep in llama.cpp's tensor allocation
(ggml_new_buffer/ggml_new_tensor) inside the worker thread. The local
inference engine is not thread-safe for concurrent/cross-thread use of one
loaded model, so every function is processed one at a time on the same
thread the request came in on. This does cost the "walker fans out in
parallel" demo beat when running on local inference - correctness has to
come first.

Plain (non-async) def:pub - no await needed once there's no
asyncio.gather/to_thread left to await. See jac-sv-persistence: graph writes
made inside a streaming (Generator-returning) endpoint never durably commit
in this server version, which is why this stays a plain request/response
endpoint rather than an SSE stream with incremental progress.
"""

import from time { time }
import from schema { Function, ResearchWork, serves_function }
import from abstract { abstract_one_level }
import from discovery { discover_candidates }
import from judge { judge_candidates }
import from verify { verify_function }

def has_verified_result(function_id: str) -> bool {
    try {
        fn = jobj(function_id);
    } except Exception {
        return False;
    }
    if not isinstance(fn, Function) {
        return False;
    }
    for e in [edge fn <-:serves_function:<-] {
        if e.verify_status == "verified" {
            return True;
        }
    }
    return False;
}

def process_one_function(function_id: str) -> str {
    try {
        fn = jobj(function_id);
    } except Exception as e {
        print(f"[pipeline] {function_id} jobj() raised: {str(e)}");
        return function_id;
    }
    if not isinstance(fn, Function) {
        print(f"[pipeline] {function_id} jobj() returned non-Function: {type(fn)}");
        return function_id;
    }

    fn.deep_status = "exploring";
    t0 = time();
    print(f"[pipeline] {function_id} START");

    try {
        print(f"[pipeline] {function_id} calling abstract_one_level at +{time() - t0:.1f}s");
        step = abstract_one_level(function_id);
        print(f"[pipeline] {function_id} abstract_one_level returned at +{time() - t0:.1f}s (step is None: {step is None})");
        if step is None {
            fn.deep_status = "no_results";
            return function_id;
        }
        current_id = jid(step.next_function);

        print(f"[pipeline] {function_id} calling discover_candidates at +{time() - t0:.1f}s");
        works = discover_candidates(current_id, step.search_queries);
        print(f"[pipeline] {function_id} discover_candidates returned {len(works)} works at +{time() - t0:.1f}s");

        if len(works) > 0 {
            work_ids = [jid(w) for w in works];
            print(f"[pipeline] {function_id} calling judge_candidates at +{time() - t0:.1f}s");
            judge_candidates(current_id, work_ids);
            print(f"[pipeline] {function_id} judge_candidates returned at +{time() - t0:.1f}s");

            print(f"[pipeline] {function_id} calling verify_function at +{time() - t0:.1f}s");
            verify_function(current_id);
            print(f"[pipeline] {function_id} verify_function returned at +{time() - t0:.1f}s");
        }

        fn.deep_status = "done" if has_verified_result(current_id) else "no_results";
        print(f"[pipeline] {function_id} DONE at +{time() - t0:.1f}s, status={fn.deep_status}");
    } except Exception as e {
        fn.deep_status = "failed";
        print(f"[pipeline] {function_id} FAILED at +{time() - t0:.1f}s: {str(e)}");
    }

    return function_id;
}

def:pub explore_functions(function_ids: list[str]) -> list[str] {
    return [process_one_function(fid) for fid in function_ids];
}
