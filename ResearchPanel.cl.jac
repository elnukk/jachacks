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
        return <div style={{"padding": "1rem", "color": "#666", "fontSize": "0.9rem"}}>Loading research path...</div>;
    }

    if steps is None or detail is None {
        return <div style={{"padding": "1rem", "color": "#666", "fontSize": "0.9rem"}}>
            Click a research paper node (orange) in the graph to see its hop
            path, read what it says, and ask questions about the connection.
            Selecting a Function node (pink highlight) for Send Deep is a
            different action - it doesn't show anything here until a paper
            actually gets discovered and verified.
        </div>;
    }

    return <div style={{"display": "flex", "flexDirection": "column", "height": "100%", "padding": "0.75rem", "boxSizing": "border-box", "gap": "0.75rem"}}>
        <div style={{"flexShrink": "0", "maxHeight": "42%", "overflowY": "auto", "border": "1px solid #e5e7eb", "borderRadius": "8px", "padding": "0.75rem"}}>
            <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center"}}>
                <strong style={{"fontSize": "0.9rem"}}>Research path</strong>
                {if onClose {
                    <button onClick={lambda (_e: MouseEvent) { onClose(); }} style={{"border": "none", "background": "none", "cursor": "pointer", "color": "#666", "fontSize": "0.8rem"}}>close</button>
                }}
            </div>

            <div style={{"marginTop": "0.5rem"}}>
                {for (i, step) in enumerate(steps) {
                    <div key={str(i)} style={{"display": "flex", "gap": "0.35rem", "fontSize": "0.78rem", "marginBottom": "0.15rem", "paddingLeft": f"{i * 0.6}rem"}}>
                        <span style={{"color": "#9ca3af"}}>{step.kind}:</span>
                        <span>{step.label}</span>
                    </div>
                }}
            </div>

            <div style={{"marginTop": "0.6rem", "padding": "0.6rem", "backgroundColor": "#fffbeb", "border": "1px solid #fde68a", "borderRadius": "6px"}}>
                <div style={{"fontWeight": "bold", "fontSize": "0.85rem"}}>{detail.title}</div>
                <div style={{"fontSize": "0.7rem", "color": "#92400e", "marginTop": "0.15rem"}}>
                    {detail.field_name} ({detail.year}) - {detail.citation_count} citations
                </div>
                <p style={{"fontSize": "0.78rem", "marginTop": "0.4rem", "marginBottom": "0.3rem"}}>{detail.translation}</p>
                <div style={{"fontSize": "0.7rem", "color": "#666"}}>
                    relevance {f"{detail.functional_relevance:.2f}"} - field distance {detail.field_distance} - {detail.maturity} - transfer: {detail.transfer_difficulty}
                </div>
                {if len(detail.oa_id) > 0 {
                    <a key="oa-link" href={detail.oa_id} target="_blank" style={{"fontSize": "0.73rem", "display": "inline-block", "marginTop": "0.3rem", "color": "#2563eb"}}>View on OpenAlex &#8594;</a>
                }}
                <details style={{"marginTop": "0.4rem"}}>
                    <summary style={{"fontSize": "0.73rem", "cursor": "pointer", "color": "#666"}}>Full abstract</summary>
                    <p style={{"fontSize": "0.73rem", "color": "#444", "marginTop": "0.3rem"}}>{detail.abstract}</p>
                </details>
            </div>
        </div>

        <div style={{"flex": "1", "display": "flex", "flexDirection": "column", "border": "1px solid #e5e7eb", "borderRadius": "8px", "padding": "0.75rem", "minHeight": "0"}}>
            <strong style={{"fontSize": "0.85rem", "flexShrink": "0"}}>Ask about this connection</strong>
            <div style={{"flex": "1", "overflowY": "auto", "marginTop": "0.5rem", "display": "flex", "flexDirection": "column", "gap": "0.5rem", "minHeight": "0"}}>
                {if len(chatMessages) == 0 {
                    <p key="chat-empty" style={{"color": "#999", "fontSize": "0.8rem"}}>
                        Ask things like "why is this relevant?" or "how would we actually apply this?"
                    </p>
                }}
                {for (i, msg) in enumerate(chatMessages) {
                    <div
                        key={str(i)}
                        style={{
                            "alignSelf": "flex-end" if msg["role"] == "user" else "flex-start",
                            "backgroundColor": "#2563eb" if msg["role"] == "user" else "#f3f4f6",
                            "color": "white" if msg["role"] == "user" else "black",
                            "padding": "0.5rem 0.75rem", "borderRadius": "10px", "maxWidth": "90%", "fontSize": "0.82rem"
                        }}
                    >
                        {msg["content"] as str}
                    </div>
                }}
                {if chatLoading {
                    <div key="thinking" style={{"alignSelf": "flex-start", "color": "#666", "fontSize": "0.82rem"}}>Thinking...</div>
                }}
            </div>

            <form onSubmit={handle_submit} style={{"display": "flex", "gap": "0.4rem", "marginTop": "0.5rem", "flexShrink": "0"}}>
                <input
                    type="text"
                    value={chatInput}
                    onChange={handle_input}
                    placeholder="Ask about this connection..."
                    style={{"flex": "1", "padding": "0.5rem", "border": "1px solid #ddd", "borderRadius": "6px", "fontSize": "0.82rem", "minWidth": "0"}}
                />
                <button
                    type="submit"
                    disabled={chatLoading or len(chatInput.strip()) == 0}
                    style={{"padding": "0.5rem 0.9rem", "backgroundColor": "#2563eb", "color": "white", "border": "none", "borderRadius": "6px", "cursor": "pointer", "fontSize": "0.82rem"}}
                >
                    Ask
                </button>
            </form>
        </div>
    </div>;
}
