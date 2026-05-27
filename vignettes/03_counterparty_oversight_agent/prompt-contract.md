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
responder cites sources.

## Business context
This is the demo's centerpiece. Shawnee should walk away saying *"this is
the workflow my team does manually all day"*. The agent answers TPO-level
oversight questions in seconds, citing structured metrics AND guideline
text in the same response.

## Deliverables
- `OPTIMAL_BLUE_DEMO.AI.COUNTERPARTY_AGENT`
- `vignettes/03_counterparty_oversight_agent/demo_script.md` - 5 prompts to run live

## Acceptance criteria
- Agent runs without error using `OB_DEMO_RW`.
- All 5 demo-script prompts return: useful answer + citation reference to
  the originating tool (semantic view OR search service OR SQL).

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
> Include the AI.REMEDIATION_LOOKUP function and CREATE OR REPLACE
> AGENT AI.COUNTERPARTY_AGENT with three tools: cortex_analyst_text_to_sql
> over AI.TPO_RISK_SV, cortex_search over AI.COMPLIANCE_CSS, and the
> generic REMEDIATION_LOOKUP function.

### 3. Expected output
- File `03_counterparty_oversight_agent.sql`, ~80 lines
- `CREATE OR REPLACE AGENT AI.COUNTERPARTY_AGENT ... FROM SPECIFICATION $$ ... $$`
- Exactly TWO tool_specs declared (cortex_analyst_text_to_sql + cortex_search)
- `tool_resources` uses `"semantic_view"` and `"search_service"` keys; analyst tool resource includes `execution_environment` block
- Closing `SHOW AGENTS` / `DESCRIBE AGENT` smoke test

### 4. Verify after running
```sql
DESCRIBE AGENT AI.COUNTERPARTY_AGENT;
```
Then open the agent in Snowsight (or Snowflake Intelligence after V7)
and run the 5 prompts in `demo_script.md`. >=4/5 should be acceptable.

### 5. Recovery move
Open `03_counterparty_oversight_agent.sql` in this folder and run it.
The pre-built file is the canonical reference.
