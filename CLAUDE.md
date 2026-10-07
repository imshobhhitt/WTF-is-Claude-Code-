# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project purpose

Bootcamp teaching material for **LangChain 1.x** (Agentic AI Ultimate RAG Bootcamp by Krish Naik). The notebooks in `updatedlangchain/` are designed to be worked through sequentially by students learning the v1 agent API. Code clarity and pedagogical progression matter more here than production hardening — keep examples minimal, explicit, and aligned with the v1 idioms.

## Environment

- Python **>=3.13** required (set in `pyproject.toml`).
- Dependencies are managed with **uv** (`uv.lock` is the source of truth). `requirements.txt` exists for pip users but `pyproject.toml` is canonical.
- Secrets live in `.env` at the repo root. Notebooks expect `OPENAI_API_KEY`, `GOOGLE_API_KEY`, and `GROQ_API_KEY` and load them with `python-dotenv`.

### Common commands

```bash
# Install / sync dependencies
uv sync

# Run the standalone middleware test script (NOT pytest — it's a plain script with print-based assertions)
uv run python test_summarization_middleware.py

# Launch the Jupyter kernel for the notebooks
uv run jupyter lab   # or: uv run jupyter notebook
```

There is no test runner, linter, or build step configured. Don't add one unless asked.

## Architecture

### Notebook curriculum (`updatedlangchain/`)

The numbered notebooks are a teaching sequence — each builds on the previous one. Preserve this order when editing or adding examples:

1. `1-langchainintro.ipynb` — `create_agent` basics, simple tool functions
2. `2-modelintegration.ipynb` — `init_chat_model` + provider-specific classes (`ChatOpenAI`, `ChatGoogleGenerativeAI`, `ChatGroq`); also covers `.stream()` and `.batch()`
3. `3-tools.ipynb` — `@tool` decorator, `bind_tools`, manual tool execution loop
4. `4-messages.ipynb` — message types
5. `5-structuredoutput.ipynb` — `with_structured_output` using Pydantic / TypedDict / dataclass; also shows `create_agent(response_format=...)` returning `result["structured_response"]`
6. `6-middleware.ipynb` — `SummarizationMiddleware` (message / token / fraction triggers) and `HumanInTheLoopMiddleware` (approve / edit / reject flows using `langgraph.types.Command` to resume after `__interrupt__`)
7. `7-vectorlessrag.ipynb` — Vectorless RAG via the **PageIndex** library (hosted SaaS at `api.pageindex.ai`): submit a PDF, poll `is_retrieval_ready`, inspect the JSON tree from `get_tree`, retrieve via `submit_query` + `get_retrieval` polling, then expose `get_outline` and `search_doc` as `@tool`s for a `create_agent` to navigate. Requires `PAGEINDEX_API_KEY` in `.env` in addition to `OPENAI_API_KEY`.

`langchain_middleware_examples.ipynb` (root) and `vibe_training_demo.ipynb` are supplementary.

### Key v1 API patterns used throughout

- **Agents**: always `from langchain.agents import create_agent` — never the deprecated `AgentExecutor` or `initialize_agent`.
- **Stateful agents**: pair `create_agent(..., checkpointer=InMemorySaver())` with `config={"configurable": {"thread_id": "..."}}` on every `.invoke()` / `.stream()` call. The thread_id is what makes summarization and human-in-the-loop work across turns.
- **Middleware**: composed via the `middleware=[...]` kwarg on `create_agent`. Order matters.
- **Human-in-the-loop**: when the agent returns a dict containing `__interrupt__`, resume by invoking with `Command(resume={"decisions": [{"type": "approve" | "reject" | "edit", ...}]})` using the **same** `thread_id`.
- **Structured output**: two distinct paths — `model.with_structured_output(Schema)` returns the parsed object directly, while `create_agent(response_format=Schema)` returns it under `result["structured_response"]` alongside the message history.

### `test_summarization_middleware.py`

Standalone verification script (not pytest) — five `test_*` functions called from `__main__`. Each test creates a fresh agent with deliberately low summarization thresholds (e.g. `trigger=("messages", 4)`) so summarization fires within a handful of turns. Uses `gpt-4o-mini` for cost. If you add a test, follow the same pattern: print observable evidence (message counts, summary detection) rather than asserting.

## Editing conventions for this repo

- Notebook examples intentionally repeat boilerplate (env loading, imports) per cell so students can run any cell standalone — don't refactor this away.
- Keep model names current with what the notebooks already use (`gpt-5`, `gpt-4o`, `gpt-4o-mini`, `gpt-4.1`, `gemini-2.5-flash`, `groq:qwen/qwen3-32b`). Don't silently swap providers.
- The repo is Windows-first (developer's primary env). Prefer commands that work in PowerShell when adding shell instructions.
