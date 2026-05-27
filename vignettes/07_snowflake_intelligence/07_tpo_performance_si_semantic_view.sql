-- *** REFERENCE / FALLBACK ONLY ***
-- Primary demo path: live-generate this SQL from prompt-contract.md in
-- Cortex Code (Snowsight Workspaces), then run that output. This file
-- exists so we can recover quickly if live generation drifts on stage.
-- =====================================================================
-- V7: Snowflake Intelligence capstone
-- Wraps SHARED.TPO_PERFORMANCE_V into an SI-friendly semantic view
-- so executives can ask cross-org questions without writing SQL.
-- =====================================================================

USE ROLE OB_DEMO_RW;
USE WAREHOUSE OB_DEMO_AI_WH;
USE DATABASE OPTIMAL_BLUE_DEMO;
USE SCHEMA AI;

CREATE OR REPLACE SEMANTIC VIEW AI.TPO_PERFORMANCE_SV
    TABLES (
        perf AS SHARED.TPO_PERFORMANCE_V
            PRIMARY KEY (tpo_id)
            WITH SYNONYMS = ('TPO performance','counterparty scorecard')
            COMMENT = 'Cross-org TPO performance + compliance'
    )
    DIMENSIONS (
        perf.state_code   AS state_code   WITH SYNONYMS = ('state'),
        perf.channel_code AS channel_code WITH SYNONYMS = ('channel'),
        perf.risk_tier    AS risk_tier    WITH SYNONYMS = ('risk band'),
        perf.tpo_status   AS tpo_status   WITH SYNONYMS = ('status')
    )
    METRICS (
        perf.tpo_count            AS COUNT(perf.tpo_id),
        perf.avg_compliance_score AS AVG(perf.compliance_score)
            WITH SYNONYMS = ('average compliance score'),
        perf.avg_pull_through     AS AVG(perf.pull_through_pct)
            WITH SYNONYMS = ('average pull-through','avg pt'),
        perf.total_funded_volume  AS SUM(perf.funded_volume_usd)
            WITH SYNONYMS = ('funded volume','origination volume')
    )
    COMMENT = 'Cross-org TPO performance for Snowflake Intelligence capstone';

-- Smoke test
SELECT * FROM SEMANTIC_VIEW(
    AI.TPO_PERFORMANCE_SV
    DIMENSIONS risk_tier
    METRICS    tpo_count, avg_compliance_score, avg_pull_through, total_funded_volume
);
