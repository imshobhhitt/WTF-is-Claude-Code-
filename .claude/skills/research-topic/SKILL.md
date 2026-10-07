---
name: research-topic
description: >-
  Research any topic using BOTH Exa (mcp__exa__*) and the built-in WebSearch
  tool together, then cross-reference and synthesize the findings into one
  well-sourced overview. Use when the user asks to "research X", "find info
  about X", "what's the latest on X", "look up / tell me about X", or invokes
  /research-topic <topic>. Unlike topic-research (Exa-only), this skill always
  queries both providers and merges their results.
---

# Research Topic (Exa + WebSearch)

Given a topic, research it using **two independent search providers** — the
**Exa** MCP server and the built-in **WebSearch** tool — then combine, dedupe,
and cross-validate their results into a single concise, well-sourced overview.

Using two providers reduces blind spots: Exa is strong on semantic/neural
retrieval and source quality; WebSearch is strong on fresh, broadly-indexed
results. Agreement across both raises confidence; disagreement is worth noting.

## Input

The topic is taken from, in order of preference:

1. The argument passed to `/research-topic <topic>`.
2. The topic named in the user's natural-language request.

If no topic is discernible, ask the user one short clarifying question before
searching.

## Workflow

1. **Frame the query.** Turn the topic into a focused search query. For broad
   topics, choose the most useful angle (e.g. "latest developments",
   "overview", "how it works"). Preserve the user's intent and any depth cues.

2. **Search with BOTH providers — in parallel.** Issue both calls in the same
   turn so they run concurrently:

   - **Exa:** `mcp__exa__web_search_exa` with
     `{ "query": "<your query>", "numResults": 5 }`
     (raise to 8–10 for broad/ambiguous topics).
   - **WebSearch:** the built-in `WebSearch` tool with the same (or a lightly
     rephrased) query.

   For specialized topics, also pick the most fitting Exa tool when one is
   clearly better — still alongside WebSearch:

   | Topic shape                        | Preferred Exa tool             |
   | ---------------------------------- | ------------------------------ |
   | General / news / "latest on X"     | `mcp__exa__web_search_exa`     |
   | A specific company                 | `mcp__exa__company_research`   |
   | A specific person (professional)   | `mcp__exa__linkedin_search`    |
   | Extract a known page's full text   | `mcp__exa__crawling`           |
   | Deep multi-step investigation      | `mcp__exa__deep_researcher_start` → `mcp__exa__deep_researcher_check` |
   | Code / library / API usage         | `mcp__exa__get_code_context_exa` |

   All Exa tools share the `mcp__exa__` prefix. Names vary slightly across
   plugin versions — if a referenced name isn't available, use whichever
   `mcp__exa__*` search tool is exposed.

3. **Merge and dedupe.** Pool the results from both providers. Drop duplicate
   URLs and near-duplicate content. Discard low-quality or irrelevant hits.
   Track which provider(s) surfaced each kept source.

4. **Cross-validate.** Prefer claims that **both** providers support. When the
   two sources disagree on a fact (dates, numbers, status), surface the
   discrepancy rather than silently picking one. Never invent facts the results
   don't support.

5. **Synthesize.** Write a short, structured overview in your own words,
   grounded in the merged results. Attribute claims to sources where it matters.

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
1. [<Title>](<url>) — _Exa_
2. [<Title>](<url>) — _WebSearch_
3. [<Title>](<url>) — _Exa + WebSearch_
```

Tag each source with the provider(s) that surfaced it. Lead with the answer;
keep it tight and skimmable; sources at the end.

## Fallbacks

- **Exa tools not available?** The Exa MCP server loads at session start. If no
  `mcp__exa__*` tool is callable, proceed with **WebSearch only** and tell the
  user Exa was unavailable (the `exa@claude-plugins-official` plugin must be
  enabled and `EXA_API_KEY` set; a restart usually fixes it).
- **WebSearch unavailable?** Proceed with **Exa only** and note it.
- **Both unavailable?** Tell the user you can't research right now and why —
  never fabricate sources.
- **No useful results?** Broaden or rephrase the query and search both providers
  once more before reporting that little was found.

## Notes

- Always cite real URLs returned by the tools — never placeholder or guessed
  links.
- Respect the user's depth cues: "quick" → 3 bullets + 3 sources; "deep" →
  raise `numResults` and consider Exa's `deep_researcher_start` /
  `deep_researcher_check`.
- This is a teaching repo (LangChain bootcamp); for technical topics prefer
  authoritative/official sources and note version-sensitivity.
