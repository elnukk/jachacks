"""Crosswalk - research assistant sidebar: hop path + paper details in their
own card, and a separate, larger chat card scoped to whichever ResearchWork
node was last clicked. Kept as two distinct blocks (not one continuous
scroll) so the chat always gets real room instead of whatever's left over."""

sv import from .views { HopStep, WorkDetail }

def:pub ResearchPanel(
    steps: list[HopStep] | None,
    detail: WorkDetail | None,
    loading: bool = False,
    chatMessages: list[dict] = [],
    chatInput: str = "",
    chatLoading: bool = False,
    onChatInputChange: Callable[[str], None] | None = None,
    onAsk: Callable[[], None] | None = None,
    onClose: Callable[[], None] | None = None
) -> JsxElement {
    def handle_input(e: ChangeEvent) {
        if onChatInputChange {
            onChatInputChange(e.target.value);
        }
    }

    def handle_submit(e: FormEvent) {
        e.preventDefault();
        if onAsk {
            onAsk();
        }
    }

    if loading {
        return <div style={{"padding": "1rem", "color": "#6b7280", "fontFamily": "'Figtree', sans-serif", "fontWeight": "500", "fontSize": "0.9rem"}}>Loading research path...</div>;
    }

    if steps is None or detail is None {
        return <div style={{"padding": "1rem", "color": "#6b7280", "fontFamily": "'Figtree', sans-serif", "fontWeight": "500", "fontSize": "0.9rem"}}>
            Click a research paper node (orange) in the graph to see its hop path, read what it says, and ask questions about the connection.
        </div>;
    }

    return <div style={{"display": "flex", "flexDirection": "column", "height": "100%", "padding": "0.9rem", "boxSizing": "border-box", "gap": "0.75rem", "fontFamily": "'Figtree', sans-serif"}}>
        <div style={{
            "flexShrink": "0", "maxHeight": "42%", "overflowY": "auto", "padding": "0.85rem",
            "background": "rgba(255,255,255,0.5)", "border": "1px solid rgba(0,0,0,0.07)", "borderRadius": "12px"
        }}>
            <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center"}}>
                <strong style={{"fontSize": "0.9rem", "color": "#111827", "fontWeight": "600", "letterSpacing": "-0.01em"}}>Research path</strong>
                {if onClose {
                    <button onClick={lambda (_e: MouseEvent) { onClose(); }} style={{"border": "none", "background": "none", "cursor": "pointer", "color": "#6b7280", "fontSize": "0.8rem", "fontFamily": "inherit"}}>close</button>
                }}
            </div>

            <div style={{"marginTop": "0.5rem"}}>
                {for (i, step) in enumerate(steps) {
                    <div key={str(i)} style={{"display": "flex", "gap": "0.35rem", "fontSize": "0.78rem", "fontWeight": "500", "marginBottom": "0.15rem", "paddingLeft": f"{i * 0.6}rem"}}>
                        <span style={{"color": "#9ca3af"}}>{step.kind}:</span>
                        <span style={{"color": "#111827"}}>{step.label}</span>
                    </div>
                }}
            </div>

            <div style={{"marginTop": "0.6rem", "padding": "0.7rem", "backgroundColor": "rgba(99,102,241,0.08)", "border": "1px solid rgba(99,102,241,0.2)", "borderRadius": "10px"}}>
                <div style={{"fontWeight": "600", "fontSize": "0.85rem", "color": "#111827"}}>{detail.title}</div>
                <div style={{"fontSize": "0.7rem", "color": "#6366f1", "fontWeight": "500", "marginTop": "0.15rem"}}>
                    {detail.field_name} ({detail.year}) - {detail.citation_count} citations
                </div>
                <p style={{"fontSize": "0.78rem", "fontWeight": "500", "color": "#111827", "marginTop": "0.4rem", "marginBottom": "0.3rem"}}>{detail.translation}</p>
                <div style={{"fontSize": "0.7rem", "color": "#6b7280", "fontWeight": "500"}}>
                    relevance {f"{detail.functional_relevance:.2f}"} - field distance {detail.field_distance} - {detail.maturity} - transfer: {detail.transfer_difficulty}
                </div>
                {if len(detail.oa_id) > 0 {
                    <a key="oa-link" href={detail.oa_id} target="_blank" style={{"fontSize": "0.73rem", "fontWeight": "600", "display": "inline-block", "marginTop": "0.3rem", "color": "#6366f1"}}>View on OpenAlex &#8594;</a>
                }}
                <details style={{"marginTop": "0.4rem"}}>
                    <summary style={{"fontSize": "0.73rem", "cursor": "pointer", "color": "#6b7280", "fontWeight": "500"}}>Full abstract</summary>
                    <p style={{"fontSize": "0.73rem", "color": "#374151", "fontWeight": "400", "marginTop": "0.3rem"}}>{detail.abstract}</p>
                </details>
            </div>
        </div>

        <div style={{
            "flex": "1", "display": "flex", "flexDirection": "column", "padding": "0.85rem", "minHeight": "0",
            "background": "rgba(255,255,255,0.5)", "border": "1px solid rgba(0,0,0,0.07)", "borderRadius": "12px"
        }}>
            <strong style={{"fontSize": "0.85rem", "flexShrink": "0", "color": "#111827", "fontWeight": "600", "letterSpacing": "-0.01em"}}>Ask about this connection</strong>
            <div style={{"flex": "1", "overflowY": "auto", "marginTop": "0.5rem", "display": "flex", "flexDirection": "column", "gap": "0.5rem", "minHeight": "0"}}>
                {if len(chatMessages) == 0 {
                    <p key="chat-empty" style={{"color": "#9ca3af", "fontWeight": "400", "fontSize": "0.8rem"}}>
                        Ask things like "why is this relevant?" or "how would we actually apply this?"
                    </p>
                }}
                {for (i, msg) in enumerate(chatMessages) {
                    <div
                        key={str(i)}
                        style={{
                            "alignSelf": "flex-end" if msg["role"] == "user" else "flex-start",
                            "backgroundColor": "#6366f1" if msg["role"] == "user" else "rgba(0,0,0,0.05)",
                            "color": "white" if msg["role"] == "user" else "#111827",
                            "fontWeight": "500",
                            "padding": "0.5rem 0.75rem", "borderRadius": "12px", "maxWidth": "90%", "fontSize": "0.82rem"
                        }}
                    >
                        {msg["content"] as str}
                    </div>
                }}
                {if chatLoading {
                    <div key="thinking" style={{"alignSelf": "flex-start", "color": "#6b7280", "fontWeight": "500", "fontSize": "0.82rem"}}>Thinking...</div>
                }}
            </div>

            <form onSubmit={handle_submit} style={{"display": "flex", "gap": "0.4rem", "marginTop": "0.5rem", "flexShrink": "0"}}>
                <input
                    type="text"
                    value={chatInput}
                    onChange={handle_input}
                    placeholder="Ask about this connection..."
                    style={{
                        "flex": "1", "padding": "0.55rem 0.7rem", "fontFamily": "inherit", "fontWeight": "500",
                        "background": "rgba(255,255,255,0.8)", "border": "1px solid rgba(0,0,0,0.08)", "borderRadius": "10px",
                        "fontSize": "0.82rem", "minWidth": "0", "outline": "none", "color": "#111827"
                    }}
                />
                <button
                    type="submit"
                    disabled={chatLoading or len(chatInput.strip()) == 0}
                    style={{
                        "padding": "0.55rem 1rem", "backgroundColor": "#c7c9d9" if (chatLoading or len(chatInput.strip()) == 0) else "#6366f1",
                        "color": "white", "border": "none", "borderRadius": "10px", "fontFamily": "inherit", "fontWeight": "600",
                        "cursor": "not-allowed" if (chatLoading or len(chatInput.strip()) == 0) else "pointer", "fontSize": "0.82rem"
                    }}
                >
                    Ask
                </button>
            </form>
        </div>
    </div>;
}
