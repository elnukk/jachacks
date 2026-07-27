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

glob FONT_FAMILY: str = "'Figtree', sans-serif";
glob COLOR_ACCENT: str = "#6366f1";
glob COLOR_TEXT_PRIMARY: str = "#111827";
glob COLOR_TEXT_SECONDARY: str = "#6b7280";
glob COLOR_TEXT_MUTED: str = "#9ca3af";
glob GLASS_SHADOW: str = "0 4px 16px rgba(0,0,0,0.06), 0 1px 4px rgba(0,0,0,0.04), inset 0 1px 0 rgba(255,255,255,0.8)";

def:pub app -> JsxElement {
    has product_text: str = "",
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
    def handle_chat_input_change(value: str) -> None;

    return <div style={{
        "minHeight": "100vh",
        "background": "radial-gradient(ellipse at 15% 20%, rgba(99,102,241,0.09) 0%, transparent 55%), radial-gradient(ellipse at 85% 75%, rgba(14,165,233,0.07) 0%, transparent 55%), #eef0f6"
    }}>
        <style>{"""
            @import url('https://fonts.googleapis.com/css2?family=Figtree:wght@300;400;500;600;700&display=swap');
            .float-tooltip-kap {
                background: rgba(255,255,255,0.95) !important;
                backdrop-filter: blur(12px) !important;
                -webkit-backdrop-filter: blur(12px) !important;
                border: 1px solid rgba(255,255,255,0.9) !important;
                border-radius: 10px !important;
                padding: 0.5rem 0.75rem !important;
                font-family: 'Figtree', sans-serif !important;
                font-weight: 500 !important;
                font-size: 0.85rem !important;
                color: #111827 !important;
                box-shadow: 0 8px 24px rgba(0,0,0,0.12), 0 2px 8px rgba(0,0,0,0.06) !important;
                max-width: 280px !important;
                line-height: 1.4 !important;
            }
        """}</style>

        <div style={{"maxWidth": "1700px", "margin": "0 auto", "padding": "2rem 1rem", "fontFamily": FONT_FAMILY}}>
            <h1 style={{"color": COLOR_TEXT_PRIMARY, "fontWeight": "600", "letterSpacing": "-0.01em", "marginBottom": "0.25rem"}}>Crosswalk</h1>
            <p style={{"color": COLOR_TEXT_SECONDARY, "fontWeight": "500"}}>
                Paste a product description. Crosswalk decomposes it live, then walks
                OpenAlex for cross-domain research that serves the same functions.
            </p>

            <textarea
                value={product_text}
                onChange={lambda (e: ChangeEvent) { product_text = e.target.value; }}
                placeholder="e.g. A camping stove with a folding wind screen, used in high-altitude backcountry conditions..."
                rows={4}
                style={{
                    "width": "100%", "padding": "0.85rem", "fontFamily": "inherit", "fontWeight": "500",
                    "fontSize": "0.95rem", "color": COLOR_TEXT_PRIMARY, "boxSizing": "border-box",
                    "background": "rgba(255,255,255,0.72)", "border": "1px solid rgba(255,255,255,0.9)",
                    "backdropFilter": "blur(20px)", "borderRadius": "14px", "boxShadow": GLASS_SHADOW,
                    "outline": "none"
                }}
            />
            <button
                onClick={handle_decompose}
                disabled={loading or len(product_text.strip()) == 0}
                style={{
                    "marginTop": "0.85rem", "padding": "0.7rem 1.4rem",
                    "backgroundColor": "#c7c9d9" if (loading or len(product_text.strip()) == 0) else COLOR_ACCENT,
                    "color": "white", "border": "none", "borderRadius": "12px",
                    "cursor": "not-allowed" if (loading or len(product_text.strip()) == 0) else "pointer",
                    "fontFamily": "inherit", "fontWeight": "600", "fontSize": "0.95rem",
                    "boxShadow": "none" if (loading or len(product_text.strip()) == 0) else "0 4px 14px rgba(99,102,241,0.35)"
                }}
            >
                {"Decomposing..." if loading else "Decompose"}
            </button>

            {if error {
                <p key="error" style={{"color": "#b91c1c", "fontWeight": "500"}}>{error}</p>
            }}

            {if graph is not None {
                <div key="graph-section">
                    <div style={{
                        "marginTop": "1.5rem", "padding": "1.1rem 1.25rem",
                        "background": "rgba(255,255,255,0.72)", "border": "1px solid rgba(255,255,255,0.9)",
                        "backdropFilter": "blur(20px)", "borderRadius": "14px", "boxShadow": GLASS_SHADOW
                    }}>
                        <div style={{"display": "flex", "alignItems": "center", "gap": "0.75rem", "flexWrap": "wrap"}}>
                            <button
                                onClick={handle_send_deep}
                                disabled={exploring or len(selected_function_ids) == 0}
                                style={{
                                    "padding": "0.7rem 1.4rem",
                                    "backgroundColor": "#c7c9d9" if (exploring or len(selected_function_ids) == 0) else COLOR_ACCENT,
                                    "color": "white",
                                    "border": "none",
                                    "borderRadius": "12px",
                                    "cursor": "not-allowed" if (exploring or len(selected_function_ids) == 0) else "pointer",
                                    "fontFamily": "inherit",
                                    "fontWeight": "600",
                                    "fontSize": "0.95rem",
                                    "boxShadow": "none" if (exploring or len(selected_function_ids) == 0) else "0 4px 14px rgba(99,102,241,0.35)"
                                }}
                            >
                                {"Exploring..." if exploring else f"Send Deep ({len(selected_function_ids)} selected)"}
                            </button>
                            <button
                                onClick={handle_show_baseline}
                                disabled={baseline_loading or len(selected_function_ids) == 0}
                                style={{
                                    "padding": "0.6rem 1.1rem", "fontSize": "0.85rem", "fontFamily": "inherit", "fontWeight": "500",
                                    "border": "1px solid rgba(0,0,0,0.07)", "borderRadius": "12px",
                                    "backgroundColor": "rgba(255,255,255,0.6)", "color": COLOR_TEXT_PRIMARY, "cursor": "pointer"
                                }}
                            >
                                {"Loading..." if baseline_loading else "Compare to plain keyword search"}
                            </button>
                        </div>
                        <p style={{"color": COLOR_TEXT_SECONDARY, "fontWeight": "500", "fontSize": "0.85rem", "marginTop": "0.5rem", "marginBottom": "0"}}>
                            {"Exploring all selected functions concurrently - this can take a minute or so..." if exploring else "Click Function nodes below to select, then Send Deep."}
                        </p>

                        {if len(send_deep_error) > 0 {
                            <p key="send-deep-error" style={{"color": "#b91c1c", "fontWeight": "500", "fontSize": "0.85rem", "marginTop": "0.5rem", "marginBottom": "0"}}>{send_deep_error}</p>
                        }}

                        {if baseline_hits is not None {
                            <div key="baseline" style={{
                                "marginTop": "0.6rem", "padding": "0.85rem",
                                "background": "rgba(255,255,255,0.5)", "border": "1px dashed rgba(0,0,0,0.12)", "borderRadius": "12px"
                            }}>
                                <strong style={{"fontSize": "0.85rem", "color": COLOR_TEXT_PRIMARY, "fontWeight": "600"}}>Plain keyword search on the literal function text (no field-distance weighting):</strong>
                                {if len(baseline_hits) == 0 {
                                    <p style={{"fontSize": "0.85rem", "color": COLOR_TEXT_SECONDARY}}>No results.</p>
                                }}
                                <ul style={{"fontSize": "0.85rem", "color": COLOR_TEXT_SECONDARY}}>
                                    {for (i, hit) in enumerate(baseline_hits) {
                                        <li key={str(i)}>{hit.title} ({hit.year}) - {hit.field_name}</li>
                                    }}
                                </ul>
                            </div>
                        }}

                        {if len(progress_log) > 0 {
                            <p key="progress" style={{"fontSize": "0.85rem", "color": COLOR_TEXT_SECONDARY, "fontWeight": "500", "marginTop": "0.5rem", "marginBottom": "0"}}>
                                Last run: explored {len(progress_log)} function(s) concurrently.
                            </p>
                        }}
                    </div>

                    <div style={{"display": "flex", "gap": "1rem", "marginTop": "1rem", "alignItems": "stretch"}}>
                        <div style={{
                            "flex": "1", "height": "800px", "minWidth": "0",
                            "background": "rgba(255,255,255,0.55)", "border": "1px solid rgba(255,255,255,0.9)",
                            "backdropFilter": "blur(20px)", "borderRadius": "14px", "boxShadow": GLASS_SHADOW, "overflow": "hidden"
                        }}>
                            <ForceGraph nodes={graph.nodes} edges={graph.edges} selectedIds={selected_function_ids} onNodeClick={handle_node_click} />
                        </div>
                        <div style={{
                            "width": "560px", "flexShrink": "0", "height": "800px", "overflow": "hidden",
                            "background": "rgba(255,255,255,0.72)", "border": "1px solid rgba(255,255,255,0.9)",
                            "backdropFilter": "blur(20px)", "borderRadius": "14px", "boxShadow": GLASS_SHADOW
                        }}>
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
        </div>
    </div>;
}
