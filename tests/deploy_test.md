# Deploy Test Checklist

Run this end-to-end against `WWC76537` (or any clean account) before
the dry-run. Every step has a "what to expect" line and a "if it
fails" recovery hint. Capture any failure in `defects.md` for
follow-up.

## 0. Reset (idempotent)

```sql
-- as SYSADMIN (Snowsight worksheet)
@docs/reset_demo.sql
```

Expect: `OPTIMAL_BLUE_DEMO`, share, three demo warehouses, four demo
roles all dropped.

## 1. Infrastructure

```sql
-- as SYSADMIN
@infrastructure/00_setup_db_roles_wh.sql
```

Expect: 3 warehouses, 4 roles, 1 database, 5 schemas, 1 stage. Final
SHOW SCHEMAS lists `AI / COMERGENCE / INFORMATION_SCHEMA / PPE / SHARED / STAGES`.

```sql
-- as OB_DEMO_RW
@infrastructure/01_synthetic_comergence.sql
@infrastructure/02_synthetic_ppe.sql
@infrastructure/03_load_unstructured.sql
```

Expect: row counts within +/-10% of these targets:

| Table | Target |
| --- | ---: |
| TPO | 22,000 |
| LOAN_OFFICER | 100,000 |
| NMLS_LICENSE | 60,000 |
| AUDIT_FINDING | 250,000 |
| EXCEPTION | 40,000 |
| ONBOARDING_EVENT | 110,000 |
| SOCIAL_POST | 50,000 |
| COMPLIANCE_DOCUMENT | 100 |
| COMPLIANCE_DOC_CHUNK | 800 |
| LOCK | 500,000 |
| RATE_SHEET | 200,000 |

## 2. V1 - TPO Risk Semantic View

```sql
-- as OB_DEMO_RW @ OB_DEMO_AI_WH
@vignettes/01_tpo_risk_semantic_view/01_tpo_risk_semantic_view.sql
```

Expect: `AI.TPO_FACT` view + `AI.TPO_RISK_SV` semantic view created.
Final SELECT shows region x risk_tier with tpo_count / open_findings /
licenses_expiring_30d numbers.

If fail: check `OB_DEMO_RW` has `CREATE SEMANTIC VIEW` on `AI` schema.

## 3. V2 - Cortex Search + AISQL

```sql
-- as OB_DEMO_RW @ OB_DEMO_AI_WH
@vignettes/02_cortex_search_compliance/02_compliance_search_and_aisql.sql
```

Expect: Cortex Search service indexed (target lag 5 min); SOCIAL_FLAG
table populated with ~5,000 rows of {topic, sentiment, compliance_risk}.

If `SEARCH_PREVIEW` returns empty: wait 60s for index build then
re-query. If AISQL errors: confirm account is in a region that supports
AI_CLASSIFY / AI_SENTIMENT (`SHOW REGIONS` and check Cortex region matrix).

## 4. V3 - Counterparty Oversight Agent

```sql
-- as OB_DEMO_RW @ OB_DEMO_AI_WH
@vignettes/03_counterparty_oversight_agent/03_counterparty_oversight_agent.sql
```

Expect: `AI.COUNTERPARTY_AGENT` created with two tools.

`DESCRIBE AGENT AI.COUNTERPARTY_AGENT` should show `agent_spec` containing
`"tool_resources":{"TPO_RISK_SV":{...,"semantic_view":"OPTIMAL_BLUE_DEMO.AI.TPO_RISK_SV"},"COMPLIANCE_SEARCH":{"search_service":"OPTIMAL_BLUE_DEMO.AI.COMPLIANCE_CSS",...}}`.

If "Insufficient privileges to operate on schema 'AI'" - check
`CREATE AGENT` grant from 00_setup.

## 5. V4 - Cross-org bridge

```sql
-- as OB_DEMO_RW @ OB_DEMO_AI_WH
@vignettes/04_cross_org_bridge/04_tpo_performance_views.sql
```

Expect: 4 views created. Final fanout-check:
`expected == actual == 22000`. compliance_score in [0,100],
pull_through_pct in [0,100].

If counts mismatch: a join lost the TPO grain. Re-run sql-verify subagent.

## 6. V5 - Marketplace share + lender simulation

```sql
-- as OB_DEMO_ADMIN @ OB_DEMO_WH
@vignettes/05_solution_center_marketplace/05_tpo_scorecard_share.sql
```

Expect: 1 share, 1 schema (`LENDER_VIEWS`), 1 view (`TPO_SCORECARD`), 1 row-access policy (`SHARED.TPO_SCORECARD_RAP`).

Then in TWO additional Snowsight tabs:

```sql
-- Tab 1: high-volume lender persona
USE ROLE OB_DEMO_LENDER_BIG;
USE SECONDARY ROLES NONE;
USE WAREHOUSE OB_DEMO_LENDER_WH;
SELECT COUNT(*)               FROM OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD;  -- ~11K
SELECT MIN(funded_volume_usd) FROM OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD;  -- > 500000
SELECT * FROM OPTIMAL_BLUE_DEMO.COMERGENCE.TPO LIMIT 1;                           -- expect: denied

-- Tab 2: California regional lender persona
USE ROLE OB_DEMO_LENDER_SMALL;
USE SECONDARY ROLES NONE;
USE WAREHOUSE OB_DEMO_LENDER_WH;
SELECT COUNT(*)            FROM OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD;     -- ~432
SELECT DISTINCT state_code FROM OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD;     -- only 'CA'
SELECT * FROM OPTIMAL_BLUE_DEMO.COMERGENCE.TPO LIMIT 1;                            -- expect: denied
```

If BIG count <= SMALL count, RAP is wired wrong (likely role names mismatch).
If either lender sees `COMERGENCE.TPO`, secondary roles weren't disabled.

## 7. V6 - Streamlit dashboard

Pre-flight (one-time):
```bash
cd vignettes/06_streamlit_dashboard
snow streamlit deploy ob_comergence_dashboard --replace
```

Expect: SiS URL returned. Open it; all 6 KPI cards populated.

If columns appear NULL: check that V4 ran successfully (KPI #5 reads
`SHARED.TPO_PERFORMANCE_V`).

## 8. Run smoke_test.sql

```sql
-- as OB_DEMO_RW
@tests/smoke_test.sql
```

All asserts pass = demo is green. Then run the lender-denial block
(commented at bottom of smoke_test.sql) in a second tab as OB_DEMO_LENDER.

## 9. Defect log template

Copy this into `tests/defects.md` if anything fails:

```
## DEFECT-NN
- File: <vignette>/<file>
- Step: <which step in this checklist>
- Error: <copy-paste exact message>
- Root cause: <what went wrong>
- Fix: <what you changed>
- Re-test: <pass/fail>
```
