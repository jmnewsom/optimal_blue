---
id: 04_cross_org_bridge
inherits: ../../infrastructure/prompt-contract.md
depends_on: [infrastructure, 01_tpo_risk_semantic_view]
role: OB_DEMO_RW
warehouse: OB_DEMO_AI_WH
database: OPTIMAL_BLUE_DEMO
schema: SHARED
output_files: [04_tpo_performance_views.sql]
est_runtime_min: 2
cortex_code_skills: [sql-author]
verifications: [sql-verify]
---

# V4 - Cross-org Bridge: TPO Performance + Lock / Pull-through

## Goal
Join Comergence TPO compliance data to PPE locks/fallout to produce
`SHARED.TPO_PERFORMANCE_V` and a derivative `SHARED.TPO_SCORECARD_V`.
This is the **strategic moment** of the demo: same TPO, both worlds.

## Business context
Today these datasets live in different products and different stacks at
Optimal Blue. In Snowflake they share a database. The scorecard answers:
"which compliant TPOs deliver the best execution?" - which is the joint
value prop for Comergence + PPE / Capital Markets.

## Inputs
- `COMERGENCE.TPO`, `AUDIT_FINDING`, `NMLS_LICENSE`
- `PPE.LOCK`

## Deliverables
- `SHARED.TPO_PERFORMANCE_V`  - per-TPO metrics joined across both worlds
- `SHARED.TPO_SCORECARD_V`    - shareable scorecard (used by V5 + V6)

## Acceptance criteria
- View runs without error.
- No row fanout: `COUNT(*)` from view equals `COUNT(*)` from `COMERGENCE.TPO`.
- Pull-through pct between 0 and 100; fallout pct between 0 and 100;
  compliance score in [0,100].

## Cortex Code talk track (live demo - 5-block runbook)

### 1. Setup
- Active role: `OB_DEMO_RW`
- Active warehouse: `OB_DEMO_AI_WH`
- DB=OPTIMAL_BLUE_DEMO, schema=SHARED

### 2. Prompt to paste verbatim
> @vignettes/04_cross_org_bridge/prompt-contract.md
> Use the `sql-author` skill. Generate the SQL exactly per this
> contract into a file named `04_tpo_performance_views.sql`. Build
> SHARED.TPO_LOCK_METRICS_V (PPE side, aggregated first), then
> SHARED.TPO_COMPLIANCE_METRICS_V (Comergence side with compliance_score),
> then SHARED.TPO_PERFORMANCE_V joining both, and finally
> SHARED.TPO_SCORECARD_V (the lender-facing projection used by V5/V6).
> When you finish, kick off the `sql-verify` subagent on the join logic
> while I review.

### 3. Expected output
- File `04_tpo_performance_views.sql`, ~120 lines
- 4 views: TPO_LOCK_METRICS_V, TPO_COMPLIANCE_METRICS_V, TPO_PERFORMANCE_V, TPO_SCORECARD_V
- compliance_score formula GREATEST(0, 100 - penalties)
- Verification block confirming `COUNT(*)` of TPO_PERFORMANCE_V == COUNT(*) of COMERGENCE.TPO

### 4. Verify after running
```sql
SELECT (SELECT COUNT(*) FROM COMERGENCE.TPO)            AS expected,
       (SELECT COUNT(*) FROM SHARED.TPO_PERFORMANCE_V)  AS actual;
SELECT MIN(compliance_score), MAX(compliance_score),
       MIN(pull_through_pct), MAX(pull_through_pct)
FROM SHARED.TPO_PERFORMANCE_V;
```
Wait for the `sql-verify` subagent to return - it should confirm no fanout.

### 5. Recovery move
Open `04_tpo_performance_views.sql` in this folder and run it.
