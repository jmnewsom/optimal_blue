---
id: 03_counterparty_oversight_agent
inherits: ../../infrastructure/prompt-contract.md
depends_on: [01_tpo_risk_semantic_view, 02_cortex_search_compliance]
role: OB_DEMO_RW
warehouse: OB_DEMO_AI_WH
database: OPTIMAL_BLUE_DEMO
schema: AI
output_files: [03_counterparty_oversight_agent.sql, demo_script.md]
est_runtime_min: 4
cortex_code_skills: [cortex-agent, create-cortex-agent, agent-optimization]
---

# V3 - Counterparty Oversight Agent (centerpiece)

## Goal
Create a Cortex Agent (`AI.COUNTERPARTY_AGENT`) that uses two tools:
- **TPO_RISK_SV** semantic view (V1) for structured questions
- **COMPLIANCE_CSS** Cortex Search service (V2) for guideline / audit lookups

The agent composes per-TPO finding lookups via the analyst tool's
generated SQL - no separate function needed. System instructions tune
the agent for a Comergence persona; the planner chooses tools; the
responder cites sources with a strict citation format.

## Business context
This is the demo's centerpiece. Shawnee should walk away saying *"this is
the workflow my team does manually all day"*. The agent answers TPO-level
oversight questions in seconds, citing structured metrics AND guideline
text in the same response.

## Optimization criteria (binding)

The agent MUST satisfy all 10 best-practice criteria - these came out of
a live audit and were verified deployed:

1. `instructions.response` is structured into labeled sections
   (PERSONA / STYLE / FORMAT / LENGTH / CITATIONS / GROUNDING / TOOL
   ROUTING / SCOPE-REFUSAL).
2. Each tool's `description` lists concrete METRICS / DIMENSIONS
   (analyst) or doc_type values (search) so the planner routes
   accurately by vocabulary match.
3. `sample_questions` has at least 6 entries covering: state-level
   aggregate, time-window aggregate, qualitative search, per-TPO
   structured lookup, remediation drafting, onboarding-funnel.
4. Explicit citation format: `[TPO_RISK_SV]` for numbers,
   `[COMPLIANCE_SEARCH: <chunk title>]` for text.
5. Explicit refusal guardrail for out-of-scope questions (consumer
   mortgage advice, capital markets pricing, hedge calculations).
6. Search `max_results: 8` (not the default 5) for richer grounding.
7. Length cap: under 12 bullets unless the user explicitly asks for more.
8. Format guidance: bullets for lists, tables for 3+ entity comparisons,
   prose only for short narrative.
9. Tool-routing rules organized inside `instructions.response` with
   trigger-word hints. Note: `orchestration: {}` MUST stay empty -
   nested `orchestration.instructions` is rejected by Snowflake.
10. SQL file ends with a 6-prompt programmatic eval block using
    `SNOWFLAKE.CORTEX.DATA_AGENT_RUN(<agent_fqn>, $$<body>$$)` (5 happy-path
    + 1 refusal). The function name is `DATA_AGENT_RUN`, NOT `AGENT_RUN`
    (the latter is for inline agents without an object). The request body
    MUST be a `$$...$$` literal; do NOT include `thread_id` or
    `parent_message_id` on a fresh thread (Snowflake rejects with
    `Thread 0 does not exist or not authorized`). Verified live: 6/6 pass.

## Inputs (FQNs)
- `OPTIMAL_BLUE_DEMO.AI.TPO_RISK_SV` (V1)
- `OPTIMAL_BLUE_DEMO.AI.COMPLIANCE_CSS` (V2)

## Deliverables
- `OPTIMAL_BLUE_DEMO.AI.COUNTERPARTY_AGENT`
- `vignettes/03_counterparty_oversight_agent/demo_script.md`

## Acceptance criteria
- Agent runs without error using `OB_DEMO_RW`.
- All 10 optimization criteria above present in `agent_spec`.
- All 6 demo-script prompts route to the expected tool with a cited,
  on-format response.
- Out-of-scope prompt is politely refused.

## Cortex Code talk track (live demo - 5-block runbook)

### 1. Setup
- Active role: `OB_DEMO_RW`
- Active warehouse: `OB_DEMO_AI_WH`
- DB=OPTIMAL_BLUE_DEMO, schema=AI
- V1 (`AI.TPO_RISK_SV`) and V2 (`AI.COMPLIANCE_CSS`) must already exist

### 2. Prompt to paste verbatim
> @vignettes/03_counterparty_oversight_agent/prompt-contract.md
> Use the `cortex-agent` skill. Generate the SQL exactly per this
> contract into a file named `03_counterparty_oversight_agent.sql`.
> Apply ALL 10 optimization criteria. Use 2 tools (no function tool).
> orchestration MUST stay {} (Snowflake rejects orchestration.instructions).
> Put tool-routing rules inside instructions.response with trigger-word
> hints. End the file with the 6-prompt eval block.

### 3. Expected output
- File `03_counterparty_oversight_agent.sql`, ~90 lines
- `CREATE OR REPLACE AGENT AI.COUNTERPARTY_AGENT ... FROM SPECIFICATION $$ ... $$`
- Exactly TWO tool_specs (cortex_analyst_text_to_sql + cortex_search)
- `instructions.response` contains labeled sections matching the 10 criteria
- 6 `sample_questions` (one per main use case)
- `tool_resources.COMPLIANCE_SEARCH.max_results = 8`
- Closing eval block listing 6 prompts + expected routing

### 4. Verify after running
```sql
DESCRIBE AGENT AI.COUNTERPARTY_AGENT;
```
Then execute the 6-prompt eval block at the bottom of
`03_counterparty_oversight_agent.sql` (uses `DATA_AGENT_RUN`) - or run
the same prompts in the Snowsight Agent Run UI. Live verified: 6/6 pass
(5 happy-path routed to expected tools, 1 refusal cited scope and offered
in-scope alternatives).

### 5. Recovery move
Open `03_counterparty_oversight_agent.sql` in this folder and run it.
The pre-built file is the canonical reference and matches the deployed agent.
