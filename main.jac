"""Crosswalk - Entry Point.

Combines server-side endpoints with the client-side UI. Every endpoint the
client calls must be named here (see jac-fullstack-patterns: registration
tracks the exact name in this import list, not just module presence) - grows
as each phase's endpoints land.
"""

import from schema { Product, Component, Function, ResearchWork }
import from decompose { decompose_product }
import from views { get_graph_view, get_hop_path, GraphView, GraphNode, GraphEdge, HopStep, WorkDetail, HopPathResult }
import from pipeline { explore_functions }
import from baseline { get_keyword_baseline, BaselineHit }
import from chat { ask_about_research }

# Client-side UI
cl {
    import from .frontend { app as ClientApp }

    def:pub app -> JsxElement {
        return <ClientApp/>;
    }
}
