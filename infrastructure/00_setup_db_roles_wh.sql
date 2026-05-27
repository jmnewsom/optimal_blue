-- =====================================================================
-- 00_setup_db_roles_wh.sql
-- Optimal Blue / Comergence Cortex Code Demo - Foundation
--
-- Generated from infrastructure/prompt-contract.md
-- Idempotent: safe to re-run on a clean or partially-built account.
--
-- Order: warehouses -> roles -> database -> schemas -> grants -> stages
-- =====================================================================

USE ROLE SYSADMIN;

-- =====================================================================
-- STEP 1: Create dedicated demo warehouses
--   - OB_DEMO_WH         : SQL/UI workloads (Worksheets, Streamlit dev)
--   - OB_DEMO_AI_WH      : Cortex Analyst / Search index build / AISQL
--   - OB_DEMO_LENDER_WH  : Simulated Marketplace consumer (V5)
-- Demo talk: "Three workload-aligned warehouses, all auto-suspending in
-- 60s so credits only burn while we're actively demonstrating."
-- =====================================================================

CREATE WAREHOUSE IF NOT EXISTS OB_DEMO_WH
    WAREHOUSE_SIZE = XSMALL
    AUTO_SUSPEND   = 60
    AUTO_RESUME    = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Optimal Blue demo - SQL & Streamlit dev workloads';

CREATE WAREHOUSE IF NOT EXISTS OB_DEMO_AI_WH
    WAREHOUSE_SIZE = MEDIUM
    AUTO_SUSPEND   = 60
    AUTO_RESUME    = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Optimal Blue demo - Cortex Analyst, Search build, AISQL';

CREATE WAREHOUSE IF NOT EXISTS OB_DEMO_LENDER_WH
    WAREHOUSE_SIZE = XSMALL
    AUTO_SUSPEND   = 60
    AUTO_RESUME    = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Optimal Blue demo - simulated Marketplace consumer (V5)';

-- =====================================================================
-- STEP 2: Create demo roles (admin, RW author, RO analyst, lender)
-- Demo talk: "Same governance pattern Comergence will use in production."
-- =====================================================================

USE ROLE USERADMIN;

CREATE ROLE IF NOT EXISTS OB_DEMO_ADMIN  COMMENT = 'OB demo - owns objects';
CREATE ROLE IF NOT EXISTS OB_DEMO_RW     COMMENT = 'OB demo - vignette author';
CREATE ROLE IF NOT EXISTS OB_DEMO_RO     COMMENT = 'OB demo - analyst read-only';
CREATE ROLE IF NOT EXISTS OB_DEMO_LENDER COMMENT = 'OB demo - simulated Marketplace consumer';

-- Role hierarchy: ADMIN owns everything, RW inherits RO read access.
GRANT ROLE OB_DEMO_RO     TO ROLE OB_DEMO_RW;
GRANT ROLE OB_DEMO_RW     TO ROLE OB_DEMO_ADMIN;
GRANT ROLE OB_DEMO_ADMIN  TO ROLE SYSADMIN;
GRANT ROLE OB_DEMO_LENDER TO ROLE SYSADMIN;

-- Grant the demo roles to the active service user so the SE can switch
-- between them in Snowsight without leaving the session. IDENTIFIER()
-- needs a session variable or string literal, not a function expression.
SET ob_demo_user = CURRENT_USER();
GRANT ROLE OB_DEMO_ADMIN  TO USER IDENTIFIER($ob_demo_user);
GRANT ROLE OB_DEMO_RW     TO USER IDENTIFIER($ob_demo_user);
GRANT ROLE OB_DEMO_RO     TO USER IDENTIFIER($ob_demo_user);
GRANT ROLE OB_DEMO_LENDER TO USER IDENTIFIER($ob_demo_user);

-- Warehouse usage grants
USE ROLE SECURITYADMIN;
GRANT USAGE, OPERATE ON WAREHOUSE OB_DEMO_WH        TO ROLE OB_DEMO_ADMIN;
GRANT USAGE, OPERATE ON WAREHOUSE OB_DEMO_AI_WH     TO ROLE OB_DEMO_ADMIN;
GRANT USAGE, OPERATE ON WAREHOUSE OB_DEMO_LENDER_WH TO ROLE OB_DEMO_ADMIN;
GRANT USAGE          ON WAREHOUSE OB_DEMO_WH        TO ROLE OB_DEMO_RW;
GRANT USAGE          ON WAREHOUSE OB_DEMO_AI_WH     TO ROLE OB_DEMO_RW;
GRANT USAGE          ON WAREHOUSE OB_DEMO_WH        TO ROLE OB_DEMO_RO;
GRANT USAGE          ON WAREHOUSE OB_DEMO_LENDER_WH TO ROLE OB_DEMO_LENDER;

-- Account-level: OB_DEMO_ADMIN needs CREATE SHARE for V5 (Marketplace).
USE ROLE ACCOUNTADMIN;
GRANT CREATE SHARE ON ACCOUNT TO ROLE OB_DEMO_ADMIN;

-- =====================================================================
-- STEP 3: Create database + functional schemas
-- Demo talk: "One DB, four functional schemas - this is the governed
-- foundation that replaces the patchwork of Azure SQL Servers today."
-- Database is created by SYSADMIN (which has CREATE DATABASE on account)
-- and ownership is transferred to OB_DEMO_ADMIN.
-- =====================================================================

USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS OPTIMAL_BLUE_DEMO
    COMMENT = 'Optimal Blue + Comergence Cortex Code demo';
GRANT OWNERSHIP ON DATABASE OPTIMAL_BLUE_DEMO TO ROLE OB_DEMO_ADMIN COPY CURRENT GRANTS;

USE ROLE OB_DEMO_ADMIN;
USE DATABASE OPTIMAL_BLUE_DEMO;

CREATE SCHEMA IF NOT EXISTS COMERGENCE COMMENT = 'TPO oversight, audits, social, NMLS';
CREATE SCHEMA IF NOT EXISTS PPE        COMMENT = 'Pricing, eligibility, locks, fallout';
CREATE SCHEMA IF NOT EXISTS SHARED     COMMENT = 'Cross-domain views and Marketplace assets';
CREATE SCHEMA IF NOT EXISTS AI         COMMENT = 'Semantic views, Cortex Search services, agents';
CREATE SCHEMA IF NOT EXISTS STAGES     COMMENT = 'Internal stages for unstructured assets';

-- =====================================================================
-- STEP 4: Schema-level grants
-- =====================================================================

GRANT USAGE ON DATABASE OPTIMAL_BLUE_DEMO TO ROLE OB_DEMO_RW;
GRANT USAGE ON DATABASE OPTIMAL_BLUE_DEMO TO ROLE OB_DEMO_RO;

GRANT USAGE, CREATE TABLE, CREATE VIEW, CREATE STAGE, CREATE FUNCTION,
      CREATE SEMANTIC VIEW, CREATE CORTEX SEARCH SERVICE
    ON SCHEMA OPTIMAL_BLUE_DEMO.COMERGENCE TO ROLE OB_DEMO_RW;
GRANT USAGE, CREATE TABLE, CREATE VIEW, CREATE STAGE, CREATE FUNCTION,
      CREATE SEMANTIC VIEW, CREATE CORTEX SEARCH SERVICE
    ON SCHEMA OPTIMAL_BLUE_DEMO.PPE TO ROLE OB_DEMO_RW;
GRANT USAGE, CREATE TABLE, CREATE VIEW, CREATE STAGE,
      CREATE SEMANTIC VIEW
    ON SCHEMA OPTIMAL_BLUE_DEMO.SHARED TO ROLE OB_DEMO_RW;
GRANT USAGE, CREATE TABLE, CREATE VIEW, CREATE STAGE, CREATE FUNCTION,
      CREATE SEMANTIC VIEW, CREATE CORTEX SEARCH SERVICE,
      CREATE AGENT, CREATE STREAMLIT
    ON SCHEMA OPTIMAL_BLUE_DEMO.AI TO ROLE OB_DEMO_RW;
GRANT USAGE, CREATE STAGE
    ON SCHEMA OPTIMAL_BLUE_DEMO.STAGES TO ROLE OB_DEMO_RW;

-- Read-only analyst sees everything but can change nothing.
GRANT USAGE ON ALL SCHEMAS    IN DATABASE OPTIMAL_BLUE_DEMO TO ROLE OB_DEMO_RO;
GRANT SELECT ON ALL TABLES    IN DATABASE OPTIMAL_BLUE_DEMO TO ROLE OB_DEMO_RO;
GRANT SELECT ON FUTURE TABLES IN DATABASE OPTIMAL_BLUE_DEMO TO ROLE OB_DEMO_RO;
GRANT SELECT ON ALL VIEWS     IN DATABASE OPTIMAL_BLUE_DEMO TO ROLE OB_DEMO_RO;
GRANT SELECT ON FUTURE VIEWS  IN DATABASE OPTIMAL_BLUE_DEMO TO ROLE OB_DEMO_RO;

-- Future grants for OB_DEMO_RW so V1-V6 objects inherit access.
GRANT SELECT, INSERT, UPDATE, DELETE
    ON FUTURE TABLES IN DATABASE OPTIMAL_BLUE_DEMO TO ROLE OB_DEMO_RW;
GRANT SELECT ON FUTURE VIEWS IN DATABASE OPTIMAL_BLUE_DEMO TO ROLE OB_DEMO_RW;

-- =====================================================================
-- STEP 5: Internal stage for unstructured compliance documents
-- Goal: house ~100 synthetic guideline / audit PDFs for V2 Cortex Search.
-- Demo talk: "Same stage pattern Comergence will use for guideline PDFs
-- received via investor portals today."
-- =====================================================================

USE SCHEMA STAGES;

CREATE STAGE IF NOT EXISTS COMPLIANCE_DOCS
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    COMMENT = 'Compliance docs: investor guidelines, audit reports, NMLS filings';

GRANT READ, WRITE ON STAGE STAGES.COMPLIANCE_DOCS TO ROLE OB_DEMO_RW;
GRANT READ          ON STAGE STAGES.COMPLIANCE_DOCS TO ROLE OB_DEMO_RO;

-- =====================================================================
-- STEP 6: Validate (run as OB_DEMO_RW)
-- =====================================================================
USE ROLE OB_DEMO_RW;
USE WAREHOUSE OB_DEMO_WH;
USE DATABASE OPTIMAL_BLUE_DEMO;

SHOW SCHEMAS IN DATABASE OPTIMAL_BLUE_DEMO;
SHOW WAREHOUSES LIKE 'OB_DEMO_%';
