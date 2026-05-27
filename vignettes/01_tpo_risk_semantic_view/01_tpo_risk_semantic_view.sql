-- *** REFERENCE / FALLBACK ONLY ***
-- Primary demo path: live-generate this SQL from prompt-contract.md in
-- Cortex Code (Snowsight Workspaces), then run that output. This file
-- exists so we can recover quickly if live generation drifts on stage.
-- =====================================================================
-- V1: TPO / Counterparty Risk Semantic View
--
-- Generated from vignettes/01_tpo_risk_semantic_view/prompt-contract.md
-- Run as: OB_DEMO_RW @ OB_DEMO_AI_WH @ OPTIMAL_BLUE_DEMO.AI
--
-- Demo talk: "Cortex Code drafted this entire semantic view from the
-- contract. We'll point Cortex Analyst at it and ask plain-English
-- questions a Comergence analyst asks every day."
-- =====================================================================

USE ROLE OB_DEMO_RW;
USE WAREHOUSE OB_DEMO_AI_WH;
USE DATABASE OPTIMAL_BLUE_DEMO;
USE SCHEMA AI;

-- =====================================================================
-- STEP 1: Pre-aggregate facts so the semantic view stays simple
-- Goal: every metric answerable with one COUNT/SUM/AVG over a fact view.
-- =====================================================================

-- ---------------------------------------------------------------------
-- TPO_FACT: per-TPO counterparty risk fact, refreshed at view time.
-- One row per TPO carrying compliance + onboarding metrics.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW AI.TPO_FACT AS
SELECT
    t.tpo_id,
    t.tpo_name,
    t.state_code,
    s.state_name,
    s.region,
    t.channel_code,
    c.channel_name,
    t.primary_investor_id,
    inv.investor_name,
    t.status        AS tpo_status,
    t.risk_tier,
    t.annual_volume_usd,
    -- audit
    COALESCE(a.open_findings, 0)            AS open_findings,
    COALESCE(a.high_severity_findings, 0)   AS high_severity_findings,
    COALESCE(a.findings_last_90d, 0)        AS findings_last_90d,
    -- exceptions
    COALESCE(e.exception_count, 0)          AS exception_count,
    -- license
    COALESCE(lic.licenses_active, 0)        AS licenses_active,
    COALESCE(lic.licenses_expiring_30d, 0)  AS licenses_expiring_30d,
    COALESCE(lic.licenses_expiring_90d, 0)  AS licenses_expiring_90d,
    -- LOs
    COALESCE(lo.lo_count, 0)                AS lo_count,
    COALESCE(lo.lo_active, 0)               AS lo_active,
    -- onboarding
    onb.days_to_active
FROM COMERGENCE.TPO t
LEFT JOIN COMERGENCE.STATE   s   ON s.state_code  = t.state_code
LEFT JOIN COMERGENCE.CHANNEL c   ON c.channel_code = t.channel_code
LEFT JOIN COMERGENCE.INVESTOR inv ON inv.investor_id = t.primary_investor_id
LEFT JOIN (
    SELECT tpo_id,
           COUNT_IF(status = 'OPEN')                    AS open_findings,
           COUNT_IF(severity = 'HIGH' AND status <> 'CLOSED') AS high_severity_findings,
           COUNT_IF(finding_date >= DATEADD('day',-90,CURRENT_DATE())) AS findings_last_90d
    FROM COMERGENCE.AUDIT_FINDING
    GROUP BY tpo_id
) a ON a.tpo_id = t.tpo_id
LEFT JOIN (
    SELECT tpo_id, COUNT(*) AS exception_count FROM COMERGENCE.EXCEPTION GROUP BY tpo_id
) e ON e.tpo_id = t.tpo_id
LEFT JOIN (
    SELECT tpo_id,
           COUNT_IF(license_status = 'ACTIVE')                                  AS licenses_active,
           COUNT_IF(expires_at <= DATEADD('day',30,CURRENT_DATE()))             AS licenses_expiring_30d,
           COUNT_IF(expires_at <= DATEADD('day',90,CURRENT_DATE()))             AS licenses_expiring_90d
    FROM COMERGENCE.NMLS_LICENSE GROUP BY tpo_id
) lic ON lic.tpo_id = t.tpo_id
LEFT JOIN (
    SELECT tpo_id, COUNT(*) AS lo_count, COUNT_IF(active_flag) AS lo_active
    FROM COMERGENCE.LOAN_OFFICER GROUP BY tpo_id
) lo ON lo.tpo_id = t.tpo_id
LEFT JOIN (
    SELECT tpo_id,
           DATEDIFF('day',
              MIN(CASE WHEN stage='APPLICATION' THEN occurred_at END),
              MAX(CASE WHEN stage='ACTIVE'     THEN occurred_at END)
           ) AS days_to_active
    FROM COMERGENCE.ONBOARDING_EVENT GROUP BY tpo_id
) onb ON onb.tpo_id = t.tpo_id;

-- =====================================================================
-- STEP 2: Semantic view
-- Demo talk: "Synonyms are how Cortex Analyst maps Shawnee's words to
-- our columns. We add 'high-risk', 'expiring license', 'audit hits'."
-- =====================================================================

CREATE OR REPLACE SEMANTIC VIEW AI.TPO_RISK_SV
    TABLES (
        tpo_fact AS AI.TPO_FACT
            PRIMARY KEY (tpo_id)
            WITH SYNONYMS = ('counterparty', 'originator', 'TPO', 'broker')
            COMMENT = 'Per-TPO counterparty risk fact for Comergence oversight'
    )
    DIMENSIONS (
        tpo_fact.tpo_name           AS tpo_name           WITH SYNONYMS = ('counterparty name','originator name'),
        tpo_fact.state_code         AS state_code         WITH SYNONYMS = ('state'),
        tpo_fact.state_name         AS state_name,
        tpo_fact.region             AS region             WITH SYNONYMS = ('US region','geography'),
        tpo_fact.channel_code       AS channel_code,
        tpo_fact.channel_name       AS channel_name       WITH SYNONYMS = ('channel'),
        tpo_fact.primary_investor_id AS primary_investor_id,
        tpo_fact.investor_name      AS investor_name      WITH SYNONYMS = ('primary investor'),
        tpo_fact.tpo_status         AS tpo_status         WITH SYNONYMS = ('status'),
        tpo_fact.risk_tier          AS risk_tier          WITH SYNONYMS = ('risk level','risk band')
    )
    METRICS (
        tpo_fact.tpo_count                  AS COUNT(tpo_fact.tpo_id)
            WITH SYNONYMS = ('number of TPOs','originator count')
            COMMENT = 'Distinct TPO count',
        tpo_fact.active_tpo_count           AS COUNT_IF(tpo_fact.tpo_status = 'ACTIVE')
            WITH SYNONYMS = ('active counterparties'),
        tpo_fact.suspended_tpo_count        AS COUNT_IF(tpo_fact.tpo_status = 'SUSPENDED')
            WITH SYNONYMS = ('suspended TPOs'),
        tpo_fact.high_risk_tpo_count        AS COUNT_IF(tpo_fact.risk_tier = 'HIGH')
            WITH SYNONYMS = ('high risk TPOs'),
        tpo_fact.open_findings              AS SUM(tpo_fact.open_findings)
            WITH SYNONYMS = ('open audit findings','open issues'),
        tpo_fact.high_severity_findings     AS SUM(tpo_fact.high_severity_findings)
            WITH SYNONYMS = ('high severity findings','severe findings'),
        tpo_fact.findings_last_90d          AS SUM(tpo_fact.findings_last_90d)
            WITH SYNONYMS = ('recent findings','findings in last 90 days'),
        tpo_fact.exception_count            AS SUM(tpo_fact.exception_count)
            WITH SYNONYMS = ('exceptions raised'),
        tpo_fact.licenses_expiring_30d      AS SUM(tpo_fact.licenses_expiring_30d)
            WITH SYNONYMS = ('licenses expiring in 30 days'),
        tpo_fact.licenses_expiring_90d      AS SUM(tpo_fact.licenses_expiring_90d)
            WITH SYNONYMS = ('licenses expiring in 90 days'),
        tpo_fact.lo_active                  AS SUM(tpo_fact.lo_active)
            WITH SYNONYMS = ('active loan officers','active LOs'),
        tpo_fact.avg_days_to_active         AS AVG(tpo_fact.days_to_active)
            WITH SYNONYMS = ('average onboarding days','avg time to active'),
        tpo_fact.total_annual_volume        AS SUM(tpo_fact.annual_volume_usd)
            WITH SYNONYMS = ('total volume','origination volume')
    )
    COMMENT = 'Comergence counterparty (TPO) risk semantic view - powers Cortex Analyst, V3 agent, V6 dashboard';

-- =====================================================================
-- STEP 3: Smoke test
-- =====================================================================
SELECT * FROM SEMANTIC_VIEW(
    AI.TPO_RISK_SV
    DIMENSIONS region, risk_tier
    METRICS    tpo_count, open_findings, licenses_expiring_30d
)
ORDER BY region, risk_tier;
