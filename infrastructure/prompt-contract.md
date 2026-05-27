---
id: infrastructure
inherits: null
role: OB_DEMO_ADMIN
warehouse: OB_DEMO_WH
database: OPTIMAL_BLUE_DEMO
schemas: [COMERGENCE, PPE, SHARED, AI, STAGES]
output_files:
  - 00_setup_db_roles_wh.sql
  - 01_synthetic_comergence.sql
  - 02_synthetic_ppe.sql
  - 03_load_unstructured.sql
  - README.md
est_runtime_min: 12
cortex_code_skills: [sql-author, snowpark-python]
---

# Master Prompt Contract - Optimal Blue / Comergence Demo Infrastructure

This is the **master contract**. Every vignette contract begins with
`inherits: ../../infrastructure/prompt-contract.md` and may override any
field below. Conventions defined here are binding for the entire demo.

## Goal

Stand up a clean, idempotent Snowflake foundation that supports all seven
vignettes for the Optimal Blue / Comergence technical deep dive: a single
database, four functional schemas, three demo warehouses, role-based access
control, internal stages for unstructured assets, and synthetic data scaled
to mirror Comergence's real network (~22K TPOs, ~100K LOs, ~250K audit
records, ~500K lock events, ~100 guideline PDFs, ~50K social posts).

## Business context (Comergence + cross-org bridge)

- **Comergence** is Optimal Blue's compliance & counterparty oversight
  product: third-party originator (TPO) due diligence, NMLS license
  monitoring, social media compliance, audit / remediation, and the
  Solution Center partner marketplace.
- **Cross-org bridge**: the same lender + investor entities live inside
  Optimal Blue's PPE (pricing & lock) world. Co-locating both data
  domains in one governed Snowflake foundation is the strategic unlock.

## Inputs

- This contract.
- Plan documents in `../plan/` for narrative context.
- No external data sources; synthetic generators are deterministic
  (seeded) so the demo resets cleanly.

## Deliverables

| File | Purpose |
| --- | --- |
| `00_setup_db_roles_wh.sql` | DB, schemas, three warehouses, four roles, grants, stages |
| `01_synthetic_comergence.sql` | TPO, LOAN_OFFICER, NMLS_LICENSE, AUDIT_FINDING, EXCEPTION, ONBOARDING_EVENT, SOCIAL_POST tables + seed data |
| `02_synthetic_ppe.sql` | RATE_SHEET, LOCK, FALLOUT, INVESTOR, PRODUCT tables + seed data |
| `03_load_unstructured.sql` | Internal stage `STAGES.COMPLIANCE_DOCS`, synthetic PDF text via `AI_PARSE_DOCUMENT` simulation, base text-chunk table |
| `README.md` | End-to-end run order + reset instructions |

Snowflake objects (FQNs):

- `OPTIMAL_BLUE_DEMO`
- `OPTIMAL_BLUE_DEMO.COMERGENCE.*`, `.PPE.*`, `.SHARED.*`, `.AI.*`, `.STAGES.*`
- Warehouses: `OB_DEMO_WH`, `OB_DEMO_AI_WH`, `OB_DEMO_LENDER_WH`
- Roles: `OB_DEMO_ADMIN`, `OB_DEMO_RW`, `OB_DEMO_RO`, `OB_DEMO_LENDER`

## Acceptance criteria

1. Re-running every script top-to-bottom on a clean account produces an
   identical result (idempotent: `CREATE OR REPLACE` everywhere except
   warehouses, which use `CREATE WAREHOUSE IF NOT EXISTS`).
2. `OB_DEMO_RW` can `SELECT * FROM` every Comergence and PPE table.
3. `OB_DEMO_LENDER` cannot see source tables. It can only see objects
   inside `OB_LENDER_CONSUMER` once the V5 share is created.
4. Synthetic row counts (medium scale, ~10% tolerance):
   - `COMERGENCE.TPO`            ~ 22,000
   - `COMERGENCE.LOAN_OFFICER`   ~ 100,000
   - `COMERGENCE.AUDIT_FINDING`  ~ 250,000
   - `COMERGENCE.SOCIAL_POST`    ~  50,000
   - `PPE.LOCK`                  ~ 500,000
5. End-to-end runtime <= 15 minutes on `OB_DEMO_AI_WH` (Medium).

## SQL conventions (binding for all vignettes)

- Every script begins with:
  ```sql
  USE ROLE  <role>;
  USE WAREHOUSE <warehouse>;
  USE DATABASE OPTIMAL_BLUE_DEMO;
  USE SCHEMA <schema>;
  ```
- Section headers use this exact pattern (so Cortex Code can navigate them):
  ```sql
  -- =====================================================================
  -- STEP N: <imperative verb phrase>
  -- =====================================================================
  ```
- All DDL is `CREATE OR REPLACE` (or `IF NOT EXISTS` for warehouses /
  databases / roles).
- All identifiers are UPPERCASE, snake_case for column names.
- Numeric IDs use `NUMBER(38,0)`; surrogate keys generated via `SEQ8()`
  inside `TABLE(GENERATOR(...))` only, or via `ROW_NUMBER()` in JOINs.
- Timestamps use `TIMESTAMP_NTZ`.

## Snowflake gotchas - learned the hard way (binding)

These are real defects we hit during the first live deploy. Codify them
so live regeneration doesn't reintroduce them:

1. `RANDOM(<column>)` is invalid - `RANDOM()` requires a constant seed.
   Use `RANDOM()` (no arg) for synthetic data; demo determinism is not a
   requirement.
2. `(SELECT col FROM lookup ORDER BY HASH(<outer_col>, ...) LIMIT 1)`
   is an unsupported correlated subquery. Use a `numbered_<lookup>` CTE
   with `ROW_NUMBER() OVER (...)` and JOIN `ON idx = MOD(ABS(HASH(...)), N)`.
3. `IDENTIFIER(CURRENT_USER())` does NOT compile. `IDENTIFIER()` needs a
   string literal or session variable. Pattern:
   `SET ob_demo_user = CURRENT_USER(); GRANT ROLE x TO USER IDENTIFIER($ob_demo_user);`
4. `OB_DEMO_ADMIN` cannot `CREATE DATABASE` directly - SYSADMIN must
   create the DB and `GRANT OWNERSHIP ON DATABASE ... TO ROLE OB_DEMO_ADMIN COPY CURRENT GRANTS`.
5. `CREATE SHARE` is account-level - `OB_DEMO_ADMIN` needs an explicit
   `GRANT CREATE SHARE ON ACCOUNT` (granted by ACCOUNTADMIN).
6. Any view added to a SHARE must be `CREATE OR REPLACE SECURE VIEW`,
   not a regular VIEW. Apply this to `SHARED.TPO_SCORECARD_V`.
7. In `CREATE SEMANTIC VIEW`, METRIC expressions reference the underlying
   COLUMN name, NOT the dimension's renamed alias. To avoid clashes
   (e.g. `status` -> `tpo_status`) rename the underlying column at the
   fact-view layer so the dimension and metric expressions stay aligned.
8. `AI_CLASSIFY(text, [labels])` returns empty `labels` arrays when label
   strings contain hyphens or descriptive multi-word phrases. Keep labels
   short (`'HIGH','MEDIUM','LOW'`) and explain the meaning in the demo
   verbally rather than embedding it in the label string.
9. To demonstrate role-based denial (V5 lender), the user MUST run
   `USE SECONDARY ROLES NONE;` after `USE ROLE OB_DEMO_LENDER_BIG;` (or
   `_SMALL`) - Snowflake's default `secondary_roles = 'all'` causes the
   user's other roles to satisfy authorization and the denial won't fire.
10. `claude-3-5-sonnet` is NOT available as an AI_COMPLETE model in
    many Snowflake regions (confirmed unavailable on `WWC76537`). Use
    `claude-4-sonnet` for any `SNOWFLAKE.CORTEX.AI_COMPLETE` call.
    Verified working pattern:
    `SELECT SNOWFLAKE.CORTEX.AI_COMPLETE('claude-4-sonnet', '<prompt>')`.
11. `TABLE(GENERATOR(ROWCOUNT => N))` cross-joined with `SEQ4()` in
    a WHERE clause does NOT produce one row per generated value -
    `SEQ4()` is bound to the generator's row context, so referencing
    it outside a SELECT against the generator returns 0 rows. Don't
    use this pattern for "next 30 days" series; use a direct
    `WHERE expires_at BETWEEN CURRENT_DATE() AND DATEADD('day',30,...)
    GROUP BY expires_at` instead.
12. `CREATE OR REPLACE ROW ACCESS POLICY` fails with "cannot be
    dropped/replaced as it is associated with one or more entities"
    when the policy is already attached to a view. Idempotent pattern:
    `ALTER VIEW IF EXISTS <view> DROP ALL ROW ACCESS POLICIES;` then
    `CREATE OR REPLACE ROW ACCESS POLICY ...;` then re-`ALTER VIEW ...
    ADD ROW ACCESS POLICY ... ON (...);`.
13. Snowflake agent spec (`CREATE AGENT ... FROM SPECIFICATION`)
    rejects nested `orchestration.instructions`. Tool-routing rules
    must live inside `instructions.response`. The `orchestration`
    object stays as `{}`.

## Comment style (binding)

- Every `CREATE OR REPLACE <object>` is preceded by a 2-4 line block
  comment that:
  1. Names the **business concept** (one sentence in plain English).
  2. Maps the object back to a bullet from the Goal / Acceptance Criteria.
  3. Calls out any **demo talking point** the SE should mention here.
- Inline comments only when an expression is non-obvious (e.g., a
  weighted random draw, a date calculation, a join key choice).

Example:

```sql
-- ---------------------------------------------------------------------
-- TPO master entity. One row per third-party originator on Comergence.
-- Goal: foundation for V1 (semantic view) and V4 (cross-org bridge).
-- Demo talk: "this is what 22,000 originators looks like in one place."
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE COMERGENCE.TPO ( ... );
```

## Cortex Code talk track (live demo - 5-block runbook)

This is the canonical pattern every vignette inherits.

### 1. Setup
- Active role: `OB_DEMO_ADMIN`
- Active warehouse: `OB_DEMO_WH`
- Snowsight: open a fresh worksheet, set role/warehouse/database
- Snowsight Workspaces: this contract should be open in the left rail;
  Cortex Code panel open on the right

### 2. Prompt to paste verbatim
> @infrastructure/prompt-contract.md
> Generate `00_setup_db_roles_wh.sql` exactly per this contract into
> a Snowsight worksheet. Idempotent, three warehouses, four roles,
> all the section headers from the SQL conventions block. Show me
> the SQL before I run it.

Repeat for `01_synthetic_comergence.sql`, `02_synthetic_ppe.sql`,
`03_load_unstructured.sql`.

### 3. Expected output ("good" looks like)
- `00_setup_db_roles_wh.sql`: ~120 lines, ends with SHOW SCHEMAS / SHOW WAREHOUSES
- `01_synthetic_comergence.sql`: ~200 lines, ends with row-count UNION query
- `02_synthetic_ppe.sql`: ~80 lines, ends with row-count UNION query
- `03_load_unstructured.sql`: ~80 lines, ends with row-count of doc tables
- Every CREATE preceded by 2-4 line block comment per Comment Style above

### 4. Verify after running
```sql
USE ROLE OB_DEMO_RW;
SELECT 'TPO' AS tbl, COUNT(*) FROM OPTIMAL_BLUE_DEMO.COMERGENCE.TPO
UNION ALL SELECT 'LOCK',        COUNT(*) FROM OPTIMAL_BLUE_DEMO.PPE.LOCK
UNION ALL SELECT 'SOCIAL_POST', COUNT(*) FROM OPTIMAL_BLUE_DEMO.COMERGENCE.SOCIAL_POST;
```
Counts within +/-10% of acceptance-criteria targets.

### 5. Recovery move
If live generation drifts on stage, open the corresponding pre-built
file in this folder (`00_setup_db_roles_wh.sql`, etc.) and run that
instead. Same outcome, ~30 seconds to recover.

## Verification

```sql
-- after running 00 + 01 + 02 + 03
USE ROLE OB_DEMO_RW;
SELECT 'TPO'              AS table_name, COUNT(*) AS rows FROM COMERGENCE.TPO
UNION ALL SELECT 'LOAN_OFFICER',   COUNT(*) FROM COMERGENCE.LOAN_OFFICER
UNION ALL SELECT 'AUDIT_FINDING',  COUNT(*) FROM COMERGENCE.AUDIT_FINDING
UNION ALL SELECT 'SOCIAL_POST',    COUNT(*) FROM COMERGENCE.SOCIAL_POST
UNION ALL SELECT 'LOCK',           COUNT(*) FROM PPE.LOCK
UNION ALL SELECT 'RATE_SHEET',     COUNT(*) FROM PPE.RATE_SHEET;
```

Counts should match the acceptance-criteria targets (+/- 10%).

## Reset

Run `docs/reset_demo.sql` to drop the database + warehouses + roles in
the correct dependency order.
