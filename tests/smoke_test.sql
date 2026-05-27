-- =====================================================================
-- tests/smoke_test.sql
-- Read-only end-to-end assertions for the Optimal Blue / Comergence
-- demo. Run as OB_DEMO_RW after the full deploy. Then run the
-- "two-role contrast" block at the bottom by switching to OB_DEMO_LENDER_BIG and OB_DEMO_LENDER_SMALL.
--
-- Demo passes when:
--   - All counts and SHOW results return non-empty
--   - The lender SELECT against COMERGENCE.TPO is denied
-- =====================================================================

USE ROLE OB_DEMO_RW;
USE WAREHOUSE OB_DEMO_WH;
USE DATABASE OPTIMAL_BLUE_DEMO;

-- ---------------------------------------------------------------------
-- INFRASTRUCTURE: row counts (medium scale targets, +/- 10%)
-- ---------------------------------------------------------------------
SELECT 'TPO'                  AS tbl, COUNT(*) AS n FROM COMERGENCE.TPO
UNION ALL SELECT 'LOAN_OFFICER',     COUNT(*) FROM COMERGENCE.LOAN_OFFICER
UNION ALL SELECT 'NMLS_LICENSE',     COUNT(*) FROM COMERGENCE.NMLS_LICENSE
UNION ALL SELECT 'AUDIT_FINDING',    COUNT(*) FROM COMERGENCE.AUDIT_FINDING
UNION ALL SELECT 'EXCEPTION',        COUNT(*) FROM COMERGENCE.EXCEPTION
UNION ALL SELECT 'ONBOARDING_EVENT', COUNT(*) FROM COMERGENCE.ONBOARDING_EVENT
UNION ALL SELECT 'SOCIAL_POST',      COUNT(*) FROM COMERGENCE.SOCIAL_POST
UNION ALL SELECT 'COMPLIANCE_DOCUMENT',  COUNT(*) FROM COMERGENCE.COMPLIANCE_DOCUMENT
UNION ALL SELECT 'COMPLIANCE_DOC_CHUNK', COUNT(*) FROM COMERGENCE.COMPLIANCE_DOC_CHUNK
UNION ALL SELECT 'PRODUCT',          COUNT(*) FROM PPE.PRODUCT
UNION ALL SELECT 'RATE_SHEET',       COUNT(*) FROM PPE.RATE_SHEET
UNION ALL SELECT 'LOCK',             COUNT(*) FROM PPE.LOCK;

-- ---------------------------------------------------------------------
-- V1: SEMANTIC VIEW smoke
-- ---------------------------------------------------------------------
SELECT * FROM SEMANTIC_VIEW(
    OPTIMAL_BLUE_DEMO.AI.TPO_RISK_SV
    DIMENSIONS region, risk_tier
    METRICS    tpo_count, open_findings, licenses_expiring_30d
)
ORDER BY region, risk_tier;

-- ---------------------------------------------------------------------
-- V2: Cortex Search service + AISQL flags
-- ---------------------------------------------------------------------
SHOW CORTEX SEARCH SERVICES IN SCHEMA AI;

SELECT PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'OPTIMAL_BLUE_DEMO.AI.COMPLIANCE_CSS',
        '{"query": "FHA overlay credit score requirements", "limit": 3}'
    )
) AS sample_search_result;

SELECT compliance_risk, COUNT(*) AS n
FROM COMERGENCE.SOCIAL_FLAG
GROUP BY compliance_risk
ORDER BY 2 DESC;

-- ---------------------------------------------------------------------
-- V3: Agent presence
-- ---------------------------------------------------------------------
SHOW AGENTS IN SCHEMA AI;
DESCRIBE AGENT AI.COUNTERPARTY_AGENT;

-- ---------------------------------------------------------------------
-- V4: Cross-org bridge (no fanout)
-- ---------------------------------------------------------------------
SELECT 'tpo_count_match' AS check_name,
       (SELECT COUNT(*) FROM COMERGENCE.TPO)            AS expected,
       (SELECT COUNT(*) FROM SHARED.TPO_PERFORMANCE_V)  AS actual;

SELECT MIN(compliance_score)  AS min_score,  MAX(compliance_score)  AS max_score,
       MIN(pull_through_pct)  AS min_pt_pct, MAX(pull_through_pct)  AS max_pt_pct
FROM SHARED.TPO_PERFORMANCE_V;

-- ---------------------------------------------------------------------
-- V5: producer share + simulated consumer schema + RAP + 2 lender roles
-- ---------------------------------------------------------------------
USE ROLE OB_DEMO_ADMIN;
SHOW SHARES LIKE 'OB_DEMO_TPO_SCORECARD_SHARE';
DESCRIBE SHARE OB_DEMO_TPO_SCORECARD_SHARE;
SHOW SCHEMAS LIKE 'LENDER_VIEWS' IN DATABASE OPTIMAL_BLUE_DEMO;
SHOW ROW ACCESS POLICIES LIKE 'TPO_SCORECARD_RAP' IN SCHEMA OPTIMAL_BLUE_DEMO.SHARED;

-- Admin sees full set (RAP returns TRUE for OB_DEMO_ADMIN):
SELECT COUNT(*) AS admin_rows FROM OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD;  -- expect: 22000

-- =====================================================================
-- TWO-ROLE CONTRAST (the V5 punchline)
-- Run each block in a separate Snowsight tab. USE SECONDARY ROLES NONE
-- is REQUIRED so other roles don't leak through and defeat the RAP.
-- =====================================================================
-- Tab 1 (BIG):
-- USE ROLE OB_DEMO_LENDER_BIG;
-- USE SECONDARY ROLES NONE;
-- USE WAREHOUSE OB_DEMO_LENDER_WH;
-- SELECT COUNT(*)               FROM OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD;  -- ~11K
-- SELECT MIN(funded_volume_usd) FROM OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD;  -- > 500000
-- SELECT * FROM OPTIMAL_BLUE_DEMO.COMERGENCE.TPO LIMIT 1;                           -- denied
--
-- Tab 2 (SMALL):
-- USE ROLE OB_DEMO_LENDER_SMALL;
-- USE SECONDARY ROLES NONE;
-- USE WAREHOUSE OB_DEMO_LENDER_WH;
-- SELECT COUNT(*)            FROM OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD;     -- ~432
-- SELECT DISTINCT state_code FROM OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD;     -- only 'CA'
-- SELECT * FROM OPTIMAL_BLUE_DEMO.COMERGENCE.TPO LIMIT 1;                            -- denied
-- =====================================================================
