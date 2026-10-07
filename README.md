# LangChain 1.x — Agentic AI Workspace

A personal workspace built around the **LangChain 1.x** agent API, covering core concepts from basic agent creation through advanced middleware, structured output, and vectorless RAG. The numbered notebooks in `updatedlangchain/` form a sequential curriculum; `CLAUDE.md` contains the full architecture reference for Claude Code.

## Repository layout

```
updatedlangchain/          # Numbered notebook curriculum (run in order)
  1-langchainintro.ipynb
  2-modelintegration.ipynb
  3-tools.ipynb
  4-messages.ipynb
  5-structuredoutput.ipynb
  6-middleware.ipynb
  7-vectorlessrag.ipynb
  vibe_training_demo.ipynb  # Supplementary

.claude/
  agents/                   # Project-scoped Claude Code subagents
    code-improvement-advisor.md
  settings.json             # Agent Teams enabled + notification hooks

test_summarization_middleware.py   # Standalone verification script
test_example.py                    # Minimal unittest example
my-first-plugin/                   # Claude Code plugin scaffold
pyproject.toml                     # Canonical dependency manifest (uv)
requirements.txt                   # pip fallback
```

## Notebook curriculum

| # | Notebook | Topics |
|---|----------|--------|
| 1 | `1-langchainintro.ipynb` | `create_agent` basics, simple `@tool` functions |
| 2 | `2-modelintegration.ipynb` | `init_chat_model`, `ChatOpenAI` / `ChatGoogleGenerativeAI` / `ChatGroq`, `.stream()`, `.batch()` |
| 3 | `3-tools.ipynb` | `@tool` decorator, `bind_tools`, manual tool-execution loop |
| 4 | `4-messages.ipynb` | Message types and the conversation history model |
| 5 | `5-structuredoutput.ipynb` | `with_structured_output` (Pydantic / TypedDict / dataclass); `create_agent(response_format=...)` |
| 6 | `6-middleware.ipynb` | `SummarizationMiddleware` (message / token / fraction triggers); `HumanInTheLoopMiddleware` with `Command(resume=...)` |
| 7 | `7-vectorlessrag.ipynb` | Vectorless RAG via **PageIndex** — PDF ingestion, tree inspection, `submit_query` polling, `@tool`-wrapped retrieval |

## Setup

**Python ≥ 3.13** is required.

```powershell
# Sync all dependencies (uv is canonical; uv.lock is the source of truth)
uv sync

# Launch Jupyter for the notebooks
uv run jupyter lab
```

Secrets live in `.env` at the repo root:

| Variable | Required by |
|----------|-------------|
| `OPENAI_API_KEY` | All notebooks and the middleware test script |
| `GOOGLE_API_KEY` | `2-modelintegration.ipynb` |
| `GROQ_API_KEY` | `2-modelintegration.ipynb` |
| `PAGEINDEX_API_KEY` | `7-vectorlessrag.ipynb` |

## Tests

### `test_summarization_middleware.py`

A standalone verification script (not pytest) that exercises `SummarizationMiddleware` across five scenarios. Each test builds a fresh `create_agent` with deliberately low thresholds so summarization fires within a handful of turns, then prints observable evidence (message counts, detected summaries) rather than hard-asserting. Uses `gpt-4o-mini`; **requires `OPENAI_API_KEY`** and makes real API calls.

```powershell
uv run python test_summarization_middleware.py
```

| # | Test | What it covers |
|---|------|----------------|
| 1 | `test_basic_summarization` | Message-count trigger (`trigger=(\"messages\", 6)`, `keep=(\"messages\", 2)`) |
| 2 | `test_token_based_summarization` | Token trigger (`trigger=(\"tokens\", 500)`, `keep=(\"messages\", 4)`) |
| 3 | `test_inspect_summarization` | Full before/after message inspection with summary detection |
| 4 | `test_custom_summary_prompt` | Custom `summary_prompt` and `summary_prefix` |
| 5 | `test_streaming_with_summarization` | Summarization under `agent.stream(..., stream_mode=\"updates\")` |

### `test_example.py`

A minimal, self-contained `unittest` example (no API calls) demonstrating the standard `assert*` pattern.

```powershell
uv run python -m unittest test_example -v
```

## Key API patterns

All notebooks follow the LangChain v1 conventions:

- **Agents**: `from langchain.agents import create_agent` — never the deprecated `AgentExecutor` or `initialize_agent`.
- **Stateful agents**: `create_agent(..., checkpointer=InMemorySaver())` paired with `config={\"configurable\": {\"thread_id\": \"...\"}}` on every `.invoke()` / `.stream()` call.
- **Middleware**: composed via the `middleware=[...]` kwarg on `create_agent`; order matters.
- **Human-in-the-loop**: resume from an `__interrupt__` with `Command(resume={\"decisions\": [...]})` using the **same** `thread_id`.
- **Structured output**: `model.with_structured_output(Schema)` returns the parsed object directly; `create_agent(response_format=Schema)` returns it under `result[\"structured_response\"]`.

## Claude Code integration

### Custom subagent

`.claude/agents/code-improvement-advisor.md` defines a project-scoped subagent available when working in Claude Code. It can be invoked via `/agents` or delegated to automatically based on its description.

### Agent Teams

`settings.json` enables the experimental Agent Teams feature:

```json
{
  "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" }
}
```

This allows spawning **persistent, named teammates** that share a task list and can message each other across turns — useful for parallel workflows like authoring a notebook while a tester validates the middleware script concurrently.

### Notification hooks

`settings.json` also wires a `Notification` hook (`notify.ps1`) and a `PostToolUse` hook (`posttool.sh`) for desktop notifications and per-tool logging.
