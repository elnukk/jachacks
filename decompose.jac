"""Crosswalk - Live Decompose + home-field resolution.

Promoted from the PRD's "cached demo product" stretch-goal scope to core:
every call to decompose_product runs the LLM decomposition AND the OpenAlex
home-field lookup live, for arbitrary pasted product text. No fixtures.
"""

import openalex_client;
import from jaclang.byllm.lib { Model }
import from schema { Product, Component, Function, has_component, requires_function }

glob fast_llm: Model = Model(model_name="claude-haiku-4-5-20251001");

obj FunctionSpec {
    has name: str;
    has domain_neutral_desc: str = "";
}
sem FunctionSpec.name = "A specific function/requirement this component must satisfy, stated in plain product-spec language (e.g. \"won't crack in cold\", \"keeps water out\").";
sem FunctionSpec.domain_neutral_desc = "Leave this blank - it is filled in later by a separate abstraction step.";

obj ComponentSpec {
    has name: str;
    has functions: list[FunctionSpec] = [];
}
sem ComponentSpec.name = "A physical or logical component of the product (e.g. \"battery pack\", \"housing seal\", \"handle grip\").";
sem ComponentSpec.functions = "Every function this component must perform. Include functions implied by the stated use environment even when not explicitly stated in the product text - e.g. \"used in a truck bed in the desert\" implies UV resistance, thermal cycling, and vibration resistance.";

obj Decomposition {
    has components: list[ComponentSpec] = [];
}
sem Decomposition.components = "Every physical or logical component of the product, derived from its stated specs plus world knowledge of how this class of product is typically built.";

def decompose(product_text: str, use_environment: str) -> Decomposition by fast_llm();
sem decompose = "Decompose a product description into its physical/logical components and every function each component must perform, including functions implied by its use environment.";
sem decompose.product_text = "The product's name, description, and/or pasted spec text.";
sem decompose.use_environment = "Where/how the product is used - may be empty. Use it to infer additional environmental functions (UV, cold, vibration, moisture, impact, etc).";

def:pub decompose_product(text: str, use_environment: str = "") -> Product {
    product = root ++> Product(
        name=text[:80],
        description=text,
        use_environment=use_environment,
        status="decomposing"
    );

    try {
        result = decompose(text, use_environment);
    } except Exception {
        product.status = "failed";
        return product;
    }

    for comp_spec in result.components {
        component = Component(name=comp_spec.name);
        product +>:has_component:+> component;
        for fn_spec in comp_spec.functions {
            function = Function(name=fn_spec.name);
            component +>:requires_function:+> function;
        }
    }

    try {
        home = openalex_client.resolve_home_field(text);
        if home is not None {
            product.home_domain_id = home["domain_id"] as str;
            product.home_domain_name = home["domain_name"] as str;
            product.home_field_id = home["field_id"] as str;
            product.home_field_name = home["field_name"] as str;
            product.home_subfield_id = home["subfield_id"] as str;
            product.home_subfield_name = home["subfield_name"] as str;
        }
    } except Exception {
        # Home-field resolution is a nice-to-have for later ranking - a live
        # OpenAlex hiccup here should not fail the whole decomposition.
    }

    product.status = "ready";
    return product;
}
