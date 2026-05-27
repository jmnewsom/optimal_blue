-- *** REFERENCE / FALLBACK ONLY ***
-- Primary demo path: live-generate this SQL from prompt-contract.md in
-- Cortex Code (Snowsight Workspaces), then run that output. This file
-- exists so we can recover quickly if live generation drifts on stage.
-- =====================================================================
-- V2: Cortex Search + AISQL on Compliance Docs & Social Media
--
-- Generated from vignettes/02_cortex_search_compliance/prompt-contract.md
-- Run as: OB_DEMO_RW @ OB_DEMO_AI_WH @ OPTIMAL_BLUE_DEMO.AI
--
-- Demo talk: "Two AI surfaces in one vignette: search over guidelines
-- and AISQL classification of every social post. Both are governed,
-- both are reproducible from this contract."
-- =====================================================================

USE ROLE OB_DEMO_RW;
USE WAREHOUSE OB_DEMO_AI_WH;
USE DATABASE OPTIMAL_BLUE_DEMO;

-- =====================================================================
-- STEP 1: Cortex Search service over compliance document chunks
-- Goal: vector + lexical hybrid index for natural-language doc queries.
-- Demo talk: "One CREATE statement and Snowflake builds the index."
-- =====================================================================

USE SCHEMA AI;

CREATE OR REPLACE CORTEX SEARCH SERVICE AI.COMPLIANCE_CSS
    ON chunk_text
    ATTRIBUTES doc_id, doc_type, title, investor_id, tpo_id, published_at
    WAREHOUSE = OB_DEMO_AI_WH
    TARGET_LAG = '5 minutes'
    AS
        SELECT
            chunk_id,
            chunk_text,
            doc_id,
            doc_type,
            title,
            investor_id,
            tpo_id,
            published_at
        FROM COMERGENCE.COMPLIANCE_DOC_CHUNK;

-- =====================================================================
-- STEP 2: AISQL classification of social media posts
-- Goal: every post gets a topic + sentiment + compliance_risk label.
-- Demo talk: "Comergence's social compliance product, accelerated by AI."
-- =====================================================================

USE SCHEMA COMERGENCE;

-- ---------------------------------------------------------------------
-- SOCIAL_FLAG: materialized AI labels for the SOCIAL_POST corpus.
-- AI_CLASSIFY picks one of our domain-specific topics; AI_SENTIMENT
-- returns positive/neutral/negative; AI_CLASSIFY into a 3-band label
-- gives us compliance_risk. Sampled to 5000 rows for cost guard
-- (~15K LLM calls instead of 150K). Demo says "sampled" out loud.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE COMERGENCE.SOCIAL_FLAG AS
SELECT
    p.post_id,
    p.tpo_id,
    p.lo_id,
    p.platform,
    p.posted_at,
    p.post_text,
    -- topic classification across compliance-relevant categories
    AI_CLASSIFY(
        p.post_text,
        ['rate advertising','approval guarantee','no-doc loan',
         'compliance neutral','customer celebration','market commentary']
    ):labels[0]::STRING                                               AS topic,
    -- sentiment: positive / neutral / negative
    AI_SENTIMENT(p.post_text):categories[0]:sentiment::STRING         AS sentiment,
    -- compliance risk via AI_CLASSIFY into a 3-band label.
    -- Labels are kept short ('HIGH','MEDIUM','LOW') because AI_CLASSIFY
    -- returns empty labels arrays when label strings contain hyphens or
    -- long descriptive text. Demo talk maps these to "likely violation
    -- / review needed / acceptable" verbally.
    AI_CLASSIFY(
        p.post_text,
        ['HIGH', 'MEDIUM', 'LOW']
    ):labels[0]::STRING                                               AS compliance_risk
FROM COMERGENCE.SOCIAL_POST p
SAMPLE (5000 ROWS);

-- =====================================================================
-- STEP 3: Smoke tests
-- =====================================================================

-- 3a) sample search over guidelines
SELECT PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'OPTIMAL_BLUE_DEMO.AI.COMPLIANCE_CSS',
        '{"query": "FHA overlay minimum credit score", "limit": 3}'
    )
) AS sample_search_result;

-- 3b) sample distribution of compliance_risk on the materialized flags
SELECT compliance_risk, COUNT(*) AS n
FROM COMERGENCE.SOCIAL_FLAG
GROUP BY compliance_risk
ORDER BY 2 DESC;
