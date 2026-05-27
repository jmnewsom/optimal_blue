# Defect Log - Live Deploy Iteration 1

Captured during the end-to-end deployment against `WWC76537`. All
defects have been fixed in both the SQL files AND (where relevant) the
prompt-contract acceptance criteria so live regeneration won't reintroduce
them.

## DEFECT-01 - IDENTIFIER(CURRENT_USER()) doesn't compile
- File: `infrastructure/00_setup_db_roles_wh.sql`
- Step: STEP 2 (role grants to current user)
- Error: `syntax error line 1 at position 18 unexpected 'CURRENT_USER'`
- Root cause: `IDENTIFIER()` requires a string literal or session variable, not a function expression
- Fix: introduced session var `SET ob_demo_user = CURRENT_USER();` then `GRANT ROLE ... TO USER IDENTIFIER($ob_demo_user)`
- Re-test: pass

## DEFECT-02 - OB_DEMO_ADMIN lacks CREATE DATABASE
- File: `infrastructure/00_setup_db_roles_wh.sql`
- Step: STEP 3 (database creation)
- Error: `Insufficient privileges to operate on account 'WWC76537'. Your primary role OB_DEMO_ADMIN must have CREATE DATABASE granted on ACCOUNT`
- Root cause: account-level CREATE DATABASE is required; OB_DEMO_ADMIN is a non-default role
- Fix: SYSADMIN creates the DB and transfers ownership: `CREATE DATABASE` then `GRANT OWNERSHIP ON DATABASE ... TO ROLE OB_DEMO_ADMIN COPY CURRENT GRANTS`
- Re-test: pass

## DEFECT-03 - RANDOM(<column>) requires constant seed
- Files: `infrastructure/01_synthetic_comergence.sql`, `02_synthetic_ppe.sql`
- Step: synthetic data inserts
- Error: `argument 1 to function RANDOM needs to be constant, found 'SEED.N'`
- Root cause: Snowflake's `RANDOM()` accepts only constant seeds, not column references
- Fix: replaced every `RANDOM(<expr>)` with `RANDOM()` (synthetic data demo doesn't need run-to-run determinism)
- Re-test: pass

## DEFECT-04 - Correlated subquery picking from STATE/PRODUCT lookup
- Files: `01_synthetic_comergence.sql`, `02_synthetic_ppe.sql`
- Step: TPO, LOAN_OFFICER, NMLS_LICENSE, RATE_SHEET, LOCK, SOCIAL_POST inserts
- Error: `Unsupported subquery type cannot be evaluated`
- Root cause: `(SELECT col FROM table ORDER BY HASH(<outer_col>, ...) LIMIT 1)` is a non-trivial correlated scalar subquery
- Fix: replaced with a `numbered_states` / `numbered_products` CTE assigning row indices, then `JOIN ... ON idx = MOD(ABS(HASH(...)), N)`
- Re-test: pass

## DEFECT-05 - Semantic-view metric references column by aliased name
- File: `vignettes/01_tpo_risk_semantic_view/01_tpo_risk_semantic_view.sql`
- Error: `invalid identifier 'TPO_FACT.TPO_STATUS'` inside METRICS expressions
- Root cause: METRIC expressions must reference the underlying COLUMN name, not the dimension's renamed alias
- Fix: renamed the underlying column in `AI.TPO_FACT` from `status` -> `tpo_status` so dimension and metric expressions are consistent
- Re-test: pass

## DEFECT-06 - `tpo_status`/`status` reserved-ish behavior in semantic view
- File: `vignettes/01_tpo_risk_semantic_view/01_tpo_risk_semantic_view.sql`
- Error: `invalid identifier 'TPO_STATUS'` even when listed in DIMENSIONS
- Root cause: when the underlying column is `status` (a SQL reserved-ish word), aliasing to `tpo_status` did not resolve cleanly
- Fix: renamed the underlying column to `tpo_status` in `AI.TPO_FACT` (combined with DEFECT-05)
- Re-test: pass

## DEFECT-07 - AI_CLASSIFY returns empty labels for descriptive labels
- File: `vignettes/02_cortex_search_compliance/02_compliance_search_and_aisql.sql`
- Step: `SOCIAL_FLAG` materialization
- Error: every `compliance_risk` row was NULL
- Root cause: `AI_CLASSIFY(text, ['HIGH - likely violation', ...])` returned `{"labels":[]}` for descriptive labels containing hyphens / multi-word phrases
- Fix: simplified labels to `['HIGH','MEDIUM','LOW']`. Demo talk maps these to "likely violation / review needed / acceptable" verbally.
- Re-test: pass; distribution = {MEDIUM: 2491, LOW: 2008, HIGH: 501}

## DEFECT-08 - OB_DEMO_ADMIN lacks CREATE SHARE on account
- File: `infrastructure/00_setup_db_roles_wh.sql`
- Step: V5 producer
- Error: `Insufficient privileges to operate on account 'WWC76537'. Your primary role OB_DEMO_ADMIN must have CREATE SHARE granted on ACCOUNT`
- Root cause: CREATE SHARE is account-level
- Fix: added `USE ROLE ACCOUNTADMIN; GRANT CREATE SHARE ON ACCOUNT TO ROLE OB_DEMO_ADMIN;` in 00_setup
- Re-test: pass

## DEFECT-09 - non-secure VIEW cannot be granted to SHARE
- File: `vignettes/04_cross_org_bridge/04_tpo_performance_views.sql`
- Step: V5 producer GRANT SELECT to share
- Error: `Non-secure object can only be granted to shares with "secure_objects_only" property set to false`
- Root cause: `SHARED.TPO_SCORECARD_V` was a regular VIEW; modern SHAREs require SECURE objects
- Fix: changed `CREATE OR REPLACE VIEW SHARED.TPO_SCORECARD_V` -> `CREATE OR REPLACE SECURE VIEW SHARED.TPO_SCORECARD_V`
- Re-test: pass

## DEFECT-10 - secondary roles defeat lender denial
- Files: `vignettes/05_solution_center_marketplace/05_tpo_scorecard_share.sql`, `tests/smoke_test.sql`
- Step: V5 lender denial verification
- Error: `SELECT * FROM OPTIMAL_BLUE_DEMO.COMERGENCE.TPO LIMIT 1` SUCCEEDED as `OB_DEMO_LENDER` (it should fail)
- Root cause: Snowflake's default `secondary_roles = 'all'` lets the user's other roles satisfy authorization even after `USE ROLE OB_DEMO_LENDER`
- Fix: documented in V5 SQL + smoke_test that the lender-denial verification requires `USE SECONDARY ROLES NONE;` after `USE ROLE OB_DEMO_LENDER;`
- Re-test: pass; second SELECT now fails with `Schema 'OPTIMAL_BLUE_DEMO.COMERGENCE' does not exist or not authorized`

## DEFECT-11 - OB_DEMO_RW lacks CREATE ROW ACCESS POLICY on SHARED schema
- File: `infrastructure/00_setup_db_roles_wh.sql`
- Step: V5 RAP creation
- Error: `Insufficient privileges to operate on schema 'SHARED'. Your primary role OB_DEMO_RW must have CREATE ROW ACCESS POLICY granted on SCHEMA OPTIMAL_BLUE_DEMO.SHARED.`
- Root cause: SHARED schema grants list omitted `CREATE ROW ACCESS POLICY` (V5 redesign added a RAP)
- Fix: added `CREATE ROW ACCESS POLICY` to the SHARED schema grant block in 00_setup
- Re-test: pass

## Summary (after V5 redesign)
- 11 defects discovered total (10 initial deploy + 1 V5 multi-tenant redesign)
- All fixed in source files
- V5 redesign verified live: BIG persona sees 21,981 rows (min funded_volume_usd = $504,365), SMALL persona sees 456 rows (all CA), both denied on COMERGENCE.TPO source.
- Estimated total deploy time on Medium WH: ~6 minutes (most spent on 500K LOCK insert + AISQL on 5K social posts).
