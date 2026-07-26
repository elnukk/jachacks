"""Crosswalk - Force-directed graph canvas (wraps react-force-graph-2d).

Explicitly measures its container and passes width/height to ForceGraph2D -
without this the canvas sizes itself independently of the parent box and
visually spills outside it. Scroll/pinch zoom is disabled in favor of
explicit +/- /reset buttons (zoom via the fgRef imperative API).

Function nodes are click-to-select (highlighted) for "Send Deep"; ResearchWork
nodes are click-to-inspect (bubbles up to show the research panel).
"""

import from react { useEffect }
import from "react-force-graph-2d" { default as ForceGraph2D }
sv import from .views { GraphNode, GraphEdge }

def node_color(kind: str, selected: bool) -> str {
    # Selection uses a color no kind ever uses (pink) - it must never be
    # confusable with ResearchWork's orange, or a "selected for Send Deep"
    # function looks like "research was found" (a real, reported confusion).
    if selected {
        return "#db2777";
    }
    if kind == "Product" { return "#2563eb"; }
    if kind == "Component" { return "#7c3aed"; }
    if kind == "Function" { return "#059669"; }
    if kind == "ResearchWork" { return "#d97706"; }
    return "#6b7280";
}

def:pub ForceGraph(
    nodes: list[GraphNode],
    edges: list[GraphEdge],
    selectedIds: list[str] = [],
    onNodeClick: Callable[[str, str], None] | None = None
) -> JsxElement {
    has containerRef: Ref[any] = Ref();
    has fgRef: Ref[any] = Ref();
    has dims: dict = {"width": 600, "height": 500};

    useEffect(lambda {
        def measure() {
            if containerRef.current {
                dims = {"width": containerRef.current.clientWidth, "height": containerRef.current.clientHeight};
            }
        }
        measure();
        window.addEventListener("resize", measure);
        return lambda { window.removeEventListener("resize", measure); };
    }, []);

    graph_nodes = [
        {
            "id": n.id,
            "name": ("[selected] " + n.label) if n.id in selectedIds else n.label,
            "val": (n.val * 1.6) if n.id in selectedIds else n.val,
            "kind": n.kind,
            "color": node_color(n.kind, n.id in selectedIds)
        }
        for n in nodes
    ];
    graph_links = [{"source": e.source, "target": e.target} for e in edges];

    def handle_click(clicked: any) {
        if onNodeClick {
            onNodeClick(clicked["id"] as str, clicked["kind"] as str);
        }
    }

    def handle_zoom_in(e: MouseEvent) {
        if fgRef.current {
            fgRef.current.zoom(fgRef.current.zoom() * 1.35, 200);
        }
    }

    def handle_zoom_out(e: MouseEvent) {
        if fgRef.current {
            fgRef.current.zoom(fgRef.current.zoom() / 1.35, 200);
        }
    }

    def handle_zoom_reset(e: MouseEvent) {
        if fgRef.current {
            fgRef.current.zoomToFit(400, 40);
        }
    }

    zoom_btn_style: dict = {
        "width": "2rem", "height": "2rem", "border": "1px solid #d1d5db", "borderRadius": "6px",
        "backgroundColor": "white", "cursor": "pointer", "fontSize": "1rem", "fontWeight": "bold",
        "boxShadow": "0 1px 3px rgba(0,0,0,0.15)"
    };

    return <div ref={containerRef} style={{"width": "100%", "height": "100%", "position": "relative", "overflow": "hidden"}}>
        <ForceGraph2D
            ref={fgRef}
            width={dims["width"]}
            height={dims["height"]}
            graphData={{"nodes": graph_nodes, "links": graph_links}}
            nodeLabel="name"
            onNodeClick={handle_click}
            enableZoomInteraction={False}
        />
        <div style={{"position": "absolute", "top": "0.5rem", "right": "0.5rem", "display": "flex", "flexDirection": "column", "gap": "0.3rem"}}>
            <button onClick={handle_zoom_in} style={zoom_btn_style} title="Zoom in">+</button>
            <button onClick={handle_zoom_out} style={zoom_btn_style} title="Zoom out">-</button>
            <button onClick={handle_zoom_reset} style={zoom_btn_style} title="Fit to view">{"⟲"}</button>
        </div>
        <div style={{
            "position": "absolute", "bottom": "0.5rem", "left": "0.5rem",
            "display": "flex", "gap": "0.75rem", "flexWrap": "wrap", "maxWidth": "90%",
            "backgroundColor": "rgba(255,255,255,0.9)", "padding": "0.35rem 0.6rem",
            "borderRadius": "6px", "fontSize": "0.72rem", "border": "1px solid #e5e7eb"
        }}>
            <span><span style={{"color": "#2563eb"}}>&#9679;</span> Product</span>
            <span><span style={{"color": "#7c3aed"}}>&#9679;</span> Component</span>
            <span><span style={{"color": "#059669"}}>&#9679;</span> Function</span>
            <span><span style={{"color": "#db2777"}}>&#9679;</span> Selected</span>
            <span><span style={{"color": "#d97706"}}>&#9679;</span> Research found</span>
        </div>
    </div>;
}
