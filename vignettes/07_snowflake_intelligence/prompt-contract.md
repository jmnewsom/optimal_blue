---
id: 07_snowflake_intelligence
inherits: ../../infrastructure/prompt-contract.md
depends_on: [03_counterparty_oversight_agent, 04_cross_org_bridge]
role: OB_DEMO_RW
warehouse: OB_DEMO_AI_WH
database: OPTIMAL_BLUE_DEMO
schema: AI
output_files: [07_tpo_performance_si_semantic_view.sql, talk_track.md]
est_runtime_min: 2
cortex_code_skills: [cortex-agent]
---

# V7 - Snowflake Intelligence capstone

## Goal
Surface the V3 agent and a second cross-org semantic view inside
Snowflake Intelligence (SI) so a non-technical user can ask questions
that span Comergence + PPE in plain English. This is the close.

## Deliverables
- `OPTIMAL_BLUE_DEMO.AI.TPO_PERFORMANCE_SV` (SI-friendly semantic view
  over `SHARED.TPO_PERFORMANCE_V`)
- The existing `AI.COUNTERPARTY_AGENT` is automatically reachable from SI.

## Cortex Code talk track (live demo - 5-block runbook)

### 1. Setup
- Active role: `OB_DEMO_RW`
- Active warehouse: `OB_DEMO_AI_WH`
- DB=OPTIMAL_BLUE_DEMO, schema=AI
- V3 (`AI.COUNTERPARTY_AGENT`) and V4 (`SHARED.TPO_PERFORMANCE_V`) must exist

### 2. Prompt to paste verbatim
> @vignettes/07_snowflake_intelligence/prompt-contract.md
> Generate the SQL exactly per this contract into a file named
> `07_tpo_performance_si_semantic_view.sql`. Wrap SHARED.TPO_PERFORMANCE_V
> as a SEMANTIC VIEW named AI.TPO_PERFORMANCE_SV with risk_tier /
> channel_code / state_code / tpo_status dimensions and tpo_count /
> avg_compliance_score / avg_pull_through / total_funded_volume metrics.

### 3. Expected output
- File `07_tpo_performance_si_semantic_view.sql`, ~30 lines
- `CREATE OR REPLACE SEMANTIC VIEW AI.TPO_PERFORMANCE_SV ...`
- Smoke-test SELECT against the view

### 4. Verify after running
Navigate Snowsight -> AI & ML -> Snowflake Intelligence:
- Create workspace "Optimal Blue - Comergence"
- Add agent `AI.COUNTERPARTY_AGENT`
- Add semantic views `AI.TPO_RISK_SV`, `AI.TPO_PERFORMANCE_SV`
- Add search service `AI.COMPLIANCE_CSS`
- Run the 3 closing prompts in `talk_track.md`

### 5. Recovery move
Open `07_tpo_performance_si_semantic_view.sql` in this folder and run it.
