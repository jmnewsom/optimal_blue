-- *** REFERENCE / FALLBACK ONLY ***
-- Primary demo path: live-generate this SQL from prompt-contract.md in
-- Cortex Code (Snowsight Workspaces), then run that output. This file
-- exists so we can recover quickly if live generation drifts on stage.
-- =====================================================================
-- V4: Cross-org Bridge - TPO Performance + Lock Pull-through
--
-- Generated from vignettes/04_cross_org_bridge/prompt-contract.md
-- Run as: OB_DEMO_RW @ OB_DEMO_AI_WH @ OPTIMAL_BLUE_DEMO.SHARED
--
-- Demo talk: "This is the strategic moment. Same TPO entity, two worlds.
-- Comergence sees compliance; PPE sees execution; Snowflake sees both."
-- =====================================================================

USE ROLE OB_DEMO_RW;
USE WAREHOUSE OB_DEMO_AI_WH;
USE DATABASE OPTIMAL_BLUE_DEMO;
USE SCHEMA SHARED;

-- =====================================================================
-- STEP 1: Build per-TPO lock metrics (PPE side)
-- Aggregate FIRST so we never fan out the TPO grain.
-- =====================================================================

CREATE OR REPLACE VIEW SHARED.TPO_LOCK_METRICS_V AS
SELECT
    tpo_id,
    COUNT(*)                                                AS total_locks,
    COUNT_IF(lock_status = 'FUNDED')                        AS funded_locks,
    COUNT_IF(lock_status = 'FALLOUT')                       AS fallout_locks,
    -- guard against div-by-zero
    DIV0(COUNT_IF(lock_status = 'FUNDED'), COUNT(*)) * 100  AS pull_through_pct,
    DIV0(COUNT_IF(lock_status = 'FALLOUT'), COUNT(*)) * 100 AS fallout_pct,
    SUM(IFF(lock_status = 'FUNDED', note_amount, 0))        AS funded_volume_usd,
    AVG(rate_bps)                                           AS avg_rate_bps,
    COUNT(DISTINCT investor_id)                             AS investor_breadth
FROM PPE.LOCK
GROUP BY tpo_id;

-- =====================================================================
-- STEP 2: Build per-TPO compliance metrics (Comergence side)
-- =====================================================================

CREATE OR REPLACE VIEW SHARED.TPO_COMPLIANCE_METRICS_V AS
SELECT
    t.tpo_id,
    t.tpo_name,
    t.state_code,
    t.channel_code,
    t.risk_tier,
    t.status,
    COALESCE(af.open_findings, 0)            AS open_findings,
    COALESCE(af.high_severity_findings, 0)   AS high_severity_findings,
    COALESCE(lic.licenses_expiring_30d, 0)   AS licenses_expiring_30d,
    -- Compliance score (0-100, higher = better):
    --   start at 100, subtract penalties for findings + expirations + suspended
    GREATEST(
        0,
        100
        - COALESCE(af.high_severity_findings, 0) * 10
        - COALESCE(af.open_findings, 0)          * 2
        - COALESCE(lic.licenses_expiring_30d, 0) * 5
        - IFF(t.status = 'SUSPENDED', 50, 0)
        - IFF(t.risk_tier = 'HIGH',    15, 0)
    )                                         AS compliance_score
FROM COMERGENCE.TPO t
LEFT JOIN (
    SELECT tpo_id,
           COUNT_IF(status = 'OPEN') AS open_findings,
           COUNT_IF(severity = 'HIGH' AND status <> 'CLOSED') AS high_severity_findings
    FROM COMERGENCE.AUDIT_FINDING GROUP BY tpo_id
) af ON af.tpo_id = t.tpo_id
LEFT JOIN (
    SELECT tpo_id, COUNT_IF(expires_at <= DATEADD('day',30,CURRENT_DATE())) AS licenses_expiring_30d
    FROM COMERGENCE.NMLS_LICENSE GROUP BY tpo_id
) lic ON lic.tpo_id = t.tpo_id;

-- =====================================================================
-- STEP 3: TPO_PERFORMANCE_V - one row per TPO, both worlds joined
-- =====================================================================

CREATE OR REPLACE VIEW SHARED.TPO_PERFORMANCE_V AS
SELECT
    c.tpo_id,
    c.tpo_name,
    c.state_code,
    c.channel_code,
    c.risk_tier,
    c.status                                AS tpo_status,
    c.open_findings,
    c.high_severity_findings,
    c.licenses_expiring_30d,
    c.compliance_score,
    COALESCE(l.total_locks, 0)              AS total_locks,
    COALESCE(l.funded_locks, 0)             AS funded_locks,
    COALESCE(l.fallout_locks, 0)            AS fallout_locks,
    COALESCE(l.pull_through_pct, 0)         AS pull_through_pct,
    COALESCE(l.fallout_pct, 0)              AS fallout_pct,
    COALESCE(l.funded_volume_usd, 0)        AS funded_volume_usd,
    COALESCE(l.avg_rate_bps, 0)             AS avg_rate_bps,
    COALESCE(l.investor_breadth, 0)         AS investor_breadth
FROM SHARED.TPO_COMPLIANCE_METRICS_V c
LEFT JOIN SHARED.TPO_LOCK_METRICS_V l ON l.tpo_id = c.tpo_id;

-- =====================================================================
-- STEP 4: TPO_SCORECARD_V - the shareable view used by V5 + V6
-- MUST be a SECURE VIEW to be granted on a Snowflake share.
-- Demo talk: "This is exactly what we'll publish to lenders via the
-- Marketplace listing in V5. No PII, just performance + compliance score."
-- =====================================================================

CREATE OR REPLACE SECURE VIEW SHARED.TPO_SCORECARD_V AS
SELECT
    tpo_id,
    state_code,
    channel_code,
    risk_tier,
    compliance_score,
    pull_through_pct,
    fallout_pct,
    funded_locks,
    funded_volume_usd,
    investor_breadth
FROM SHARED.TPO_PERFORMANCE_V;

-- =====================================================================
-- STEP 5: Verification - no fanout, ranges sane
-- =====================================================================
SELECT 'tpo_count_match' AS check_name,
       (SELECT COUNT(*) FROM COMERGENCE.TPO)             AS expected,
       (SELECT COUNT(*) FROM SHARED.TPO_PERFORMANCE_V)   AS actual;

SELECT MIN(compliance_score)  AS min_score,  MAX(compliance_score)  AS max_score,
       MIN(pull_through_pct)  AS min_pt_pct, MAX(pull_through_pct)  AS max_pt_pct,
       MIN(fallout_pct)       AS min_fo_pct, MAX(fallout_pct)       AS max_fo_pct
FROM SHARED.TPO_PERFORMANCE_V;

-- Top 10 high-compliance + high-pull-through TPOs (the "good citizens")
SELECT tpo_id, tpo_name, compliance_score, pull_through_pct, funded_volume_usd
FROM SHARED.TPO_PERFORMANCE_V
WHERE compliance_score >= 90
ORDER BY pull_through_pct DESC, funded_volume_usd DESC
LIMIT 10;
