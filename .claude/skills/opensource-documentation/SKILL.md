---
name: opensource-documentation
description: >-
  Look up recent, version-accurate documentation for a specific open-source
  library using the Context7 MCP plugin. Use when the user asks "how do I use
  <library>", "docs for <library>", "what's the latest API for <library>",
  "show me <library> examples", or invokes /opensource-documentation <library>
  [topic]. Internally calls Context7 (resolve-library-id → get-library-docs) to
  pull up-to-date docs straight from the source, then presents a concise,
  example-driven answer with the resolved library ID cited.
---

# Open-Source Documentation (via Context7)

Given an open-source library (optionally a sub-topic or version), fetch its
**current** documentation through the **Context7** MCP server and present a
concise, accurate, example-driven answer. Context7 pulls docs straight from the
library's own source/docs, so it reflects recent releases — prefer it over the
model's training memory, which may be stale.

## Input

Parse the request into:

1. **Library** (required) — the package/repo name, e.g. `langchain`, `fastapi`,
   `next.js`, `drizzle-orm`. Taken from the `/opensource-documentation <library>`
   argument or the library named in the user's request.
2. **Topic** (optional) — a specific area to focus the docs on, e.g.
   "middleware", "streaming", "structured output", "migration to v1".
3. **Version** (optional) — if the user pins a version, note it and prefer
   matching docs.

If no library is discernible, ask one short clarifying question before fetching.

## Workflow

1. **Resolve the library ID.** Call Context7's resolver first — never guess the
   ID:

   - Tool: `resolve-library-id`
   - Arguments: `{ "libraryName": "<library>" }`

   This returns one or more Context7-compatible IDs (e.g.
   `/langchain-ai/langchain`, `/vercel/next.js`). Pick the best match by:
   name exactness, GitHub stars / popularity, and documentation coverage. If
   several plausibly match, choose the most authoritative and say which you used.

2. **Fetch the docs.** Call:

   - Tool: `get-library-docs`
   - Arguments:
     `{ "context7CompatibleLibraryID": "<resolved-id>", "topic": "<topic if any>", "tokens": 5000 }`
     (raise `tokens` for broad topics, lower for narrow lookups; omit `topic`
     for a general overview).

3. **Read and verify.** Use the returned documentation as the ground truth.
   Prefer the docs' own code snippets and current API names. Do not blend in
   outdated patterns from memory — if the docs show a newer idiom, use it.

4. **Synthesize.** Answer the user's actual question grounded in the fetched
   docs: explain the concept, show a minimal working code example, and call out
   version-sensitive details (deprecations, renamed APIs, "new in vX").

## Output format

Present the answer as Markdown:

````
## <Library>[ — <topic>]

<1–3 sentence answer to the user's intent, noting the version if relevant.>

### Usage
```<language>
<minimal, current code example drawn from the docs>
```

### Notes
- <version-sensitive detail, deprecation, or gotcha>
- <related API worth knowing>

_Docs via Context7: `<resolved-library-id>`_
````

Keep it tight and runnable. Lead with the answer; cite the resolved Context7
library ID at the end so the source is traceable.

## Fallbacks

- **Context7 tools not available?** The Context7 MCP server loads at session
  start. If neither `resolve-library-id` nor `get-library-docs` is callable
  (names may carry an MCP prefix like `mcp__context7__*` depending on the plugin
  version — use whichever `*context7*` tools are exposed), tell the user
  Context7 isn't loaded and how to add it:

  ```bash
  claude mcp add context7 -- npx -y @upstash/context7-mcp
  ```

  Then offer to answer **now** using `WebSearch` + `WebFetch` against the
  library's official docs as a labeled substitute (note it isn't Context7).

- **Library not found / ambiguous?** If `resolve-library-id` returns no good
  match, report the closest candidates and ask the user to confirm, or fall
  back to official-docs WebFetch. Never invent an API.

- **Docs returned but thin?** Re-query with a broader `topic` or higher
  `tokens` once before reporting limited coverage.

## Notes

- Always resolve the ID with `resolve-library-id` before `get-library-docs` —
  passing a guessed ID is the most common failure.
- Cite the exact resolved library ID; never fabricate version numbers or APIs.
- This is a teaching repo (LangChain 1.x bootcamp). For LangChain/LangGraph
  questions, prefer the v1 idioms (`create_agent`, middleware, `init_chat_model`)
  and flag anything the docs mark as deprecated (`AgentExecutor`,
  `initialize_agent`).
