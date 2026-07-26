"""Crosswalk - Graph view projections for the client.

get_graph_view() gives the force-graph client a flat {nodes, edges} payload
instead of raw typed nodes - see jac-sv-persistence's to_view() pattern.
Only verified serves_function edges render - rejected/dropped candidates stay
in the graph for transparency/debugging but are not part of the rendered view.
"""

import from schema { Product, Component, Function, ResearchWork, has_component, requires_function, abstracts_to, serves_function }

obj GraphNode {
    has id: str, kind: str, label: str;
    has val: float = 1.0;
}

obj GraphEdge {
    has source: str, target: str, kind: str;
    has verify_status: str = "", rank_score: float = 0.0;
}

obj GraphView {
    has nodes: list[GraphNode] = [], edges: list[GraphEdge] = [];
}

obj HopStep {
    has kind: str, label: str;
}

obj WorkDetail {
    has title: str = "", abstract: str = "", oa_id: str = "",
        year: int = 0, citation_count: int = 0;
    has domain_name: str = "", field_name: str = "", subfield_name: str = "";
    has functional_relevance: float = 0.0, field_distance: int = 0, rank_score: float = 0.0;
    has maturity: str = "", transfer_difficulty: str = "", surprise_flag: bool = False;
    has translation: str = "";
}

obj HopPathResult {
    has steps: list[HopStep] = [];
    has detail: WorkDetail | None = None;
}

def find_owning_product(fn: Function) -> Product | None {
    current = fn;
    while True {
        parents = [current <-:abstracts_to:<-][?:Function];
        if len(parents) == 0 {
            break;
        }
        current = parents[0];
    }
    components = [current <-:requires_function:<-][?:Component];
    if len(components) == 0 {
        return None;
    }
    products = [components[0] <-:has_component:<-][?:Product];
    if len(products) == 0 {
        return None;
    }
    return products[0];
}

def collect_function_descendants(fn: Function) -> list[Function] {
    result = [fn];
    for child in [fn ->:abstracts_to:->][?:Function] {
        result = result + collect_function_descendants(child);
    }
    return result;
}

def:pub get_graph_view(product_id: str) -> GraphView | None {
    try {
        product = jobj(product_id);
    } except Exception {
        return None;
    }
    if not isinstance(product, Product) {
        return None;
    }

    nodes: list[GraphNode] = [GraphNode(id=jid(product), kind="Product", label=product.name)];
    edges: list[GraphEdge] = [];

    for component in [product ->:has_component:->][?:Component] {
        nodes.append(GraphNode(id=jid(component), kind="Component", label=component.name));
        edges.append(GraphEdge(source=jid(product), target=jid(component), kind="has_component"));

        for top_fn in [component ->:requires_function:->][?:Function] {
            edges.append(GraphEdge(source=jid(component), target=jid(top_fn), kind="requires_function"));

            for fn in collect_function_descendants(top_fn) {
                nodes.append(GraphNode(id=jid(fn), kind="Function", label=fn.name));
                for child in [fn ->:abstracts_to:->][?:Function] {
                    edges.append(GraphEdge(source=jid(fn), target=jid(child), kind="abstracts_to"));
                }

                works = [fn <-:serves_function:<-][?:ResearchWork];
                work_edges = [edge fn <-:serves_function:<-];
                for i in range(len(works)) {
                    w = works[i];
                    e = work_edges[i];
                    if e.verify_status != "verified" {
                        continue;
                    }
                    nodes.append(GraphNode(id=jid(w), kind="ResearchWork", label=w.title, val=1.0 + e.rank_score));
                    edges.append(GraphEdge(
                        source=jid(w), target=jid(fn), kind="serves_function",
                        verify_status=e.verify_status, rank_score=e.rank_score
                    ));
                }
            }
        }
    }

    return GraphView(nodes=nodes, edges=edges);
}

def build_hop_path(work: ResearchWork) -> HopPathResult | None {
    functions = [work ->:serves_function:->][?:Function];
    if len(functions) == 0 {
        return None;
    }
    served_fn = functions[0];

    work_edges = [edge work ->:serves_function:->];
    if len(work_edges) == 0 {
        return None;
    }
    e = work_edges[0];

    chain = [served_fn];
    current = served_fn;
    while True {
        parents = [current <-:abstracts_to:<-][?:Function];
        if len(parents) == 0 {
            break;
        }
        current = parents[0];
        chain.append(current);
    }
    chain.reverse();

    base_fn = chain[0];
    components = [base_fn <-:requires_function:<-][?:Component];
    if len(components) == 0 {
        return None;
    }
    component = components[0];
    products = [component <-:has_component:<-][?:Product];
    if len(products) == 0 {
        return None;
    }
    product = products[0];

    steps: list[HopStep] = [
        HopStep(kind="Product", label=product.name),
        HopStep(kind="Component", label=component.name),
    ];
    for fn in chain {
        steps.append(HopStep(kind="Function", label=fn.name));
    }
    steps.append(HopStep(kind="ResearchWork", label=work.title));

    detail = WorkDetail(
        title=work.title, abstract=work.abstract, oa_id=work.oa_id,
        year=work.year, citation_count=work.citation_count,
        domain_name=work.domain_name, field_name=work.field_name, subfield_name=work.subfield_name,
        functional_relevance=e.functional_relevance, field_distance=e.field_distance, rank_score=e.rank_score,
        maturity=e.maturity, transfer_difficulty=e.transfer_difficulty, surprise_flag=e.surprise_flag,
        translation=e.translation
    );

    return HopPathResult(steps=steps, detail=detail);
}

def:pub get_hop_path(work_id: str) -> HopPathResult | None {
    try {
        work = jobj(work_id);
    } except Exception {
        return None;
    }
    if not isinstance(work, ResearchWork) {
        return None;
    }
    return build_hop_path(work);
}
