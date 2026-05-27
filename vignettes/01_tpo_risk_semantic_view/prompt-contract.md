---
id: 01_tpo_risk_semantic_view
inherits: ../../infrastructure/prompt-contract.md
depends_on: [infrastructure]
role: OB_DEMO_RW
warehouse: OB_DEMO_AI_WH
database: OPTIMAL_BLUE_DEMO
schema: AI
output_files: [01_tpo_risk_semantic_view.sql, sample_questions.md]
est_runtime_min: 3
cortex_code_skills: [semantic-view, create_semantic_view, evaluate_and_optimize_semantic_view]
---

# V1 - TPO / Counterparty Risk Semantic View

## Goal
Build a Cortex Analyst-ready semantic view (`AI.TPO_RISK_SV`) that lets a
Comergence persona ask plain-English questions about counterparty risk:
license expirations, audit findings, exception volume, onboarding speed,
and (via the cross-org seed) which investors a TPO concentrates on.

## Business context (Comergence + cross-org bridge)
This is the structured-data spine of the Comergence story. Today Shawnee's
team answers these questions across Tableau + Azure SQL Server + Excel.
Putting them in a semantic view makes them text-to-SQL queryable for
22,000 originators in one place - and seeds V3 (the agent) and V4 (the
cross-org bridge to PPE locks).

## Inputs (FQNs)
- `COMERGENCE.TPO`
- `COMERGENCE.LOAN_OFFICER`
- `COMERGENCE.NMLS_LICENSE`
- `COMERGENCE.AUDIT_FINDING`
- `COMERGENCE.EXCEPTION`
- `COMERGENCE.ONBOARDING_EVENT`
- `COMERGENCE.STATE`, `COMERGENCE.CHANNEL`, `COMERGENCE.INVESTOR`

## Deliverables
- `OPTIMAL_BLUE_DEMO.AI.TPO_RISK_SV` (Snowflake SEMANTIC VIEW)
- `vignettes/01_tpo_risk_semantic_view/sample_questions.md` - 10 verified
  natural-language questions Cortex Analyst should answer correctly

## Acceptance criteria
- The view compiles and is queryable via `SELECT * FROM SEMANTIC_VIEW(...)`.
- Cortex Analyst answers all 10 sample questions with semantically correct
  SQL on the first try.
- Metrics include: open_findings, high_severity_findings, license_expiry_30d,
  active_lo_count, days_to_active, exception_count, suspended_tpo_count.
- Dimensions include: state, region, channel, risk_tier, status,
  primary_investor, finding_category.

## Cortex Code talk track (live demo - 5-block runbook)

### 1. Setup
- Active role: `OB_DEMO_RW`
- Active warehouse: `OB_DEMO_AI_WH`
- Snowsight worksheet, set DB=OPTIMAL_BLUE_DEMO, schema=AI
- This contract open in Workspaces left rail; Cortex Code panel right

### 2. Prompt to paste verbatim
> @vignettes/01_tpo_risk_semantic_view/prompt-contract.md
> Use the `semantic-view` skill. Generate the SQL exactly per this
> contract into a file named `01_tpo_risk_semantic_view.sql`. Include
> the AI.TPO_FACT view, the SEMANTIC VIEW with all listed metrics and
> dimensions plus their synonyms, and a final SELECT * FROM SEMANTIC_VIEW(...)
> smoke test. Reflect the model before showing it to me.

### 3. Expected output
- File `01_tpo_risk_semantic_view.sql`, ~120 lines
- `CREATE OR REPLACE VIEW AI.TPO_FACT AS ...`
- `CREATE OR REPLACE SEMANTIC VIEW AI.TPO_RISK_SV ...`
- 13 metrics, 10 dimensions, synonyms on most
- Final smoke-test SELECT against the semantic view

### 4. Verify after running
```sql
SELECT * FROM SEMANTIC_VIEW(
  AI.TPO_RISK_SV
  DIMENSIONS region, risk_tier
  METRICS    tpo_count, open_findings, licenses_expiring_30d
) ORDER BY 1,2;
```
Then open Cortex Analyst on `AI.TPO_RISK_SV`, run the 10 questions in
`sample_questions.md`. All should return correct SQL on the first try.

### 5. Recovery move
If live generation drifts: open `01_tpo_risk_semantic_view.sql` in this
folder (the pre-built fallback) and run it. Same outcome, ~30 sec.
