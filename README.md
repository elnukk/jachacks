# Crosswalk — PRD
**Finding the research your R&D team didn't know to look for**
Built on Jac (Object-Spatial Programming: nodes, edges, walkers) + `by llm()`

---

## 1. One-line pitch

Give Crosswalk a real product. It decomposes it into components and functions, walks the global research graph (OpenAlex) to find work that serves those functions in *unrelated fields*, and shows you the exact hop path that got there — not a ranked list, a traversal you can trust.

## 2. Problem statement

R&D teams miss solutions that already exist because the solution lives in a field whose vocabulary they don't speak. Keyword and embedding search both require the user to name what they want. Crosswalk doesn't require naming — it abstracts a feature to its underlying function, then traverses to any field that serves that function.

This automates a known-good but manual methodology (TRIZ, biomimicry) at a scale no team can do by hand across a whole product.

## 3. Critical architecture constraint: the system must be general, not hardcoded

**Do not build this as a system that only works for 2-3 pre-selected products.** The pipeline — decomposition, abstraction, discovery, judging, verification — must work on *arbitrary* product input, because that's the actual claim being made: "this runs on whatever OpenAlex has," not "this is a demo of 3 fixtures."

What this means concretely:

- **No hardcoded product data, function graphs, or paper results anywhere in the core pipeline code.** Every `Component`, `Function`, and `ResearchWork` node must be produced by actually calling DecomposeWalker → AbstractWalker → DiscoveryWalker → JudgeWalker → VerifyWalker for whatever input is given at runtime — never a switch statement or lookup table keyed on "if product == 'camping stove'."
- **Caching is a reliability layer on top of a general system, not a replacement for one.** Build it as: run the real pipeline once for your chosen demo products ahead of time, save the *output* of that real run (the resulting graph + verified hits) as a fixture, and load the fixture instead of re-running the pipeline live during the actual judged demo — purely to avoid live-demo timing/flakiness risk. The underlying code path must be identical whether it's serving a cached fixture or running fresh; the only difference is whether you fetch from cache or call the walkers, not different logic.
- **Test this constraint directly:** before considering the build "done," run the full live pipeline (not cache) on at least one product nobody on the team pre-picked or tuned for, and confirm it produces a coherent (even if less polished) result. If it only works on your curated 2-3, that's a sign the pipeline has been implicitly tuned to those inputs rather than actually general, and needs fixing.
- **Practical implication for build order:** get the general pipeline working end-to-end on *some* arbitrary input first, then curate/cache your best demo products from real runs of that same pipeline — don't build product-specific logic first and generalize later, since that tends to bake in hardcoding you won't notice until a judge asks to try their own product.

## 4. Non-goals for the hackathon build (explicit cuts)

Cut without apology — these are correctly identified in the source doc as scope risks:
- **No live web scraping.** Accept pasted product name/spec text as input. Do not build a URL scraper.
- **No second live data source.** OpenAlex only for the live build. Grants/patents/startups are a roadmap slide, not working code.
- **No polished custom UI chrome.** The force-directed graph *is* the UI. Don't build dashboard scaffolding around it.
- **No live decomposition for the demo product.** Pre-run and cache the decomposition for whichever product(s) you demo with. Only the *discovery walk* runs live.
- **No recursive depth on every node.** Depth is configurable but only needs to go deep on the path(s) you'll show.

If time is short, cut in this order: grants/patents mention → force-directed rendering polish → surprise score → verify pass (keep the last two as long as possible — they're what makes the demo trustworthy, not decorative).

## 5. Core mechanism (the thing to protect above all else)

**Ranking is never relevance alone.** Score = `functional_relevance × field_distance`, with a `surprise` factor as a secondary signal. This is the single most important design decision in the project — it is the entire difference between Crosswalk and a semantic search box. Every architecture decision below should protect this, not bury it under generic infra work.

Three computable levers:
1. **Field distance** — from OpenAlex's concept/field hierarchy per work, measure distance between the product's home field and each candidate's field. Downrank/filter same-field hits.
2. **Abstraction height** — prefer the highest level of abstraction that still validates (shallow abstraction → same-field results; too high → loses validity). Track which abstraction level produced each hit.
3. **Surprise score** — `by llm()` judgment of non-obviousness, used as a secondary rank signal, not primary. Be ready to justify this isn't pure vibes: correlate it loosely with field distance + (if easy to check) low citation overlap between source/target fields.

## 6. Graph schema

```
node Product {
    has name: str, description: str, use_environment: str;
}

node Component {
    has name: str;  # e.g. "battery pack", "housing seal"
}

node Function {
    has name: str;              # e.g. "waterproofing"
    has abstraction_level: int; # 0 = concrete feature, higher = more general principle
    has domain_neutral_desc: str; # e.g. "energy absorption in brittle materials"
}

node ResearchWork {
    has title: str, abstract: str, oa_id: str, field: str,
       concepts: list[str], year: int, citation_count: int;
}

node Field {
    has name: str; # OpenAlex concept/field node, for distance computation
}

edge has_component;      # Product -> Component
edge requires_function;  # Component -> Function
edge abstracts_to;       # Function -> Function (concrete -> more general)
edge serves_function;    # ResearchWork -> Function (the traversal payoff edge)
edge belongs_to_field;   # ResearchWork -> Field, Function -> Field (home field)
edge field_distance;     # Field -> Field, weighted
```

## 7. Walkers

### 6.1 DecomposeWalker
- Input: product name/description text (+ optional pasted spec text).
- `by llm()` call #1 ("Decompose"): emit `Component` and `Function` nodes from stated specs + world knowledge of how that product class is typically built. Include inferred use-environment functions (e.g. "used in a truck bed in the desert" → adds UV resistance, thermal cycling, vibration).
- Output: structured `obj Decomposition { has components: list[Component], functions: list[Function] }` — typed, not free text.
- **This step is pre-run and cached for demo products.** Build it to run live for arbitrary input as a stretch goal only.

### 6.2 AbstractWalker
- Input: a concrete `Function` node.
- `by llm()` call #2 ("Abstract"): produce one or more `abstracts_to` edges to more general, domain-neutral versions of the function, each tagged with `abstraction_level`. E.g. "won't crack in cold" → "impact resistance at low temperature" → "energy absorption in brittle materials."
- Stop condition: abstraction should climb only as high as still validates — don't let this run unbounded. Cap at 2-3 hops up for the hackathon.

### 6.3 DiscoveryWalker (the core, must be live in the demo)
- Input: an abstracted `Function` node.
- Queries OpenAlex API (free, no auth needed for reasonable use) for works whose concepts/abstract match the function's `domain_neutral_desc`.
- For each candidate `ResearchWork`, creates `serves_function` edge candidates.
- Computes `field_distance` using OpenAlex's concept hierarchy between the work's field and the function's home field.
- Fans out in parallel across function nodes — this is your "no human monitors 40 subsystems, a walker does it at once" line; make sure the demo actually shows parallel fan-out, not a serial loop that looks sequential.

### 6.4 JudgeWalker
- `by llm()` call #3 ("Judge"): for each candidate `serves_function` edge, return structured output:
```
obj Judgment {
    has functional_relevance: float,
    has maturity: str,
    has transfer_difficulty: str,
    has surprise_flag: bool,       # "would a domain expert already know this?"
    has translation: str,          # one-line plain-language translation
}
```

### 6.5 VerifyWalker
- Second pass, separate `by llm()` call, **not the same prompt as Judge** — this needs to be a genuinely independent check or it's just the model agreeing with itself.
- Confirms the candidate paper's abstract actually supports the claimed function-serving relationship before it's surfaced.
- Design the rejection path explicitly: on reject, does the walker try the next-ranked candidate, or drop that hop entirely? **Decide this before building — recommended: try next candidate, cap at 2 retries, then drop the hop.**

## 8. Data source

- **OpenAlex API only** (`api.openalex.org`) for the hackathon build. Free, no key required for polite-pool usage. Provides title, abstract, concepts/field tags, and citation edges — sufficient for every step above. No paywall issue since nothing requires full-text.
- Grants/patents/startups: mentioned in the pitch as roadmap ("technology scouting extends here"), not built.

## 9. Demo script (two-beat + credibility move, per source doc — keep this structure)

1. **Breadth beat:** paste one real, deliberately mundane product (camping gear / kitchen appliance / furniture). Show it explode into a ~40-node component/function graph, DiscoveryWalker fanning out in parallel. Line: *"No human monitors the literature for all forty of these subsystems. A walker does it at once."*
2. **Credibility move (do this before the wow beat):** point Crosswalk at a problem with a *known* famous cross-domain solution (swimsuit drag → shark-skin denticles; high-speed-train noise → kingfisher beak; self-cleaning surface → lotus leaf) and show it independently rediscovers the known link. This proves the mechanism works before asking judges to trust a novel result.
3. **Wow beat:** spotlight the 2-3 genuinely far-field hits the distance-scoring surfaced on your demo product, each with its traversal path rendered — battery pack → thermal runaway risk → passive heat dissipation → data-center cooling → phase-change material research. Show side-by-side against what plain keyword search returns for the same product (obvious, same-field results) so the gap is the pitch.

## 10. Build order (checkpoint-friendly)

| Time | Milestone | Fallback if behind |
|---|---|---|
| Hr 0–2 | Graph schema stood up; DecomposeWalker producing a cached decomposition for 2-3 pre-selected demo products | Hand-write the decomposition JSON directly if `by llm()` decomposition is unreliable |
| Hr 2–4 | AbstractWalker producing 2-3 abstraction hops per function | Cap abstraction depth at 1 hop, still demoable |
| Hr 4–6 | DiscoveryWalker live against OpenAlex, field-distance scoring working | If distance scoring is buggy, ship relevance-only ranking and say scoring is "in progress" rather than show wrong results |
| Hr 6–8 | JudgeWalker + VerifyWalker producing translations, force-directed graph rendering the path | Cut VerifyWalker before cutting the graph rendering — the visual path is your demo's core asset |
| Remaining | **Curate your 2-3 demo products and the known-transfer validation case.** Run the full pipeline against each repeatedly until it reliably produces a good result. This is not optional polish — it's the actual product risk. | — |

## 11. Known risks (carried from source doc, do not lose these)

- **Abstraction quality is the make-or-break step.** Sloppy function-mapping → random-paper generator. Mitigate with tight structured outputs + the Verify pass.
- **Ranking by relevance alone kills the whole pitch** — field-distance scoring must be core to the ranking function from the start, not bolted on later.
- **Demo reliability depends entirely on curation you haven't done yet.** Lock in demo products early (first 2 hours if possible) and test repeatedly — don't write more walker code than needed before you know your demo examples actually produce a good result.

## 12. Track / positioning notes for the pitch itself

- Position against existing cross-domain analogical search tools (e.g., patent-search tools already do embedding + LLM abstraction) honestly: differentiate on (a) starting from a *whole product's* structured decomposition rather than a single typed query, and (b) showing the traversal path as an inspectable, multi-hop walk rather than a ranked black-box list.
- Lead the "who pays" argument with: technology scouting is an existing paid service done manually and slowly at R&D-driven companies — Crosswalk automates it across a whole product's function graph at once.

---

**Working name:** Crosswalk. Hand this doc to Claude Code as the implementation brief — Section 6 (schema) and Section 7 (walkers) are the core to implement first; Section 10 is the suggested sequencing.