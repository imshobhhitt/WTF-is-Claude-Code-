---
name: topic-research
description: >-
  Research any topic with live web search (Exa) and return a synthesized,
  well-sourced overview. Use when the user asks to "research X", "find info
  about X", "what's the latest on X", "look up / tell me about X", or invokes
  /topic-research <topic>. Internally calls the Exa MCP tools (mcp__exa__*) and
  presents a readable summary with linked sources.
---

# Topic Research (via Exa)

Given a topic, search the live web using the **Exa** MCP server and present a
concise, accurate, well-sourced overview — not a raw dump of search hits.

## Input

The topic is taken from, in order of preference:

1. The argument passed to `/topic-research <topic>`.
2. The topic named in the user's natural-language request.

If no topic is discernible, ask the user one short clarifying question before
searching.

## Workflow

1. **Frame the query.** Turn the topic into a focused search query. For
   broad topics, prefer the most useful angle (e.g. "latest developments",
   "overview", "how it works"). Keep the user's intent.

2. **Search with Exa.** Call the Exa web-search tool:

   - Tool: `mcp__exa__web_search_exa`
   - Arguments: `{ "query": "<your query>", "numResults": 5 }`
     (raise `numResults` to 8–10 for broad/ambiguous topics; lower for narrow ones).

   Pick the most fitting Exa tool for the topic when one is clearly better:

   | Topic shape                        | Preferred Exa tool             |
   | ---------------------------------- | ------------------------------ |
   | General / news / "latest on X"     | `mcp__exa__web_search_exa`     |
   | A specific company                 | `mcp__exa__company_research`   |
   | A specific person (professional)   | `mcp__exa__linkedin_search`    |
   | Extract a known page's full text   | `mcp__exa__crawling`           |
   | Deep multi-step investigation      | `mcp__exa__deep_researcher_start` → `mcp__exa__deep_researcher_check` |
   | Code / library / API usage         | `mcp__exa__get_code_context_exa` |

   All Exa tools share the `mcp__exa__` prefix. If a referenced name isn't
   available, use whichever `mcp__exa__*` search tool is exposed — names vary
   slightly across plugin versions.

3. **Read and verify.** Inspect each result's title, URL, and returned text
   snippet. Discard low-quality, irrelevant, or duplicate hits. Do not invent
   facts that the results don't support.

4. **Synthesize.** Write a short, structured overview in your own words,
   grounded in the results. Attribute claims to sources where it matters.

## Output format

Present the answer as Markdown:

```
## <Topic>

<2–4 sentence synthesized summary answering the user's intent.>

### Key points
- <point grounded in the sources>
- <point …>
- <point …>

### Sources
1. [<Title>](<url>)
2. [<Title>](<url>)
3. …
```

Keep it tight and skimmable. Lead with the answer; sources at the end.

## Fallbacks

- **Exa tools not available?** The Exa MCP server loads at session start. If no
  `mcp__exa__*` tool is callable, tell the user to restart Claude Code (the
  `exa@claude-plugins-official` plugin must be enabled and `EXA_API_KEY` set).
  If they want results now anyway, offer to use the built-in `WebSearch` tool
  as a substitute and label it as such.
- **No useful results?** Broaden or rephrase the query and search once more
  before reporting that little was found. Never fabricate sources.

## Notes

- Always cite real URLs returned by Exa — never placeholder or guessed links.
- Respect the user's depth cues: "quick" → 3 bullets + 3 sources; "deep" →
  consider `deep_researcher_start`/`deep_researcher_check`.
- This is a teaching repo (LangChain bootcamp); when a topic is technical,
  prefer authoritative/official sources and note version-sensitivity.
