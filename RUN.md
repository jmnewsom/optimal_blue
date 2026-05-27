# RUN.md - Optimal Blue / Comergence Demo

This is the **table of contents** for the demo workspace. Open this file
first inside Snowsight Workspaces, then work top-down.

## How the demo flows

```mermaid
flowchart LR
    A["Snowsight Workspaces<br/>(Git repo mounted)"] -->|browse left rail| B["NN_prompt-contract.md"]
    B -->|@-mention in Cortex Code panel| C["Cortex Code in Snowsight"]
    C -->|generates SQL live| D["Snowsight worksheet"]
    D -->|run| E["Snowflake objects"]
    F["NN_<deliverable>.sql<br/>(fallback)"] -.recovery.-> D
```

## Pre-flight (do before the call)

1. As `SYSADMIN`: run `docs/reset_demo.sql` if any prior demo state exists.
2. As `SYSADMIN`: run `infrastructure/00_setup_db_roles_wh.sql`.
3. As `OB_DEMO_RW`: run `infrastructure/01_synthetic_comergence.sql`,
   `02_synthetic_ppe.sql`, `03_load_unstructured.sql`.
4. Pre-deploy V6 Streamlit: `snow streamlit deploy ob_comergence_dashboard --replace`.
5. Open this file in Snowsight Workspaces; open Cortex Code panel on the right.
6. Open TWO additional Snowsight tabs - one logged in as `OB_DEMO_LENDER_BIG`, one as `OB_DEMO_LENDER_SMALL` (V5 multi-tenant demo).

## Run order during the call

| # | Open this contract | Live-generate this file | Object created |
| --- | --- | --- | --- |
| Infra | `infrastructure/prompt-contract.md` | `00_..03_*.sql` | DB / schemas / WHs / data (DONE in pre-flight) |
| V1 | `vignettes/01_tpo_risk_semantic_view/prompt-contract.md` | `01_tpo_risk_semantic_view.sql` | `AI.TPO_RISK_SV` |
| V2 | `vignettes/02_cortex_search_compliance/prompt-contract.md` | `02_compliance_search_and_aisql.sql` | `AI.COMPLIANCE_CSS` + `COMERGENCE.SOCIAL_FLAG` |
| V3 | `vignettes/03_counterparty_oversight_agent/prompt-contract.md` | `03_counterparty_oversight_agent.sql` | `AI.COUNTERPARTY_AGENT` |
| V4 | `vignettes/04_cross_org_bridge/prompt-contract.md` | `04_tpo_performance_views.sql` | `SHARED.TPO_PERFORMANCE_V`, `TPO_SCORECARD_V` |
| V5 | `vignettes/05_solution_center_marketplace/prompt-contract.md` | `05_tpo_scorecard_share.sql` | `OB_DEMO_TPO_SCORECARD_SHARE` + `LENDER_VIEWS.TPO_SCORECARD` + RAP, served to 2 lender personas |
| V6 | `vignettes/06_streamlit_dashboard/prompt-contract.md` | (pre-deployed; explained live) | SiS app `OB_COMERGENCE_DASHBOARD` |

## The loop, every vignette

1. Click the contract in the left rail.
2. In Cortex Code panel, paste the **block 2** prompt verbatim.
3. Review the generated SQL against the **block 3** "expected output" checklist.
4. Run the SQL in a Snowsight worksheet (correct role + warehouse from YAML).
5. Run the **block 4** verification.
6. If anything drifts, use **block 5** recovery: open the pre-built
   `NN_*.sql` in the same folder and run it.

## Reset (between dry-runs)

```sql
-- as SYSADMIN
@docs/reset_demo.sql
-- then re-run pre-flight steps 2-4
```

## Reference docs

- `docs/demo_runbook.md` - 2-hour minute-by-minute
- `docs/cortex_code_talktrack.md` - what to say while Cortex Code works
- `docs/deploy_to_snowsight_workspaces.md` - one-time Git integration
- `docs/reset_demo.sql` - canonical teardown
