"""Crosswalk - Client Shell (stateful shell, see jac-cl-organization).

Owns all page state; handler bodies live in frontend.impl.jac.
"""

sv import from .decompose { decompose_product }
sv import from .schema { Product }
sv import from .views { get_graph_view, get_hop_path, GraphView, HopStep, WorkDetail }
sv import from .baseline { get_keyword_baseline, BaselineHit }
sv import from .pipeline { explore_functions }
sv import from .chat { ask_about_research }
import from .ForceGraph { ForceGraph }
import from .ResearchPanel { ResearchPanel }

glob EXAMPLE_PRODUCTS: list[dict] = [
    {
        "label": "Camping stove (breadth beat)",
        "text": "A portable backpacking camping stove with a folding wind screen, piezo igniter, and adjustable fuel valve, used in high-altitude backcountry conditions.",
        "use_environment": "Used above treeline in cold, windy, high-UV backcountry conditions.",
    },
    {
        "label": "Competitive swimsuit (credibility move)",
        "text": "A competitive racing swimsuit fabric designed to reduce drag for elite swimmers.",
        "use_environment": "Worn in chlorinated pool water at racing speeds.",
    },
    {
        "label": "Insulated cooler (wow beat)",
        "text": "A hard-sided insulated cooler with a battery-powered compressor and passive ice retention, used to keep food cold for multi-day trips.",
        "use_environment": "Left in direct sun in a truck bed in the desert.",
    },
];

def:pub app -> JsxElement {
    has product_text: str = "",
        use_environment: str = "",
        product: Product | None = None,
        graph: GraphView | None = None,
        loading: bool = False,
        error: str = "";

    has selected_function_ids: list[str] = [],
        exploring: bool = False,
        progress_log: list[str] = [],
        send_deep_error: str = "";

    has baseline_hits: list[BaselineHit] | None = None,
        baseline_loading: bool = False;

    has selected_work_id: str | None = None,
        hop_path_steps: list[HopStep] | None = None,
        hop_path_detail: WorkDetail | None = None,
        hop_path_loading: bool = False;

    has chat_messages: list[dict] = [],
        chat_input: str = "",
        chat_loading: bool = False;

    async def handle_decompose -> None;
    async def handle_node_click(node_id: str, kind: str) -> None;
    async def handle_send_deep -> None;
    async def handle_show_baseline -> None;
    async def handle_ask -> None;
    def handle_close_hop_path -> None;
    def handle_prefill(example: dict) -> None;
    def handle_chat_input_change(value: str) -> None;

    return <div style={{"maxWidth": "1400px", "margin": "2rem auto", "padding": "0 1rem", "fontFamily": "system-ui, -apple-system, sans-serif"}}>
        <h1>Crosswalk</h1>
        <p style={{"color": "#666"}}>
            Paste a product description. Crosswalk decomposes it live, then walks
            OpenAlex for cross-domain research that serves the same functions.
        </p>

        <div style={{"display": "flex", "gap": "0.5rem", "flexWrap": "wrap", "marginBottom": "0.5rem"}}>
            {for (i, example) in enumerate(EXAMPLE_PRODUCTS) {
                <button
                    key={str(i)}
                    onClick={lambda (e: MouseEvent) { handle_prefill(example); }}
                    style={{"padding": "0.3rem 0.7rem", "fontSize": "0.8rem", "border": "1px solid #ddd", "borderRadius": "999px", "backgroundColor": "#f9fafb", "cursor": "pointer"}}
                >
                    {example["label"] as str}
                </button>
            }}
        </div>

        <textarea
            value={product_text}
            onChange={lambda (e: ChangeEvent) { product_text = e.target.value; }}
            placeholder="e.g. A camping stove with a folding wind screen, used in high-altitude backcountry conditions..."
            rows={4}
            style={{"width": "100%", "padding": "0.6rem", "border": "1px solid #ddd", "borderRadius": "6px", "fontFamily": "inherit", "boxSizing": "border-box"}}
        />
        <input
            type="text"
            value={use_environment}
            onChange={lambda (e: ChangeEvent) { use_environment = e.target.value; }}
            placeholder="Use environment (optional) - e.g. 'truck bed in the desert'"
            style={{"width": "100%", "marginTop": "0.5rem", "padding": "0.6rem", "border": "1px solid #ddd", "borderRadius": "6px", "boxSizing": "border-box"}}
        />
        <button
            onClick={handle_decompose}
            disabled={loading or len(product_text.strip()) == 0}
            style={{"marginTop": "0.75rem", "padding": "0.6rem 1.2rem", "backgroundColor": "#2563eb", "color": "white", "border": "none", "borderRadius": "6px", "cursor": "pointer"}}
        >
            {"Decomposing..." if loading else "Decompose"}
        </button>

        {if error {
            <p key="error" style={{"color": "#b91c1c"}}>{error}</p>
        }}

        {if graph is not None {
            <div key="graph-section">
                <div style={{"marginTop": "1.5rem", "padding": "1rem", "border": "1px solid #e5e7eb", "borderRadius": "8px", "backgroundColor": "#fafafa"}}>
                    <div style={{"display": "flex", "alignItems": "center", "gap": "0.75rem", "flexWrap": "wrap"}}>
                        <button
                            onClick={handle_send_deep}
                            disabled={exploring or len(selected_function_ids) == 0}
                            style={{
                                "padding": "0.7rem 1.4rem",
                                "backgroundColor": "#d1d5db" if (exploring or len(selected_function_ids) == 0) else "#f59e0b",
                                "color": "white",
                                "border": "none",
                                "borderRadius": "6px",
                                "cursor": "not-allowed" if (exploring or len(selected_function_ids) == 0) else "pointer",
                                "fontWeight": "bold",
                                "fontSize": "0.95rem",
                                "boxShadow": "none" if (exploring or len(selected_function_ids) == 0) else "0 2px 6px rgba(245, 158, 11, 0.4)"
                            }}
                        >
                            {"Exploring..." if exploring else f"Send Deep ({len(selected_function_ids)} selected)"}
                        </button>
                        <button
                            onClick={handle_show_baseline}
                            disabled={baseline_loading or len(selected_function_ids) == 0}
                            style={{"padding": "0.6rem 1rem", "fontSize": "0.85rem", "border": "1px solid #ddd", "borderRadius": "6px", "backgroundColor": "white", "cursor": "pointer"}}
                        >
                            {"Loading..." if baseline_loading else "Compare to plain keyword search"}
                        </button>
                    </div>
                    <p style={{"color": "#666", "fontSize": "0.85rem", "marginTop": "0.5rem", "marginBottom": "0"}}>
                        {"Exploring all selected functions concurrently - this can take a minute or so..." if exploring else "Click Function nodes (green) below to select, then Send Deep."}
                    </p>

                    {if len(send_deep_error) > 0 {
                        <p key="send-deep-error" style={{"color": "#b91c1c", "fontSize": "0.85rem", "marginTop": "0.5rem", "marginBottom": "0"}}>{send_deep_error}</p>
                    }}

                    {if baseline_hits is not None {
                        <div key="baseline" style={{"marginTop": "0.5rem", "padding": "0.75rem", "border": "1px dashed #d1d5db", "borderRadius": "8px"}}>
                            <strong style={{"fontSize": "0.85rem"}}>Plain keyword search on the literal function text (no field-distance weighting):</strong>
                            {if len(baseline_hits) == 0 {
                                <p style={{"fontSize": "0.85rem", "color": "#666"}}>No results.</p>
                            }}
                            <ul style={{"fontSize": "0.85rem", "color": "#666"}}>
                                {for (i, hit) in enumerate(baseline_hits) {
                                    <li key={str(i)}>{hit.title} ({hit.year}) - {hit.field_name}</li>
                                }}
                            </ul>
                        </div>
                    }}

                    {if len(progress_log) > 0 {
                        <p key="progress" style={{"fontSize": "0.85rem", "color": "#666", "marginTop": "0.5rem", "marginBottom": "0"}}>
                            Last run: explored {len(progress_log)} function(s) concurrently.
                        </p>
                    }}
                </div>

                <div style={{"display": "flex", "gap": "1rem", "marginTop": "1rem", "alignItems": "stretch"}}>
                    <div style={{"flex": "1", "height": "720px", "border": "1px solid #e5e7eb", "borderRadius": "8px", "minWidth": "0"}}>
                        <ForceGraph nodes={graph.nodes} edges={graph.edges} selectedIds={selected_function_ids} onNodeClick={handle_node_click} />
                    </div>
                    <div style={{"width": "380px", "flexShrink": "0", "height": "720px", "border": "1px solid #e5e7eb", "borderRadius": "8px", "overflow": "hidden"}}>
                        <ResearchPanel
                            steps={hop_path_steps}
                            detail={hop_path_detail}
                            loading={hop_path_loading}
                            chatMessages={chat_messages}
                            chatInput={chat_input}
                            chatLoading={chat_loading}
                            onChatInputChange={handle_chat_input_change}
                            onAsk={handle_ask}
                            onClose={handle_close_hop_path}
                        />
                    </div>
                </div>
            </div>
        }}
    </div>;
}
