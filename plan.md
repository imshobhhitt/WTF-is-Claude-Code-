# Plan: Add `7-vectorlessrag.ipynb` — Vectorless RAG with PageIndex

## Context

The bootcamp's `updatedlangchain/` curriculum currently ends at notebook 6 (middleware). RAG is the next natural topic, and we introduce it via the **vectorless** approach — using the **PageIndex** library (VectifyAI) — before (or instead of) the standard chunk-and-embed pattern. This is pedagogically interesting because:

- It contrasts directly with the embedding-based RAG students have likely seen elsewhere.
- It composes cleanly with the agent material from notebooks 1–6: PageIndex retrieval becomes a `@tool` that a `create_agent` can call, reinforcing the agent-as-orchestrator mental model the bootcamp builds.
- PageIndex exposes a small, readable async API (`submit_document` → poll `is_retrieval_ready` → `get_tree`, then `submit_query` → poll `get_retrieval`) that fits a single ~15 cell teaching notebook.

**Outcome:** a new notebook `updatedlangchain/7-vectorlessrag.ipynb` that a student can run top-to-bottom — auto-downloading a small public PDF — and walks them from "what is vectorless RAG" through "an agent answers questions over a PDF without any vector DB."

## File to create

- **Path:** `E:\agenticAI\langchainupdated\updatedlangchain\7-vectorlessrag.ipynb`
- **Format:** Jupyter notebook, follows the cadence of notebooks 1–6 (markdown explanation cell → code cell → output, boilerplate repeated per cell so students can run any cell standalone).

## Dependency changes

Add to `pyproject.toml` `[project] dependencies` (and mirror in `requirements.txt`):
- `pageindex>=0.2.8` — the library being taught
- `requests>=2.32` — used in the notebook to download the sample PDF (likely already pulled transitively, but make it explicit)

After the edit: run `uv sync` to refresh `uv.lock`.

## PageIndex API (verified against installed v0.2.8)

PageIndex is a **hosted SaaS** at `https://api.pageindex.ai`, not a local library. The notebook needs `PAGEINDEX_API_KEY` in `.env` in addition to `OPENAI_API_KEY`.

Real method surface (introspected via `dir(PageIndexClient)`):

- Constructor: `PageIndexClient(api_key: str)`
- `submit_document(file_path)` → `{"doc_id": ...}` (async — returns immediately)
- `is_retrieval_ready(doc_id)` → `bool` (poll until True)
- `get_tree(doc_id, node_summary=True)` → hierarchical JSON tree
- `submit_query(doc_id, query)` → `{"retrieval_id": ...}` (async)
- `get_retrieval(retrieval_id)` → `{"status": "completed" | "failed", ...}` (poll)
- Also available: `chat_completions`, `list_documents`, `get_document`, `get_ocr`, `create_folder`, `delete_document`

> **Note:** an earlier draft of this plan listed `client.index()` / `get_document_structure` / `get_page_content` based on outdated examples. Those methods do not exist in v0.2.8. The notebook uses the verified surface above.

## Notebook structure (cell-by-cell, as implemented)

The actual notebook is 19 cells (10 markdown + 9 code). Headings below correspond to the section markers in the file.

### Section 1 — Intro (markdown)
3–4 sentences framing standard RAG vs vectorless RAG, why the hierarchical-tree approach matters (no chunk fragmentation, interpretable retrieval), and what we'll build. Cite https://pageindex.ai/blog/pageindex-intro.

### Section 2 — Setup (markdown + code)
Env loading. Both `PAGEINDEX_API_KEY` and `OPENAI_API_KEY` required. Asserts both are present.

```python
import os
from dotenv import load_dotenv
load_dotenv()
os.environ["OPENAI_API_KEY"] = os.getenv("OPENAI_API_KEY")
os.environ["PAGEINDEX_API_KEY"] = os.getenv("PAGEINDEX_API_KEY")
assert os.environ["PAGEINDEX_API_KEY"], "Set PAGEINDEX_API_KEY in your .env"
assert os.environ["OPENAI_API_KEY"], "Set OPENAI_API_KEY in your .env"
```

### Section 3 — Grab a sample PDF (markdown + code)
Auto-download the *Attention Is All You Need* paper (`https://arxiv.org/pdf/1706.03762.pdf`) into `sample.pdf`. Cached on re-run.

### Section 4 — Submit the document (markdown + code)
`client.submit_document(file_path=PDF_PATH)` returns `{"doc_id": ...}` immediately; indexing happens server-side.

### Section 5 — Wait for indexing (markdown + code)
Poll `client.is_retrieval_ready(doc_id)` with a 3-minute deadline.

### Section 6 — Inspect the tree (markdown + code)
`client.get_tree(doc_id, node_summary=True)` — print first 2500 chars of the JSON tree so students can see the section titles, page numbers, and node summaries the LLM will navigate.

### Section 7 — Direct retrieval (markdown + code)
Helper function `run_query(query, timeout=60)` that wraps the async submit-and-poll cycle:

```python
def run_query(query: str, timeout: int = 60) -> dict:
    submission = client.submit_query(doc_id=doc_id, query=query)
    retrieval_id = submission["retrieval_id"]
    deadline = time.time() + timeout
    while time.time() < deadline:
        result = client.get_retrieval(retrieval_id)
        if result.get("status") in ("completed", "failed"):
            return result
        time.sleep(2)
    raise TimeoutError(f"Retrieval {retrieval_id} did not finish")
```

Demo: `run_query("What is multi-head attention?")`.

### Section 8 — Wrap as LangChain tools (markdown + code)
Two `@tool`s plus `create_agent`. Both tool outputs are truncated to 6000 chars to keep the agent's context manageable.

```python
from langchain_core.tools import tool
from langchain.agents import create_agent
from langchain_core.messages import HumanMessage

@tool
def get_outline() -> str:
    """Return the hierarchical outline (table of contents) of the indexed PDF as JSON."""
    return json.dumps(client.get_tree(doc_id, node_summary=True))[:6000]

@tool
def search_doc(query: str) -> str:
    """Search the indexed PDF for content relevant to a natural-language query. Returns matching nodes with their text."""
    return json.dumps(run_query(query))[:6000]

agent = create_agent(
    model="gpt-4o-mini",
    tools=[get_outline, search_doc],
    system_prompt=(
        "You answer questions about an indexed research paper. "
        "First call get_outline to see the section structure, "
        "then call search_doc with a focused query, "
        "then answer concisely with citations to section names."
    ),
)
```

Model choice: `gpt-4o-mini` — matches `test_summarization_middleware.py` and notebook 6, keeps cost low.

### Section 9 — Ask a real question (markdown + code)
```python
result = agent.invoke({
    "messages": [HumanMessage(content="What is multi-head attention and why was it introduced?")]
})
print(result["messages"][-1].content)
```

Plus a trace cell that walks `result["messages"]` and prints each tool call — that's the interpretability payoff over embedding RAG.

### Section 10 — Recap (markdown)
- **Vectorless wins**: long structured docs, interpretability matters, hierarchy is meaningful (filings, contracts, papers, manuals).
- **Vector RAG wins**: many small documents, fuzzy semantic match, sub-second latency.
- PageIndex also has an [MCP server](https://github.com/VectifyAI/pageindex-mcp) — students can plug the same indexed document into Claude Code post-bootcamp.

## Reference patterns reused from the repo

- **Env-loading boilerplate per cell**: matches `updatedlangchain/2-modelintegration.ipynb` and `updatedlangchain/6-middleware.ipynb`. Repeated intentionally so cells run standalone (per `CLAUDE.md`).
- **`@tool` + `create_agent` wiring**: same pattern as `updatedlangchain/3-tools.ipynb` and `updatedlangchain/1-langchainintro.ipynb`.
- **Model name**: `gpt-4o-mini` — consistent with `test_summarization_middleware.py` and notebook 6.

## CLAUDE.md update

Added notebook 7 to the curriculum list:

> 7. `7-vectorlessrag.ipynb` — Vectorless RAG via the **PageIndex** library (hosted SaaS at `api.pageindex.ai`): submit a PDF, poll `is_retrieval_ready`, inspect the JSON tree from `get_tree`, retrieve via `submit_query` + `get_retrieval` polling, then expose `get_outline` and `search_doc` as `@tool`s for a `create_agent` to navigate. Requires `PAGEINDEX_API_KEY` in `.env` in addition to `OPENAI_API_KEY`.

## Verification (how to test end-to-end)

1. **Dependency install**: `uv sync` — confirm `pageindex` resolves into `.venv`.
2. **API smoke test** (already done during implementation): `uv run python -c "from pageindex import PageIndexClient; print(dir(PageIndexClient))"` to confirm method names.
3. **Run the notebook top-to-bottom**: `uv run jupyter lab updatedlangchain/7-vectorlessrag.ipynb`, then *Restart Kernel and Run All Cells*. Acceptance:
   - Sample PDF downloads (or is skipped if cached).
   - `submit_document` returns a non-empty `doc_id`.
   - `is_retrieval_ready` flips to True within ~30s for this 15-page paper.
   - `get_tree` prints visibly hierarchical JSON (section titles + page numbers + summaries).
   - The final agent invocation returns a coherent answer about multi-head attention with at least one `get_outline` and one `search_doc` tool call visible in the trace.
4. **Cost check**: only `gpt-4o-mini` is used — students will run this many times.

## Out of scope (deliberately)

- Side-by-side comparison with FAISS/Chroma vector RAG (focused scope).
- Multi-document RAG (PageIndex is weaker here per the docs).
- Custom prompt engineering for tree navigation — let PageIndex's defaults drive the demo.

## Open risk

PageIndex is at v0.2.8 and still actively evolving. The verified API surface above is correct as of implementation, but minor drift is possible. If a future cell starts erroring, re-run `dir(PageIndexClient)` against the installed version and update method calls before assuming a deeper problem.
