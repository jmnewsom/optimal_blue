# Optimal Blue / Comergence - Cortex Code Demo

A 2-hour Cortex Code-driven Snowflake technical deep dive, tailored for
Optimal Blue's Comergence product (counterparty oversight + compliance)
with explicit cross-org bridges to PPE / Capital Markets.

Every artifact in this workspace is **generated live** from a versioned
`prompt-contract.md` by Cortex Code in Snowsight. The pre-built `.sql`
files are kept as fallbacks so the SE can recover quickly if a live
generation drifts on stage.

## Quick start

1. Read [`RUN.md`](RUN.md) - the 1-page table of contents + run order.
2. One-time setup: [`docs/deploy_to_snowsight_workspaces.md`](docs/deploy_to_snowsight_workspaces.md) - mount this repo as a Git-backed Snowsight Workspace.
3. Pre-flight + live demo: [`docs/demo_runbook.md`](docs/demo_runbook.md).
4. Tests: [`tests/deploy_test.md`](tests/deploy_test.md), [`tests/smoke_test.sql`](tests/smoke_test.sql), [`tests/defects.md`](tests/defects.md).

## Layout

```
optimal_blue/
  RUN.md                                # workspace entry point
  README.md                             # this file
  .gitignore
  infrastructure/                       # DB, schemas, RBAC, 3 WHs, synthetic data
    prompt-contract.md
    00_setup_db_roles_wh.sql
    01_synthetic_comergence.sql
    02_synthetic_ppe.sql
    03_load_unstructured.sql
    README.md
  vignettes/
    01_tpo_risk_semantic_view/          # Cortex Analyst - structured TPO risk
    02_cortex_search_compliance/        # Cortex Search + AISQL on social posts
    03_counterparty_oversight_agent/    # Cortex Agent (centerpiece)
    04_cross_org_bridge/                # TPO performance + lock pull-through
    05_solution_center_marketplace/     # Snowflake share + simulated lender
    06_streamlit_dashboard/             # SiS counterparty risk dashboard
  docs/
    demo_runbook.md
    cortex_code_talktrack.md
    deploy_to_snowsight_workspaces.md
    reset_demo.sql
  tests/
    smoke_test.sql
    deploy_test.md
    defects.md
```

## Vignettes at a glance

| # | Deliverable | Snowflake objects |
|---|---|---|
| V1 | TPO Risk Semantic View | `AI.TPO_FACT`, `AI.TPO_RISK_SV` |
| V2 | Cortex Search + AISQL | `AI.COMPLIANCE_CSS`, `COMERGENCE.SOCIAL_FLAG` |
| V3 | Counterparty Oversight Agent | `AI.COUNTERPARTY_AGENT` (2 tools) |
| V4 | Cross-org Bridge | `SHARED.TPO_PERFORMANCE_V`, `TPO_SCORECARD_V` (SECURE) |
| V5 | Marketplace share + multi-tenant RAP | `OB_DEMO_TPO_SCORECARD_SHARE`, `LENDER_VIEWS.TPO_SCORECARD`, `SHARED.TPO_SCORECARD_RAP` |
| V6 | Streamlit dashboard | SiS app `OB_COMERGENCE_DASHBOARD` |

## Conventions

- All SQL is idempotent (`CREATE OR REPLACE` / `IF NOT EXISTS`).
- Demo state regenerates cleanly via [`docs/reset_demo.sql`](docs/reset_demo.sql).
- Every prompt contract follows a strict 5-block live-demo runbook
  (Setup / Prompt to paste / Expected output / Verify / Recovery).
- Snowflake gotchas surfaced during the first live deploy are codified
  in [`infrastructure/prompt-contract.md`](infrastructure/prompt-contract.md)
  and [`tests/defects.md`](tests/defects.md) so live regeneration won't
  reintroduce them.

## License

Internal Snowflake demo material. Not for distribution outside the
prospect engagement.
