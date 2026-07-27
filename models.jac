"""Crosswalk - shared model instance.

Switched back to Claude (from local:gemma-4-e4b) - the local model stalled
indefinitely (9+ minutes, no completion, no crash) on the very first
structured-output call, with no time left before submission to root-cause
llama.cpp/grammar-decoding internals. The call-count reduction work (single
shared instance, batched judge, single-hop abstraction, similarity
pre-filter) already cut this down to ~6-7 calls per function, which is cheap
and fast on Claude - that's what actually matters for cost, not the
provider. One shared instance, reused everywhere, same as before.
"""

import from jaclang.byllm.lib { Model }

glob shared_llm: any = Model(model_name="anthropic/claude-haiku-4-5-20251001");
