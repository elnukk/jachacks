"""Crosswalk - Graph Schema.

The graph a Product decomposes into: Product -> Component -> Function, with
Function -> Function abstraction hops (abstracts_to) and ResearchWork -> Function
discovery hits (serves_function, payoff edge per the PRD). Judge + Verify results
live directly on the serves_function edge since that's what the client
sorts/colors/renders by. Hop-path traversal (a clicked ResearchWork back up to its
Product) walks one hop forward over serves_function, then backward over
abstracts_to / requires_function / has_component - see views.jac.

No Field node and no field_distance edge - field distance is a pure function
(see distance.jac) over each side's OpenAlex topic hierarchy, not graph structure.
"""

node Product {
    has name: str = "",
        description: str = "",
        use_environment: str = "",
        status: str = "decomposing";   # "decomposing" | "ready" | "failed"
    has home_domain_id: str = "", home_domain_name: str = "",
        home_field_id: str = "", home_field_name: str = "",
        home_subfield_id: str = "", home_subfield_name: str = "";
}

node Component {
    has name: str = "";   # e.g. "battery pack", "housing seal"
}

node Function {
    has name: str = "",
        abstraction_level: int = 0,           # 0 = concrete feature, higher = more general
        domain_neutral_desc: str = "";
    has deep_status: str = "idle";            # "idle" | "exploring" | "done" | "failed"
}

node ResearchWork {
    has title: str = "", abstract: str = "", oa_id: str = "",
        year: int = 0, citation_count: int = 0;
    has domain_id: str = "", domain_name: str = "",
        field_id: str = "", field_name: str = "",
        subfield_id: str = "", subfield_name: str = "",
        topic_id: str = "", topic_name: str = "";
}

edge has_component: Product --> Component {}
edge requires_function: Component --> Function {}
edge abstracts_to: Function --> Function {}   # concrete -> more general

edge serves_function: ResearchWork --> Function {
    has functional_relevance: float = 0.0,
        field_distance: int = 0,
        rank_score: float = 0.0;
    has maturity: str = "", transfer_difficulty: str = "";
    has surprise_flag: bool = False;
    has translation: str = "";
    has verify_status: str = "pending";   # "pending" | "verified" | "rejected" | "dropped"
}
