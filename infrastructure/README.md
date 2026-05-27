# Infrastructure - Optimal Blue / Comergence Demo

End-to-end foundation that supports all 7 vignettes. Generated from
`prompt-contract.md` via Cortex Code.

## Run order

Execute as the active Snowflake user with rights to create roles/WHs:

```sql
-- in Snowsight worksheet (or via snowflake_sql_execute)
!source 00_setup_db_roles_wh.sql
!source 01_synthetic_comergence.sql
!source 02_synthetic_ppe.sql
!source 03_load_unstructured.sql
```

Or, from the Cortex Code CLI:

```bash
snow sql -f infrastructure/00_setup_db_roles_wh.sql
snow sql -f infrastructure/01_synthetic_comergence.sql
snow sql -f infrastructure/02_synthetic_ppe.sql
snow sql -f infrastructure/03_load_unstructured.sql
```

## What gets built

| Object | Schema | Purpose |
| --- | --- | --- |
| `OPTIMAL_BLUE_DEMO`            | (DB)        | Demo database |
| `OB_DEMO_WH`                   | (WH)        | XS - SQL/UI workloads |
| `OB_DEMO_AI_WH`                | (WH)        | M  - Cortex / AISQL / Search |
| `OB_DEMO_LENDER_WH`            | (WH)        | XS - Marketplace consumer (V5) |
| `COMERGENCE.TPO`, `LOAN_OFFICER`, `NMLS_LICENSE`, `AUDIT_FINDING`, `EXCEPTION`, `ONBOARDING_EVENT`, `SOCIAL_POST`, `COMPLIANCE_DOCUMENT`, `COMPLIANCE_DOC_CHUNK` | COMERGENCE | TPO oversight + content |
| `PPE.PRODUCT`, `RATE_SHEET`, `LOCK` | PPE | Pricing + lock pipeline |
| `STAGES.COMPLIANCE_DOCS`       | STAGES      | Internal stage for PDFs |

## Reset

```sql
USE ROLE SYSADMIN;
DROP DATABASE IF EXISTS OPTIMAL_BLUE_DEMO    CASCADE;
DROP DATABASE IF EXISTS OB_LENDER_CONSUMER   CASCADE;
DROP WAREHOUSE IF EXISTS OB_DEMO_WH;
DROP WAREHOUSE IF EXISTS OB_DEMO_AI_WH;
DROP WAREHOUSE IF EXISTS OB_DEMO_LENDER_WH;
DROP ROLE IF EXISTS OB_DEMO_LENDER;
DROP ROLE IF EXISTS OB_DEMO_RO;
DROP ROLE IF EXISTS OB_DEMO_RW;
DROP ROLE IF EXISTS OB_DEMO_ADMIN;
```
(see `docs/reset_demo.sql` for the canonical version)
