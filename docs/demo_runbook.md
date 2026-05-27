# Optimal Blue / Comergence - 2-hour Technical Deep Dive Runbook

**Audience**: Shawnee (PM Data & Analytics, Comergence) + team
**Goal**: convert from Tableau-only / Azure SQL-only to Snowflake by
showing Cortex Code-built artifacts solving Comergence's daily problems
(and bridging to PPE / Capital Markets).

## Pre-flight (45 minutes before call)

- [ ] As `SYSADMIN`: run `docs/reset_demo.sql` if any prior demo state exists.
- [ ] As `SYSADMIN`: run `infrastructure/00_setup_db_roles_wh.sql`.
- [ ] As `OB_DEMO_RW`: run `infrastructure/01..03` synthetic-data scripts.
- [ ] **DO NOT** pre-run vignette SQL - those are generated live during the demo.
- [ ] EXCEPT V6: pre-deploy Streamlit `snow streamlit deploy ob_comergence_dashboard --replace`
      and confirm the SiS URL loads.
- [ ] In a SECOND Snowsight tab, log in as `OB_DEMO_LENDER` (for V5 role-switch).
- [ ] Snowsight Workspaces: confirm the Git pull is current; open `RUN.md`.
- [ ] Cortex Code panel: type `@infrastructure/prompt-contract.md` to confirm it resolves.

## Minute-by-minute (each vignette = generate + run + verify)

| Time | Block | Cortex Code feature | File generated live |
| --- | --- | --- | --- |
| 0:00 | Framing + meeting recap; open `RUN.md` in Workspaces | Plan mode review | - |
| 0:08 | Walk infra contract; SHOW the pre-built infra files | `@`-mention master contract | (DONE in pre-flight) |
| 0:18 | V1 generate + run + Cortex Analyst questions | `semantic-view` skill, `reflect_semantic_model` | `01_tpo_risk_semantic_view.sql` |
| 0:35 | V2 generate + run + search/AISQL preview | `search-optimization`, `document-intelligence` | `02_compliance_search_and_aisql.sql` |
| 0:55 | V3 generate + run + 5 agent prompts (centerpiece) | `cortex-agent` skill | `03_counterparty_oversight_agent.sql` |
| 1:15 | V4 generate + `sql-verify` subagent + run (the cross-org "aha") | `sql-author` + `sql-verify` | `04_tpo_performance_views.sql` |
| 1:30 | V5 generate + run producer; role-switch tab as `OB_DEMO_LENDER`; query consumer | `declarative-sharing` | `05_tpo_scorecard_share.sql` |
| 1:42 | V6 open SiS URL; Cortex Code explains a code block | `developing-with-streamlit-in-snowflake` | (pre-deployed) |
| 1:50 | V7 generate + run; assemble SI workspace; closing prompts | `cortex-agent` + SI | `07_tpo_performance_si_semantic_view.sql` |
| 1:55 | Recap + trial handoff: "clone the repo, mount as Workspace, rerun" | - | - |

## What Shawnee should walk away with

1. Plain-English answers to compliance & oversight questions in seconds.
2. One governed home for TPO + PPE data (no more FTP).
3. AI grounded in *her* docs, not the open internet.
4. A repeatable build pattern (prompt contracts) her team can adopt.
5. A clear path to Solution Center as a Marketplace data product.

## Recovery moves

- Live generation drifts? Open the pre-built `NN_*.sql` in the same
  vignette folder (the "REFERENCE / FALLBACK ONLY" file) and run it.
  ~30 seconds to recover.
- Cortex Search build slow? Continue with V3 talk-track while the index
  builds in the background; come back to query previews.
- Agent gives a weak answer? Re-prompt with exact text from
  `vignettes/03_counterparty_oversight_agent/demo_script.md`.
- SiS app fails to load? Run `streamlit run app.py` locally with
  `SNOWFLAKE_CONNECTION_NAME` set; same UI on localhost.

## Leave-behinds

- This entire workspace (zip or git push) shared with Shawnee.
- Screenshot of V5 role-switch (lender consumer view).
- Trial-instance worksheet preloaded with the master prompt contract.
