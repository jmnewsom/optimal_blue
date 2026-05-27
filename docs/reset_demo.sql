-- =====================================================================
-- reset_demo.sql
-- Tear down everything created by the Optimal Blue / Comergence demo.
-- Safe to run repeatedly.
--
-- ORDER MATTERS: a share that references the DB blocks DROP DATABASE,
-- so the share is dropped FIRST as its owning role (OB_DEMO_ADMIN).
-- Drop sequence: SHARE -> DATABASE -> WAREHOUSES -> ROLES.
-- =====================================================================

-- 1. Drop share as its owning role.
-- Use IDENTIFIER + USE ROLE pattern to remain robust if the role tree
-- changes; SYSADMIN inherits OB_DEMO_ADMIN by design.
USE ROLE SYSADMIN;
USE ROLE OB_DEMO_ADMIN;
DROP SHARE IF EXISTS OB_DEMO_TPO_SCORECARD_SHARE;

-- 2. Drop database (now safe since the share no longer references it).
USE ROLE SYSADMIN;
DROP DATABASE IF EXISTS OPTIMAL_BLUE_DEMO CASCADE;

-- 3. Drop demo warehouses.
DROP WAREHOUSE IF EXISTS OB_DEMO_WH;
DROP WAREHOUSE IF EXISTS OB_DEMO_AI_WH;
DROP WAREHOUSE IF EXISTS OB_DEMO_LENDER_WH;

-- 4. Drop demo roles.
USE ROLE USERADMIN;
DROP ROLE IF EXISTS OB_DEMO_LENDER_BIG;
DROP ROLE IF EXISTS OB_DEMO_LENDER_SMALL;
DROP ROLE IF EXISTS OB_DEMO_LENDER;     -- legacy single-lender role (pre-V5 redesign)
DROP ROLE IF EXISTS OB_DEMO_RO;
DROP ROLE IF EXISTS OB_DEMO_RW;
DROP ROLE IF EXISTS OB_DEMO_ADMIN;
