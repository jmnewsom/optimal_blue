---
id: 05_solution_center_marketplace
inherits: ../../infrastructure/prompt-contract.md
depends_on: [04_cross_org_bridge]
role: OB_DEMO_ADMIN
warehouse: OB_DEMO_WH
database: OPTIMAL_BLUE_DEMO
schema: SHARED
output_files: [05_tpo_scorecard_share.sql, listing_manifest.yaml]
est_runtime_min: 3
cortex_code_skills: [declarative-sharing, internal-marketplace-org-listing]
---

# V5 - Solution Center as Snowflake Marketplace / Data Share

## Goal
Mirror Comergence's Solution Center value-prop on Snowflake:
1. **Producer** side: real Snowflake share `OB_DEMO_TPO_SCORECARD_SHARE`
   on `SHARED.TPO_SCORECARD_V`. This is the object Optimal Blue would
   grant to lender accounts in production.
2. **Consumer** simulation: in-account `LENDER_VIEWS` schema with a
   single SELECT-only view granted to `OB_DEMO_LENDER`. Snowflake does
   NOT permit consuming a share inside the same account, so we simulate
   the lender's surface with a dedicated schema + view. The role-switch
   demo moment is preserved.
3. Scaffold a Marketplace **listing manifest** to show the path from
   internal share -> Marketplace data product.

## Business context
Comergence already runs Solution Center as a partner marketplace.
Snowflake makes that a *governed, monetizable data product* across
accounts. This is the data-product monetization pillar from the
Optimal Blue strategy doc.

## Deliverables
- `OB_DEMO_TPO_SCORECARD_SHARE` (Snowflake share, producer)
- `OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD` (simulated consumer view)
- `vignettes/05_solution_center_marketplace/listing_manifest.yaml`

## Acceptance criteria
- After running, `OB_DEMO_LENDER` can `SELECT * FROM
  OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD` but CANNOT see source tables.
- Producer share lists exactly one view (the scorecard).
- `LENDER_VIEWS` schema contains exactly one view.

## Cortex Code talk track (live demo - 5-block runbook)

### 1. Setup
- Active role: `OB_DEMO_ADMIN` (need rights to CREATE SHARE / DATABASE FROM SHARE)
- Active warehouse: `OB_DEMO_WH`
- DB=OPTIMAL_BLUE_DEMO
- V4 must already exist (provides SHARED.TPO_SCORECARD_V)
- IMPORTANT: open a SECOND Snowsight tab logged in as `OB_DEMO_LENDER`
  before running the consumer-side SELECTs

### 2. Prompt to paste verbatim
> @vignettes/05_solution_center_marketplace/prompt-contract.md
> Use the `declarative-sharing` skill. Generate the SQL exactly per
> this contract into a file named `05_tpo_scorecard_share.sql`. Create
> OB_DEMO_TPO_SCORECARD_SHARE granting only SHARED.TPO_SCORECARD_V,
> then create OB_LENDER_CONSUMER FROM SHARE in this account, then
> grant IMPORTED PRIVILEGES + warehouse usage to OB_DEMO_LENDER.

### 3. Expected output
- File `05_tpo_scorecard_share.sql`, ~60 lines
- `CREATE OR REPLACE SHARE OB_DEMO_TPO_SCORECARD_SHARE` + grants on the share
- `CREATE SCHEMA OPTIMAL_BLUE_DEMO.LENDER_VIEWS`
- `CREATE OR REPLACE VIEW OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD`
- Grants to `OB_DEMO_LENDER`: USAGE on DB + schema, SELECT on the view, USAGE on `OB_DEMO_LENDER_WH`
- Closing `SHOW SHARES` / `DESCRIBE SHARE` / `SHOW SCHEMAS` smoke tests
- IMPORTANT: do NOT use `CREATE DATABASE FROM SHARE` (Snowflake forbids same-account consumption)

### 4. Verify after running
In the second Snowsight tab as `OB_DEMO_LENDER`:
```sql
USE ROLE OB_DEMO_LENDER;
USE WAREHOUSE OB_DEMO_LENDER_WH;
SELECT COUNT(*) FROM OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD;  -- ~22000
SELECT * FROM OPTIMAL_BLUE_DEMO.COMERGENCE.TPO LIMIT 1;             -- denied
```
The denial is the demo's punchline: governance kept source tables hidden.

### 5. Recovery move
Open `05_tpo_scorecard_share.sql` in this folder and run it.
