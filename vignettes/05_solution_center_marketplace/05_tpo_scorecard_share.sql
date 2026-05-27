-- *** REFERENCE / FALLBACK ONLY ***
-- Primary demo path: live-generate this SQL from prompt-contract.md in
-- Cortex Code (Snowsight Workspaces), then run that output. This file
-- exists so we can recover quickly if live generation drifts on stage.
-- =====================================================================
-- V5: Solution Center as a Snowflake Data-Product Share (multi-tenant)
--
-- Generated from vignettes/05_solution_center_marketplace/prompt-contract.md
-- Run as: OB_DEMO_ADMIN @ OB_DEMO_WH
--
-- Three deliverables:
--   1. PRODUCER share OB_DEMO_TPO_SCORECARD_SHARE on the SECURE
--      SHARED.TPO_SCORECARD_V (the object OB would publish to lender
--      accounts in production).
--   2. ROW ACCESS POLICY SHARED.TPO_SCORECARD_RAP attached to the
--      consumer-facing LENDER_VIEWS.TPO_SCORECARD. Filters rows by
--      CURRENT_ROLE() so two lender personas see different slices of
--      the same view.
--   3. Two lender roles consuming the same view:
--        - OB_DEMO_LENDER_BIG   -> rows with funded_volume_usd > $500K
--        - OB_DEMO_LENDER_SMALL -> rows where state_code = 'CA'
--
-- Snowflake does NOT permit same-account share consumption; the lender
-- experience is simulated via LENDER_VIEWS + RAP. The role-switch demo
-- moment (BIG vs SMALL counts) is the network-effects punchline.
--
-- Demo talk: "Same producer view. Same governed share. Same data product.
-- But two lender personas see materially different slices because of one
-- row-access policy. Solution Center on Snowflake scales like this -
-- one product, N tenants, zero file copies."
-- =====================================================================

USE ROLE OB_DEMO_ADMIN;
USE WAREHOUSE OB_DEMO_WH;
USE DATABASE OPTIMAL_BLUE_DEMO;

-- =====================================================================
-- STEP 1: PRODUCER - real Snowflake share on the SECURE scorecard view
-- This is the object that would be granted to lender accounts in prod.
-- =====================================================================

CREATE OR REPLACE SHARE OB_DEMO_TPO_SCORECARD_SHARE
    COMMENT = 'Optimal Blue / Comergence TPO performance + compliance scorecard - lender-facing data product';

GRANT USAGE  ON DATABASE OPTIMAL_BLUE_DEMO        TO SHARE OB_DEMO_TPO_SCORECARD_SHARE;
GRANT USAGE  ON SCHEMA   OPTIMAL_BLUE_DEMO.SHARED TO SHARE OB_DEMO_TPO_SCORECARD_SHARE;
GRANT SELECT ON VIEW     OPTIMAL_BLUE_DEMO.SHARED.TPO_SCORECARD_V
    TO SHARE OB_DEMO_TPO_SCORECARD_SHARE;

-- =====================================================================
-- STEP 2: CONSUMER simulation - LENDER_VIEWS schema + view
-- Same view name a real consumer would see; RAP attached in STEP 3.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS OPTIMAL_BLUE_DEMO.LENDER_VIEWS
    COMMENT = 'Simulated lender Marketplace consumer surface (V5)';

CREATE OR REPLACE VIEW OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD AS
    SELECT * FROM OPTIMAL_BLUE_DEMO.SHARED.TPO_SCORECARD_V;

-- =====================================================================
-- STEP 3: ROW ACCESS POLICY - one product, N tenants
-- Filter logic keys off CURRENT_ROLE() so any number of lender personas
-- can be onboarded with one ALTER + one GRANT.
-- =====================================================================

USE SCHEMA SHARED;
CREATE OR REPLACE ROW ACCESS POLICY SHARED.TPO_SCORECARD_RAP
    AS (state_code VARCHAR, funded_volume_usd NUMBER) RETURNS BOOLEAN ->
    CASE
      WHEN CURRENT_ROLE() IN ('OB_DEMO_ADMIN','OB_DEMO_RW','OB_DEMO_RO',
                              'SYSADMIN','ACCOUNTADMIN')          THEN TRUE
      WHEN CURRENT_ROLE() = 'OB_DEMO_LENDER_BIG'                  THEN funded_volume_usd > 500000
      WHEN CURRENT_ROLE() = 'OB_DEMO_LENDER_SMALL'                THEN state_code = 'CA'
      ELSE FALSE
    END;

ALTER VIEW OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD
    ADD ROW ACCESS POLICY SHARED.TPO_SCORECARD_RAP
    ON (state_code, funded_volume_usd);

-- =====================================================================
-- STEP 4: Grants to both lender personas
-- =====================================================================

GRANT USAGE  ON DATABASE OPTIMAL_BLUE_DEMO                       TO ROLE OB_DEMO_LENDER_BIG;
GRANT USAGE  ON SCHEMA   OPTIMAL_BLUE_DEMO.LENDER_VIEWS          TO ROLE OB_DEMO_LENDER_BIG;
GRANT SELECT ON VIEW     OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD TO ROLE OB_DEMO_LENDER_BIG;

GRANT USAGE  ON DATABASE OPTIMAL_BLUE_DEMO                       TO ROLE OB_DEMO_LENDER_SMALL;
GRANT USAGE  ON SCHEMA   OPTIMAL_BLUE_DEMO.LENDER_VIEWS          TO ROLE OB_DEMO_LENDER_SMALL;
GRANT SELECT ON VIEW     OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD TO ROLE OB_DEMO_LENDER_SMALL;

-- =====================================================================
-- STEP 5: Verify - two roles, two slices, same view
-- (Run in TWO Snowsight tabs as the respective lender role. IMPORTANT:
-- USE SECONDARY ROLES NONE so other roles' grants don't leak through.)
-- =====================================================================

-- Sanity counts as admin (full visibility, RAP returns TRUE):
SELECT 'admin_full_view'              AS check_name,
       COUNT(*)                        AS rows_visible
FROM OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD;
-- expect: 22000

-- Provider view of the share + policy:
SHOW SHARES LIKE 'OB_DEMO_TPO_SCORECARD_SHARE';
DESCRIBE SHARE OB_DEMO_TPO_SCORECARD_SHARE;
SHOW ROW ACCESS POLICIES LIKE 'TPO_SCORECARD_RAP' IN SCHEMA SHARED;

-- Two-role contrast (the demo punchline):
--   USE ROLE OB_DEMO_LENDER_BIG;   USE SECONDARY ROLES NONE;
--   USE WAREHOUSE OB_DEMO_LENDER_WH;
--   SELECT COUNT(*)               FROM OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD;  -- ~11K
--   SELECT MIN(funded_volume_usd) FROM OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD;  -- > 500000
--   SELECT *                      FROM OPTIMAL_BLUE_DEMO.COMERGENCE.TPO LIMIT 1;     -- denied
--
--   USE ROLE OB_DEMO_LENDER_SMALL; USE SECONDARY ROLES NONE;
--   USE WAREHOUSE OB_DEMO_LENDER_WH;
--   SELECT COUNT(*)               FROM OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD;  -- ~432
--   SELECT DISTINCT state_code    FROM OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD;  -- only 'CA'
--   SELECT *                      FROM OPTIMAL_BLUE_DEMO.COMERGENCE.TPO LIMIT 1;     -- denied
-- =====================================================================
