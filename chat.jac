"""Crosswalk - conversational Q&A scoped to one hop path / research connection.

Client owns the conversation history (a plain list[dict], round-tripped each
call) rather than using by llm()'s conversation= kwarg, which binds to a
single module-level glob at declaration time - not suited to per-path,
per-user history.
"""

import from schema { ResearchWork }
import from views { build_hop_path }
import from models { shared_llm }

def answer_question(prompt_text: str) -> str by shared_llm();
sem answer_question = "Answer the user's question about this specific cross-domain research connection. Be concise, specific, and grounded only in the given context - if the context doesn't support an answer, say so rather than speculating.";
sem answer_question.prompt_text = "The traversal path, the research paper's details, prior conversation turns, and the user's latest question, all as plain text.";

def format_history(history: list[dict]) -> str {
    lines: list[str] = [];
    for turn in history {
        role = turn["role"] as str;
        content = turn["content"] as str;
        lines.append(f"{role}: {content}");
    }
    return "\n".join(lines);
}

def:pub ask_about_research(work_id: str, question: str, history: list[dict]) -> str {
    try {
        work = jobj(work_id);
    } except Exception {
        return "I couldn't find that research paper anymore - try clicking it again.";
    }
    if not isinstance(work, ResearchWork) {
        return "That doesn't look like a research paper node.";
    }

    result = build_hop_path(work);
    if result is None {
        return "I couldn't trace this paper's connection back to the product.";
    }
    detail = result.detail;
    if detail is None {
        return "I couldn't find this paper's details.";
    }
    steps = result.steps;

    path_str = " -> ".join([f"{s.kind}: {s.label}" for s in steps]);
    context_lines = [
        f"Traversal path: {path_str}",
        "",
        f"Research paper: {detail.title} ({detail.year})",
        f"Field: {detail.domain_name} / {detail.field_name}",
        f"Abstract: {detail.abstract}",
        f"Why it was judged relevant to the product: {detail.translation}",
        f"Functional relevance: {detail.functional_relevance}, field distance: {detail.field_distance}, maturity: {detail.maturity}, transfer difficulty: {detail.transfer_difficulty}",
    ];
    context = "\n".join(context_lines);

    prompt = context + "\n\nConversation so far:\n" + format_history(history) + f"\n\nUser question: {question}";

    try {
        return answer_question(prompt);
    } except Exception {
        return "Sorry, I couldn't answer that - try rephrasing.";
    }
}
