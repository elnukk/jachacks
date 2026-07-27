"""Crosswalk - shared model instance.

Local models are expensive to load - a Model(model_name="local:...") glob
reads the whole GGUF file into memory and initializes a llama.cpp context.
Each .jac file that declared its OWN separate Model() instance (even when
pointing at the identical model file) got its own separate load - so a
pipeline that calls abstract.jac's model, then judge.jac's, then verify.jac's
was reloading the ~4.6GB model from scratch at every single hop. One shared
instance, loaded once at server start, reused everywhere.
"""

import from jaclang.byllm.lib { Model }

glob shared_llm: any = Model(model_name="local:gemma-4-e4b");
