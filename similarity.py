"""Crosswalk - lightweight, dependency-free text similarity for pre-filtering
OpenAlex candidates before spending any model call on them. Not a real
semantic embedding model - a simple term-frequency cosine similarity - but
it's pure math (zero network, zero LLM cost) and good enough to narrow a
pooled candidate list down to the few worth an actual Judge call.
"""

import re
import math
from collections import Counter

_TOKEN_RE = re.compile(r"[a-z0-9]+")


def _tokenize(text):
    return _TOKEN_RE.findall(text.lower())


def _tf_vector(text):
    return Counter(_tokenize(text))


def cosine_similarity(text_a, text_b):
    vec_a = _tf_vector(text_a)
    vec_b = _tf_vector(text_b)
    if not vec_a or not vec_b:
        return 0.0
    common = set(vec_a) & set(vec_b)
    dot = sum(vec_a[t] * vec_b[t] for t in common)
    norm_a = math.sqrt(sum(v * v for v in vec_a.values()))
    norm_b = math.sqrt(sum(v * v for v in vec_b.values()))
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)


def rank_by_similarity(candidates, query_text, top_n):
    """candidates: list of dicts with 'title' and 'abstract' keys."""
    scored = []
    for c in candidates:
        text = (c.get("title") or "") + " " + (c.get("abstract") or "")
        score = cosine_similarity(query_text, text)
        scored.append((score, c))
    scored.sort(key=lambda pair: pair[0], reverse=True)
    return [c for _, c in scored[:top_n]]
