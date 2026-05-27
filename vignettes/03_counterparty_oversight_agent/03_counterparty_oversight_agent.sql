-- *** REFERENCE / FALLBACK ONLY ***
-- Primary demo path: live-generate this SQL from prompt-contract.md in
-- Cortex Code (Snowsight Workspaces), then run that output. This file
-- exists so we can recover quickly if live generation drifts on stage.
-- =====================================================================
-- V3: Counterparty Oversight Agent (audited + optimized)
--
-- Generated from vignettes/03_counterparty_oversight_agent/prompt-contract.md
-- Run as: OB_DEMO_RW @ OB_DEMO_AI_WH @ OPTIMAL_BLUE_DEMO.AI
--
-- Audit improvements over v1:
--   - Richer tool descriptions: METRICS / DIMENSIONS for analyst tool;
--     doc_type values for search tool. Routes faster + more accurately.
--   - 6 sample_questions covering all main use cases (was 3).
--   - Explicit citation format + length cap + table-format guidance.
--   - Refusal / scope guardrail (decline outside Comergence oversight).
--   - max_results bumped 5 -> 8 for richer search grounding.
--   - Tool routing rules organized inside instructions.response with
--     trigger-word hints. NOTE: Snowflake's agent spec rejects nested
--     `orchestration.instructions`; the documented field stays {}.
--   - Demo-time eval block at the bottom.
--
-- Two tools:
--   - TPO_RISK_SV       (cortex_analyst_text_to_sql -> AI.TPO_RISK_SV)
--   - COMPLIANCE_SEARCH (cortex_search              -> AI.COMPLIANCE_CSS)
-- =====================================================================

USE ROLE OB_DEMO_RW;
USE WAREHOUSE OB_DEMO_AI_WH;
USE DATABASE OPTIMAL_BLUE_DEMO;
USE SCHEMA AI;

-- =====================================================================
-- STEP 1: Create the optimized Counterparty Oversight Agent
-- =====================================================================

CREATE OR REPLACE AGENT AI.COUNTERPARTY_AGENT
    WITH PROFILE = '{ "display_name": "Counterparty Oversight Agent" }'
    COMMENT = 'Comergence TPO oversight assistant - structured KPIs (semantic view) + governed guideline / audit search. Persona: a risk operations analyst supporting Comergence counterparty oversight.'
    FROM SPECIFICATION $$
{
    "models": { "orchestration": "auto" },
    "orchestration": {},
    "instructions": {
        "response": "PERSONA: Comergence counterparty oversight assistant for risk-operations analysts. STYLE: concise, decision-oriented, professional. FORMAT: markdown bullets for lists; markdown tables when comparing 3+ entities or showing top-N rows; prose only for short narrative summaries. LENGTH: under 12 bullets unless the user explicitly asks for more detail. CITATIONS: end every fact-bearing bullet with a tag in square brackets - [TPO_RISK_SV] for structured numbers and [COMPLIANCE_SEARCH: <chunk title>] for guideline / audit text. GROUNDING: NEVER invent TPO IDs, finding IDs, or guideline content - if a value is not in tool output say not available. TOOL ROUTING: (a) Use TPO_RISK_SV for QUANTITATIVE questions - counts, sums, averages, expirations within N days, sliced by state / region / channel / risk_tier / investor / status (trigger words: how many, which states, top N, average, expiring). (b) Use COMPLIANCE_SEARCH for QUALITATIVE / TEXT questions about investor guidelines, audit narratives, NMLS filings, policy text (trigger words: summarize, what does the policy say, differences between, find guidance on). (c) For per-TPO questions that mix counts AND narrative, call TPO_RISK_SV first then optionally COMPLIANCE_SEARCH. (d) For remediation drafting on a specific TPO id, ALWAYS retrieve open and high-severity findings via TPO_RISK_SV first, then format as a 4-bullet remediation note grounded only in those findings. SCOPE / REFUSAL: if a question is outside Comergence counterparty oversight (e.g. consumer mortgage advice, secondary marketing pricing strategy, hedge calculations), politely decline and suggest a Comergence oversight question instead - do NOT answer speculatively.",
        "sample_questions": [
            { "question": "Which states have the most high-risk TPOs?" },
            { "question": "How many TPOs have licenses expiring in the next 30 days, by region?" },
            { "question": "Summarize the FHA overlay differences between investor guidelines from our compliance documents." },
            { "question": "Has TPO 2210 had any open audit findings in the last 60 days?" },
            { "question": "Draft a remediation note for TPO 2210 referencing the most recent open high-severity findings." },
            { "question": "Which onboarding stage is slowest on average across our TPO network?" }
        ]
    },
    "tools": [
        { "tool_spec": {
            "type": "cortex_analyst_text_to_sql",
            "name": "TPO_RISK_SV",
            "description": "STRUCTURED counterparty risk semantic view over 22,000 TPOs. METRICS available: tpo_count, active_tpo_count, suspended_tpo_count, high_risk_tpo_count, open_findings, high_severity_findings, findings_last_90d, exception_count, licenses_expiring_30d, licenses_expiring_90d, lo_active, avg_days_to_active, total_annual_volume. DIMENSIONS available: tpo_name, state_code, state_name, region (Northeast/South/Midwest/West), channel_code, channel_name (Wholesale / Correspondent / Non-Delegated / Retail), primary_investor_id, investor_name, tpo_status (ACTIVE/PROBATION/SUSPENDED/ONBOARDING), risk_tier (LOW/MED/HIGH). Use for any aggregate, count, top-N, expiring-license, or per-TPO finding lookup question."
        } },
        { "tool_spec": {
            "type": "cortex_search",
            "name": "COMPLIANCE_SEARCH",
            "description": "UNSTRUCTURED Cortex Search service over Comergence compliance documents. Indexes ~800 chunks across 100 documents of types: GUIDELINE (investor FHA / VA / agency overlays), AUDIT_REPORT (per-TPO audit narratives), NMLS_FILING (Consumer Access disclosures), POLICY (Optimal Blue compliance policies). Use for any question about policy text, guideline differences between investors, audit narrative content, or BSA/AML / fair lending / social media compliance language."
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
            "max_results": 8,
            "id_column": "CHUNK_ID",
            "title_column": "TITLE"
        }
    }
}
$$;

-- =====================================================================
-- STEP 2: Smoke + structural verification
-- =====================================================================
SHOW AGENTS IN SCHEMA AI;
DESCRIBE AGENT AI.COUNTERPARTY_AGENT;

-- =====================================================================
-- STEP 3: Demo-time eval block (manual - run each prompt in Snowsight
-- Agent Run UI and confirm the routing matches the expected tool):
--
--   1. "Which states have the most high-risk TPOs?"           -> TPO_RISK_SV
--   2. "Summarize FHA overlay differences."                   -> COMPLIANCE_SEARCH
--   3. "Licenses expiring in 30 days by region?"              -> TPO_RISK_SV
--   4. "Draft remediation for TPO 2210."                      -> TPO_RISK_SV (then format)
--   5. "What does our BSA/AML reporting policy say?"          -> COMPLIANCE_SEARCH
--   6. (Out-of-scope) "What rate should I lock today?"        -> refuse politely
-- =====================================================================
