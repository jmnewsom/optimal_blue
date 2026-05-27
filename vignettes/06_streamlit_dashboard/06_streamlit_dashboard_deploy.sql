-- *** REFERENCE / FALLBACK ONLY ***
-- Primary demo path: live-generate this SQL from prompt-contract.md in
-- Cortex Code (Snowsight Workspaces), then run that output. This file
-- exists so we can recover quickly if live generation drifts on stage.
-- =====================================================================
-- V6: Deploy the Streamlit app to Snowflake (SiS)
-- Run as: OB_DEMO_RW @ OB_DEMO_WH @ OPTIMAL_BLUE_DEMO.AI
-- Prefer:  snow streamlit deploy ob_comergence_dashboard --replace
-- =====================================================================
USE ROLE OB_DEMO_RW;
USE WAREHOUSE OB_DEMO_WH;
USE DATABASE OPTIMAL_BLUE_DEMO;
USE SCHEMA AI;

-- Stage to host the Streamlit files
CREATE STAGE IF NOT EXISTS AI.STREAMLIT_STAGE
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

-- Upload via:
--   snow stage put vignettes/06_streamlit_dashboard/app.py
--                  @OPTIMAL_BLUE_DEMO.AI.STREAMLIT_STAGE/ob_comergence_dashboard/
--                  --auto-compress=false --overwrite=true
--   snow stage put vignettes/06_streamlit_dashboard/requirements.txt
--                  @OPTIMAL_BLUE_DEMO.AI.STREAMLIT_STAGE/ob_comergence_dashboard/
--                  --auto-compress=false --overwrite=true

CREATE OR REPLACE STREAMLIT AI.OB_COMERGENCE_DASHBOARD
    ROOT_LOCATION = '@OPTIMAL_BLUE_DEMO.AI.STREAMLIT_STAGE/ob_comergence_dashboard'
    MAIN_FILE     = 'app.py'
    QUERY_WAREHOUSE = OB_DEMO_WH
    COMMENT = 'Counterparty Risk Dashboard - Optimal Blue Comergence demo';

GRANT USAGE ON STREAMLIT AI.OB_COMERGENCE_DASHBOARD TO ROLE OB_DEMO_RO;
SHOW STREAMLITS LIKE 'OB_COMERGENCE_DASHBOARD' IN SCHEMA AI;
