---
name: litellm-callback-pitfall
description: litellm.input_callback silently swallows exceptions — never use it for blocking guardrails
metadata:
  type: feedback
---

`litellm.input_callback` (and the callback system generally) swallows exceptions raised inside the callback — the request still proceeds to the API. This was discovered during review of `llm_gateway_tutorial.ipynb` cell-51, where a `GuardrailViolation` raised inside `injection_guardrail` did not block the LLM call. The LLM still responded.

**Why:** LiteLLM's callback hooks are designed for logging/mutation, not for request blocking. They run in a context where exceptions are caught internally.

**How to apply:** For blocking guardrails (PII redaction, injection checks, topic filters), validate BEFORE calling `completion()` in a wrapper function — do not register as `litellm.input_callback`. For observability-only callbacks (logging, cost tracking), the callback system is fine but may need a `time.sleep()` flush for async execution in Jupyter.

See also: [[litellm-success-callback-async]] (success_callback timing in Jupyter)
