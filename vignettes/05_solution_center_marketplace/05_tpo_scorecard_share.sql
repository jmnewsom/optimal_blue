-- *** REFERENCE / FALLBACK ONLY ***
-- Primary demo path: live-generate this SQL from prompt-contract.md in
-- Cortex Code (Snowsight Workspaces), then run that output. This file
-- exists so we can recover quickly if live generation drifts on stage.
-- =====================================================================
-- V5: Solution Center as Snowflake Marketplace / Data Share
--
-- Generated from vignettes/05_solution_center_marketplace/prompt-contract.md
-- Run as: OB_DEMO_ADMIN @ OB_DEMO_WH
--
-- Two halves:
--   1. PRODUCER side: real Snowflake SHARE on TPO_SCORECARD_V (the
--      object Optimal Blue would publish to lender accounts in prod).
--   2. CONSUMER simulation: in-account LENDER_VIEWS schema with a
--      single SELECT-only view granted to OB_DEMO_LENDER. Snowflake
--      does NOT permit consuming a share inside the same account, so
--      we simulate the lender's surface this way. The role-switch
--      demo moment is preserved.
--
-- Demo talk: "Producer side is exactly how we'd publish to lender
-- accounts. Consumer side is simulated in this same account so you
-- can see the lender's surface without a second login."
-- =====================================================================

USE ROLE OB_DEMO_ADMIN;
USE WAREHOUSE OB_DEMO_WH;
USE DATABASE OPTIMAL_BLUE_DEMO;

-- =====================================================================
-- STEP 1: PRODUCER - create a real Snowflake share
-- This is the object that would be granted to lender accounts in prod.
-- =====================================================================

CREATE OR REPLACE SHARE OB_DEMO_TPO_SCORECARD_SHARE
    COMMENT = 'Optimal Blue / Comergence TPO performance + compliance scorecard - lender-facing';

GRANT USAGE  ON DATABASE OPTIMAL_BLUE_DEMO        TO SHARE OB_DEMO_TPO_SCORECARD_SHARE;
GRANT USAGE  ON SCHEMA   OPTIMAL_BLUE_DEMO.SHARED TO SHARE OB_DEMO_TPO_SCORECARD_SHARE;
GRANT SELECT ON VIEW     OPTIMAL_BLUE_DEMO.SHARED.TPO_SCORECARD_V
    TO SHARE OB_DEMO_TPO_SCORECARD_SHARE;

-- =====================================================================
-- STEP 2: CONSUMER simulation (in-account)
-- Snowflake does not allow same-account share consumption. We simulate
-- the lender experience with a dedicated schema + single SELECT-only
-- view that mirrors what the share exposes. The lender role can ONLY
-- see this schema; source tables remain hidden.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS OPTIMAL_BLUE_DEMO.LENDER_VIEWS
    COMMENT = 'Simulated lender Marketplace consumer surface (V5)';

CREATE OR REPLACE VIEW OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD AS
    SELECT * FROM OPTIMAL_BLUE_DEMO.SHARED.TPO_SCORECARD_V;

-- Lender role: minimum privileges to query exactly one view.
GRANT USAGE  ON DATABASE OPTIMAL_BLUE_DEMO                       TO ROLE OB_DEMO_LENDER;
GRANT USAGE  ON SCHEMA   OPTIMAL_BLUE_DEMO.LENDER_VIEWS          TO ROLE OB_DEMO_LENDER;
GRANT SELECT ON VIEW     OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD TO ROLE OB_DEMO_LENDER;
GRANT USAGE  ON WAREHOUSE OB_DEMO_LENDER_WH                       TO ROLE OB_DEMO_LENDER;

-- =====================================================================
-- STEP 3: Verify the consumer experience
-- Run these in the SECOND Snowsight tab as OB_DEMO_LENDER:
--   USE ROLE OB_DEMO_LENDER;
--   USE SECONDARY ROLES NONE;       -- IMPORTANT: disables inherited roles
--   USE WAREHOUSE OB_DEMO_LENDER_WH;
--   SELECT COUNT(*) FROM OPTIMAL_BLUE_DEMO.LENDER_VIEWS.TPO_SCORECARD;  -- ~22000
--   SELECT * FROM OPTIMAL_BLUE_DEMO.COMERGENCE.TPO LIMIT 1;             -- denied
-- The denial is the demo punchline: governance keeps source tables hidden.
-- Without USE SECONDARY ROLES NONE, the SE's user picks up other roles
-- with broader access and the denial won't fire - this is the gotcha.
-- =====================================================================

SHOW SHARES LIKE 'OB_DEMO_TPO_SCORECARD_SHARE';
DESCRIBE SHARE OB_DEMO_TPO_SCORECARD_SHARE;
SHOW SCHEMAS LIKE 'LENDER_VIEWS' IN DATABASE OPTIMAL_BLUE_DEMO;
