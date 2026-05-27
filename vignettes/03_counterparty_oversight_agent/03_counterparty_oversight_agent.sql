-- *** REFERENCE / FALLBACK ONLY ***
-- Primary demo path: live-generate this SQL from prompt-contract.md in
-- Cortex Code (Snowsight Workspaces), then run that output. This file
-- exists so we can recover quickly if live generation drifts on stage.
-- =====================================================================
-- V3: Counterparty Oversight Agent
--
-- Generated from vignettes/03_counterparty_oversight_agent/prompt-contract.md
-- Run as: OB_DEMO_RW @ OB_DEMO_AI_WH @ OPTIMAL_BLUE_DEMO.AI
--
-- Two tools:
--   - TPO_RISK_SV       (cortex_analyst_text_to_sql -> AI.TPO_RISK_SV)
--   - COMPLIANCE_SEARCH (cortex_search              -> AI.COMPLIANCE_CSS)
--
-- Demo talk: "Centerpiece. One agent, two governed tools, real
-- oversight questions answered in seconds with citations."
-- =====================================================================

USE ROLE OB_DEMO_RW;
USE WAREHOUSE OB_DEMO_AI_WH;
USE DATABASE OPTIMAL_BLUE_DEMO;
USE SCHEMA AI;

-- =====================================================================
-- STEP 1: Create the Counterparty Oversight Agent
-- Tools: semantic view (V1) + search service (V2).
-- The agent composes any per-TPO finding lookup via the analyst tool's
-- generated SQL - no separate function needed.
-- =====================================================================

CREATE OR REPLACE AGENT AI.COUNTERPARTY_AGENT
    WITH PROFILE = '{ "display_name": "Counterparty Oversight Agent" }'
    COMMENT = 'Comergence TPO oversight: structured KPIs + guideline lookup'
    FROM SPECIFICATION $$
{
    "models": { "orchestration": "auto" },
    "orchestration": {},
    "instructions": {
        "response": "You are a Comergence counterparty oversight assistant. Answer in concise bullets. Cite which tool produced each fact. Use TPO_RISK_SV for any aggregate or KPI question (counts, expirations, risk tiers, regions, exception volume, onboarding speed). Use COMPLIANCE_SEARCH for any question about investor guidelines, policy text, or audit narrative content. When a user asks for remediation drafting for a specific TPO id, first use TPO_RISK_SV to retrieve open / high-severity findings for that TPO, then summarize them as a 4-bullet remediation note.",
        "sample_questions": [
            { "question": "Which states have the most high-risk TPOs?" },
            { "question": "Summarize the FHA overlay differences between investors from the guideline PDFs." },
            { "question": "Has TPO 2210 had any open audit findings in the last 60 days?" }
        ]
    },
    "tools": [
        { "tool_spec": {
            "type": "cortex_analyst_text_to_sql",
            "name": "TPO_RISK_SV",
            "description": "TPO counterparty risk semantic view: audit findings, license expirations, exceptions, onboarding, sliced by state / channel / risk_tier / investor."
        } },
        { "tool_spec": {
            "type": "cortex_search",
            "name": "COMPLIANCE_SEARCH",
            "description": "Cortex Search service over Comergence guidelines, audit reports, NMLS filings, and policy text."
        } }
    ],
    "tool_resources": {
        "TPO_RISK_SV": {
            "execution_environment": {
                "type": "warehouse",
                "warehouse": "OB_DEMO_AI_WH",
                "query_timeout": 30
            },
            "semantic_view": "OPTIMAL_BLUE_DEMO.AI.TPO_RISK_SV"
        },
        "COMPLIANCE_SEARCH": {
            "search_service": "OPTIMAL_BLUE_DEMO.AI.COMPLIANCE_CSS",
            "max_results": 5,
            "id_column": "CHUNK_ID",
            "title_column": "TITLE"
        }
    }
}
$$;

-- =====================================================================
-- STEP 2: Smoke test
-- =====================================================================
SHOW AGENTS IN SCHEMA AI;
DESCRIBE AGENT AI.COUNTERPARTY_AGENT;
