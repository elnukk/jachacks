"""Crosswalk - Client Shell impls. `has` state is bare here (no self.)."""

impl app.handle_decompose -> None {
    if len(product_text.strip()) == 0 {
        return;
    }
    loading = True;
    error = "";
    graph = None;
    hop_path_steps = None;
    hop_path_detail = None;
    selected_work_id = None;
    chat_messages = [];
    selected_function_ids = [];

    p = await decompose_product(product_text, use_environment);
    product = p;

    if p.status == "failed" {
        error = "Decomposition failed - try rephrasing or simplifying the product description.";
        loading = False;
        return;
    }

    g = await get_graph_view(jid(p));
    graph = g;
    loading = False;
}

impl app.handle_node_click(node_id: str, kind: str) -> None {
    if kind == "Function" {
        if node_id in selected_function_ids {
            selected_function_ids = [i for i in selected_function_ids if i != node_id];
        } else {
            selected_function_ids = selected_function_ids + [node_id];
        }
        return;
    }
    if kind == "ResearchWork" {
        hop_path_loading = True;
        hop_path_steps = None;
        hop_path_detail = None;
        selected_work_id = node_id;
        chat_messages = [];
        chat_input = "";

        result = await get_hop_path(node_id);
        if result is not None {
            hop_path_steps = result.steps;
            hop_path_detail = result.detail;
        }
        hop_path_loading = False;
    }
}

impl app.handle_close_hop_path -> None {
    hop_path_steps = None;
    hop_path_detail = None;
    selected_work_id = None;
    chat_messages = [];
}

impl app.handle_chat_input_change(value: str) -> None {
    chat_input = value;
}

impl app.handle_ask -> None {
    if selected_work_id is None {
        return;
    }
    question = chat_input.strip();
    if len(question) == 0 {
        return;
    }

    history_before = chat_messages;
    chat_messages = chat_messages + [{"role": "user", "content": question}];
    chat_input = "";
    chat_loading = True;

    try {
        answer = await ask_about_research(selected_work_id, question, history_before);
        chat_messages = chat_messages + [{"role": "assistant", "content": answer}];
    } except Exception {
        chat_messages = chat_messages + [{"role": "assistant", "content": "Sorry, something went wrong answering that."}];
    }

    chat_loading = False;
}

impl app.handle_prefill(example: dict) -> None {
    product_text = example["text"] as str;
    use_environment = example["use_environment"] as str;
}

impl app.handle_show_baseline -> None {
    if len(selected_function_ids) == 0 {
        return;
    }
    baseline_loading = True;
    baseline_hits = None;
    hits = await get_keyword_baseline(selected_function_ids[0]);
    baseline_hits = hits;
    baseline_loading = False;
}

impl app.handle_send_deep -> None {
    if len(selected_function_ids) == 0 {
        return;
    }
    exploring = True;
    progress_log = [];
    send_deep_error = "";
    ids_to_explore = selected_function_ids;

    try {
        processed = await explore_functions(ids_to_explore);
        progress_log = processed;
        selected_function_ids = [];
    } except Exception as e {
        send_deep_error = "Send Deep failed: " + str(e);
        exploring = False;
        return;
    }

    exploring = False;

    if product is not None {
        g = await get_graph_view(jid(product));
        graph = g;
    }
}
