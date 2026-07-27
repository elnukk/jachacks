"""Crosswalk - Force-directed graph canvas (wraps react-force-graph-2d).

Explicitly measures its container and passes width/height to ForceGraph2D -
without this the canvas sizes itself independently of the parent box and
visually spills outside it. Scroll/pinch zoom is disabled in favor of
explicit +/- /reset buttons (zoom via the fgRef imperative API).

Nodes are plain circles (native ForceGraph2D rendering, no custom canvas
draw) - always-visible on-canvas labels (as text below the dot, or as
auto-sized card text) were tried and made the graph crowded/illegible with
more than a handful of nodes. Labels only appear on hover (nodeLabel), which
keeps the canvas itself readable regardless of graph size.

Function nodes are click-to-select (highlighted) for "Send Deep"; ResearchWork
nodes are click-to-inspect (bubbles up to show the research panel).
"""

import from react { useEffect, useMemo }
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

    useEffect(lambda {
        if fgRef.current {
            fgRef.current.d3Force("charge").strength(-140).distanceMax(500);
            fgRef.current.d3Force("link").distance(65);
        }
    }, []);

    # Memoized so unrelated re-renders (e.g. typing in the chat box, which
    # re-renders the whole page) don't hand ForceGraph2D a brand-new
    # graphData object every keystroke - a new object reference makes it
    # reheat the force simulation, visibly jostling every node even though
    # nothing about the graph actually changed.
    graph_data = useMemo(lambda {
        return {
            "nodes": [
                {
                    "id": n.id,
                    "name": n.label,
                    "val": (n.val * 1.6) if n.id in selectedIds else n.val,
                    "kind": n.kind,
                    "color": node_color(n.kind, n.id in selectedIds)
                }
                for n in nodes
            ],
            "links": [{"source": e.source, "target": e.target} for e in edges]
        };
    }, [nodes, edges, selectedIds]);

    def format_tooltip(gnode: any) -> str {
        color = gnode["color"] as str;
        name = gnode["name"] as str;
        return f"<div style='display:flex;align-items:center;gap:0.45rem;'><span style='display:inline-block;width:8px;height:8px;border-radius:50%;background:{color};flex-shrink:0;'></span><span>{name}</span></div>";
    }

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

    def handle_engine_stop() {
        if fgRef.current {
            fgRef.current.zoomToFit(400, 60);
        }
    }

    zoom_btn_style: dict = {
        "width": "2rem", "height": "2rem", "border": "1px solid rgba(255,255,255,0.9)", "borderRadius": "10px",
        "backgroundColor": "rgba(255,255,255,0.8)", "backdropFilter": "blur(12px)", "cursor": "pointer",
        "fontFamily": "'Figtree', sans-serif", "fontSize": "1rem", "fontWeight": "600", "color": "#111827",
        "boxShadow": "0 2px 8px rgba(0,0,0,0.08)"
    };

    return <div ref={containerRef} style={{"width": "100%", "height": "100%", "position": "relative", "overflow": "hidden"}}>
        <ForceGraph2D
            ref={fgRef}
            width={dims["width"]}
            height={dims["height"]}
            graphData={graph_data}
            backgroundColor="rgba(0,0,0,0)"
            nodeColor="color"
            nodeVal="val"
            nodeRelSize={5}
            nodeLabel={format_tooltip}
            linkColor={lambda { return "rgba(99,102,241,0.25)"; }}
            onNodeClick={handle_click}
            onEngineStop={handle_engine_stop}
            enableZoomInteraction={False}
        />
        <div style={{"position": "absolute", "top": "0.5rem", "right": "0.5rem", "display": "flex", "flexDirection": "column", "gap": "0.35rem"}}>
            <button onClick={handle_zoom_in} style={zoom_btn_style} title="Zoom in">+</button>
            <button onClick={handle_zoom_out} style={zoom_btn_style} title="Zoom out">-</button>
            <button onClick={handle_zoom_reset} style={zoom_btn_style} title="Fit to view">{"⟲"}</button>
        </div>
        <div style={{
            "position": "absolute", "bottom": "0.5rem", "left": "0.5rem",
            "display": "flex", "gap": "0.75rem", "flexWrap": "wrap", "maxWidth": "90%",
            "backgroundColor": "rgba(255,255,255,0.8)", "backdropFilter": "blur(12px)", "padding": "0.4rem 0.65rem",
            "borderRadius": "10px", "fontSize": "0.72rem", "fontFamily": "'Figtree', sans-serif", "fontWeight": "500",
            "color": "#111827", "border": "1px solid rgba(255,255,255,0.9)", "boxShadow": "0 2px 8px rgba(0,0,0,0.06)"
        }}>
            <span><span style={{"color": "#2563eb"}}>&#9679;</span> Product</span>
            <span><span style={{"color": "#7c3aed"}}>&#9679;</span> Component</span>
            <span><span style={{"color": "#059669"}}>&#9679;</span> Function</span>
            <span><span style={{"color": "#db2777"}}>&#9679;</span> Selected</span>
            <span><span style={{"color": "#d97706"}}>&#9679;</span> Research found</span>
        </div>
    </div>;
}
