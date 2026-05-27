---
id: 05_solution_center_marketplace
inherits: ../../infrastructure/prompt-contract.md
depends_on: [04_cross_org_bridge]
role: OB_DEMO_ADMIN
warehouse: OB_DEMO_WH
database: OPTIMAL_BLUE_DEMO
schema: SHARED
output_files: [05_tpo_scorecard_share.sql]
est_runtime_min: 3
cortex_code_skills: [declarative-sharing, internal-marketplace-org-listing]
---

# V5 - Solution Center as a Snowflake Data-Product Share (multi-tenant)

## Goal
Mirror Comergence's Solution Center value-prop on Snowflake with a
multi-tenant data-sharing pattern:

1. **Producer**: real Snowflake share `OB_DEMO_TPO_SCORECARD_SHARE` on
   the SECURE `SHARED.TPO_SCORECARD_V`. This is the object Optimal Blue
   would grant to lender accounts in production.
2. **Consumer simulation (in-account)**: `LENDER_VIEWS.TPO_SCORECARD`
   view, protected by a **row access policy** that filters rows based
   on `CURRENT_ROLE()`.
3. **Two lender personas, one product**:
   - `OB_DEMO_LENDER_BIG` -> rows where funded_volume_usd > $500K
   - `OB_DEMO_LENDER_SMALL` -> rows where state_code = 'CA'

Same producer view. Same governed share. Same data product contract.
Two lender personas see materially different rows because of one
row-access policy.

## Business context
This is the network-effects pitch for Optimal Blue. Solution Center
already runs as a partner marketplace; on Snowflake it becomes a
multi-tenant data product where one definition serves N consumers
without ever shipping a file. The "no FTP, no batch refresh" message
that Shawnee asked about is operationalized here.

## Inputs
- `OPTIMAL_BLUE_DEMO.SHARED.TPO_SCORECARD_V` (SECURE view from V4)
- Lender roles: `OB_DEMO_LENDER_BIG`, `OB_DEMO_LENDER_SMALL` (from 00_setup)

## Deliverables
- `OB_DEMO_TPO_SCORECARD_SHARE` (Snowflake share, producer)
- `OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD` (consumer-facing view)
- `OPTIMAL_BLUE_DEMO.SHARED.TPO_SCORECARD_RAP` (row access policy)
- Grants to both lender roles

## Acceptance criteria
- Provider side: 1 share, 1 RAP, 1 LENDER_VIEWS schema with 1 view.
- `OB_DEMO_LENDER_BIG` (with `USE SECONDARY ROLES NONE`):
  - SELECT against `LENDER_VIEWS.TPO_SCORECARD` returns > 0 rows
  - `MIN(funded_volume_usd)` > 500,000
  - SELECT against `COMERGENCE.TPO` denied
- `OB_DEMO_LENDER_SMALL` (with `USE SECONDARY ROLES NONE`):
  - SELECT against `LENDER_VIEWS.TPO_SCORECARD` returns > 0 rows
  - `DISTINCT state_code` returns only `{'CA'}`
  - SELECT against `COMERGENCE.TPO` denied
- BIG row count > SMALL row count > 0 (proves different slices).

## Cortex Code talk track (live demo - 5-block runbook)

### 1. Setup
- Active role: `OB_DEMO_ADMIN` (CREATE SHARE granted from 00_setup)
- Active warehouse: `OB_DEMO_WH`
- DB=OPTIMAL_BLUE_DEMO
- V4 must already exist (provides SHARED.TPO_SCORECARD_V as SECURE view)
- Open TWO additional Snowsight tabs - one logged in as
  `OB_DEMO_LENDER_BIG`, one as `OB_DEMO_LENDER_SMALL`

### 2. Prompt to paste verbatim
> @vignettes/05_solution_center_marketplace/prompt-contract.md
> Use the `declarative-sharing` skill. Generate the SQL exactly per
> this contract into a file named `05_tpo_scorecard_share.sql`. Include:
> the producer share, LENDER_VIEWS schema + view, ROW ACCESS POLICY
> SHARED.TPO_SCORECARD_RAP keyed off CURRENT_ROLE(), ALTER VIEW to
> attach the policy, and grants to both OB_DEMO_LENDER_BIG and
> OB_DEMO_LENDER_SMALL roles.

### 3. Expected output
- File `05_tpo_scorecard_share.sql`, ~90 lines
- `CREATE OR REPLACE SHARE OB_DEMO_TPO_SCORECARD_SHARE` + grants on share
- `CREATE SCHEMA OPTIMAL_BLUE_DEMO.LENDER_VIEWS` (idempotent)
- `CREATE OR REPLACE VIEW OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD`
- `CREATE OR REPLACE ROW ACCESS POLICY SHARED.TPO_SCORECARD_RAP AS (state_code VARCHAR, funded_volume_usd NUMBER) RETURNS BOOLEAN -> CASE ...`
- `ALTER VIEW ... ADD ROW ACCESS POLICY SHARED.TPO_SCORECARD_RAP ON (state_code, funded_volume_usd)`
- Grants for BOTH `OB_DEMO_LENDER_BIG` and `OB_DEMO_LENDER_SMALL`
- IMPORTANT: do NOT use `CREATE DATABASE FROM SHARE` (Snowflake forbids
  same-account consumption)

### 4. Verify after running
In Snowsight tab #1 as `OB_DEMO_LENDER_BIG`:
```sql
USE ROLE OB_DEMO_LENDER_BIG;
USE SECONDARY ROLES NONE;
USE WAREHOUSE OB_DEMO_LENDER_WH;
SELECT COUNT(*)               FROM OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD;  -- ~11K
SELECT MIN(funded_volume_usd) FROM OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD;  -- > 500000
SELECT * FROM OPTIMAL_BLUE_DEMO.COMERGENCE.TPO LIMIT 1;                           -- denied
```
In Snowsight tab #2 as `OB_DEMO_LENDER_SMALL`:
```sql
USE ROLE OB_DEMO_LENDER_SMALL;
USE SECONDARY ROLES NONE;
USE WAREHOUSE OB_DEMO_LENDER_WH;
SELECT COUNT(*)            FROM OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD;     -- ~432
SELECT DISTINCT state_code FROM OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD;     -- only 'CA'
SELECT * FROM OPTIMAL_BLUE_DEMO.COMERGENCE.TPO LIMIT 1;                            -- denied
```

The two count contrast is the demo punchline.

After the verification, narrate: "If I went back to the producer side
and changed a TPO's compliance_score right now, both lenders would see
it on their very next query - no FTP, no batch refresh, no overnight
file. That's the FTP-elimination story your team is asking for."

### 5. Recovery move
Open `05_tpo_scorecard_share.sql` in this folder and run it. Then
manually `USE ROLE` switch in Snowsight to verify both lender slices.
