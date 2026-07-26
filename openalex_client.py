"""Crosswalk - OpenAlex API client.

Plain Python: pure HTTP/JSON, no graph semantics - imported directly into .jac
via normal `import` (see jac-python-interop). Kept out of the graph layer so it
stays independently testable against fixture responses.
"""

import os
import time

import requests

BASE_URL = "https://api.openalex.org/works"
SELECT_FIELDS = "id,title,abstract_inverted_index,primary_topic,publication_year,cited_by_count"
MAILTO = "elanu.karakus@gmail.com"

# As of Feb 2026, OpenAlex meters `search=` calls ($1/1000 with a free API key,
# vs a tiny $0.10/day unauthenticated allowance that a shared dev environment
# can exhaust quickly). Singleton by-ID/DOI lookups stay free either way.
# Sign up free at openalex.org, grab a key from openalex.org/settings/api, and
# export OPENALEX_API_KEY - search_works sends it as the documented `api_key=`
# query param automatically when set.
#
# Read fresh on every call (not cached at import time): this module can be
# imported before a .env file finishes loading into the process environment,
# and a module-level constant would freeze in whatever was there at that
# moment - silently dropping the key for the process's whole lifetime.
def _api_key():
    return os.environ.get("OPENALEX_API_KEY", "")


def reconstruct_abstract(inverted_index):
    """OpenAlex never returns plain abstract text, only word -> [positions]."""
    if not inverted_index:
        return ""
    positions = []
    for word, idxs in inverted_index.items():
        for i in idxs:
            positions.append((i, word))
    positions.sort(key=lambda p: p[0])
    return " ".join(word for _, word in positions)


def extract_topic(work):
    """Pull the domain > field > subfield > topic hierarchy off a Work's primary_topic."""
    topic = work.get("primary_topic") or {}
    field = topic.get("field") or {}
    subfield = topic.get("subfield") or {}
    domain = topic.get("domain") or {}
    return {
        "topic_id": topic.get("id") or "",
        "topic_name": topic.get("display_name") or "",
        "field_id": field.get("id") or "",
        "field_name": field.get("display_name") or "",
        "subfield_id": subfield.get("id") or "",
        "subfield_name": subfield.get("display_name") or "",
        "domain_id": domain.get("id") or "",
        "domain_name": domain.get("display_name") or "",
    }


def _work_to_dict(work):
    return {
        "oa_id": work.get("id") or "",
        "title": work.get("title") or "",
        "abstract": reconstruct_abstract(work.get("abstract_inverted_index")),
        "year": work.get("publication_year") or 0,
        "citation_count": work.get("cited_by_count") or 0,
        **extract_topic(work),
    }


def search_works(query, mailto=MAILTO, per_page=8, max_retries=3):
    """Search OpenAlex works. Retries with backoff on network errors and 429s."""
    params = {
        "search": query,
        "per-page": per_page,
        "select": SELECT_FIELDS,
        "mailto": mailto,
    }
    api_key = _api_key()
    if api_key:
        params["api_key"] = api_key
    last_error = None
    for attempt in range(max_retries):
        try:
            resp = requests.get(BASE_URL, params=params, timeout=10)
        except requests.RequestException as exc:
            last_error = exc
            time.sleep(0.5 * (attempt + 1))
            continue
        if resp.status_code == 429:
            time.sleep(1.0 * (attempt + 1))
            continue
        resp.raise_for_status()
        data = resp.json()
        return [_work_to_dict(w) for w in data.get("results", [])]
    raise RuntimeError(f"OpenAlex search failed after {max_retries} attempts: {last_error}")


def resolve_home_field(product_text, mailto=MAILTO):
    """One search on the literal, unabstracted product text; top hit's topic anchors the product."""
    results = search_works(product_text, mailto=mailto, per_page=1)
    if not results:
        return None
    return results[0]
