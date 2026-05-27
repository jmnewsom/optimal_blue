-- =====================================================================
-- 03_load_unstructured.sql
-- Synthetic compliance documents -> chunked text table for V2 search.
--
-- Real demos can also PUT actual PDFs to @STAGES.COMPLIANCE_DOCS and
-- call AI_PARSE_DOCUMENT. For repeatability we simulate parsed text
-- inline so the demo regenerates without external file dependencies.
-- After the demo, swap the inline INSERT for an AI_PARSE_DOCUMENT call.
-- =====================================================================

USE ROLE OB_DEMO_RW;
USE WAREHOUSE OB_DEMO_AI_WH;
USE DATABASE OPTIMAL_BLUE_DEMO;
USE SCHEMA COMERGENCE;

-- ---------------------------------------------------------------------
-- Document master (~100 docs across guidelines, audit reports, NMLS)
-- Goal: source corpus for V2 Cortex Search service AI.COMPLIANCE_CSS.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE COMERGENCE.COMPLIANCE_DOCUMENT (
    doc_id        NUMBER(38,0) PRIMARY KEY,
    doc_type      VARCHAR(32)  NOT NULL,    -- GUIDELINE / AUDIT_REPORT / NMLS_FILING / POLICY
    investor_id   NUMBER(38,0),
    tpo_id        NUMBER(38,0),
    title         VARCHAR(256) NOT NULL,
    published_at  DATE         NOT NULL,
    source_path   VARCHAR(512)
);

INSERT INTO COMERGENCE.COMPLIANCE_DOCUMENT
WITH base AS (SELECT SEQ8() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 100)))
SELECT
    n,
    DECODE(MOD(n,4),0,'GUIDELINE',1,'AUDIT_REPORT',
                    2,'NMLS_FILING','POLICY')                AS doc_type,
    CASE WHEN MOD(n,4) IN (0,3) THEN 1 + MOD(n,125) ELSE NULL END AS investor_id,
    CASE WHEN MOD(n,4) IN (1,2) THEN 1 + MOD(HASH(n),22000) ELSE NULL END AS tpo_id,
    CASE MOD(n,4)
        WHEN 0 THEN 'Investor '||LPAD(1+MOD(n,125),3,'0')||' FHA Overlay Guidelines v'||(1+MOD(n,5))
        WHEN 1 THEN 'Annual Audit Report - TPO '||LPAD(1+MOD(HASH(n),22000),5,'0')
        WHEN 2 THEN 'NMLS Consumer Access Filing #'||(50000+n)
        ELSE        'Optimal Blue Compliance Policy '||LPAD(n,3,'0')
    END                                                       AS title,
    DATEADD('day', -UNIFORM(0, 720, RANDOM(n)), CURRENT_DATE()) AS published_at,
    '@OPTIMAL_BLUE_DEMO.STAGES.COMPLIANCE_DOCS/doc_'||LPAD(n,4,'0')||'.pdf' AS source_path
FROM base;

-- ---------------------------------------------------------------------
-- Chunked text. In production we would chunk the output of
-- AI_PARSE_DOCUMENT(@stage/file.pdf). Here we synthesize realistic
-- compliance prose so V2 Cortex Search has substantive content.
-- Each doc gets 5-12 chunks.
-- ---------------------------------------------------------------------
-- ---------------------------------------------------------------------
-- Chunked text. In production we would chunk the output of
-- AI_PARSE_DOCUMENT(@stage/file.pdf). Here we synthesize realistic
-- compliance prose so V2 Cortex Search has substantive content.
-- Each doc gets 8 chunks (~800 rows total).
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE COMERGENCE.COMPLIANCE_DOC_CHUNK (
    chunk_id    NUMBER(38,0) PRIMARY KEY,
    doc_id      NUMBER(38,0) NOT NULL,
    chunk_index NUMBER(10)   NOT NULL,
    chunk_text  VARCHAR(4000) NOT NULL,
    doc_type    VARCHAR(32),
    title       VARCHAR(256),
    investor_id NUMBER(38,0),
    tpo_id      NUMBER(38,0),
    published_at DATE
);

INSERT INTO COMERGENCE.COMPLIANCE_DOC_CHUNK
WITH chunk_idx AS (
    SELECT SEQ8() AS chunk_index FROM TABLE(GENERATOR(ROWCOUNT => 8))
),
templates AS (
    SELECT col AS body, idx FROM (VALUES
        ('FHA loans must comply with HUD 4000.1 chapter II. Minimum credit score 580 with 3.5% down. '
         'Maximum DTI 43% unless compensating factors. Manual underwrite required for scores 500-579.', 1),
        ('Investor overlay: borrower bankruptcy seasoning at least 24 months from discharge. '
         'Foreclosure seasoning 36 months. Short sale 24 months with re-established credit.', 2),
        ('VA loans require Certificate of Eligibility. Funding fee waived for veterans with 10%+ disability. '
         'Cash-out refi capped at 90% LTV per VA Circular 26-19-05.', 3),
        ('Audit finding: TPO failed to retain advertising disclosures for 90 days. '
         'Remediation: implement ad archive workflow within 30 days. Severity HIGH.', 4),
        ('NMLS Consumer Access record reviewed; no public disciplinary actions. '
         'Annual MU2 renewal due in 60 days. Continuing education credits current.', 5),
        ('Social media policy: all loan officer posts referring to rates must include APR disclosure '
         'within the same post or thread. Use of "guaranteed" is prohibited per Reg Z.', 6),
        ('Counterparty oversight requires quarterly financial review including audited statements, '
         'minimum tangible net worth $1M for non-delegated correspondents.', 7),
        ('Fair lending: HMDA reporting must include disaggregated demographic data per the 2015 rule. '
         'Disparate-impact monitoring on pricing exceptions reviewed monthly.', 8),
        ('Best execution: investor pricing compared at 9am, 11am, 2pm. Lender must document rationale '
         'for any deviation greater than 12.5 bps from best price tier.', 9),
        ('Solution Center listings require completed compliance package, NMLS verification, '
         'and signed counterparty agreement before activation.', 10),
        ('Compliance management system shall reflect this policy within 30 days of publication. '
         'Failure to acknowledge will result in suspended status until acknowledgement is received.', 11),
        ('BSA/AML: Currency Transaction Reports filed for cash dealings >$10K. '
         'Suspicious Activity Reports filed within 30 days of detection. Annual training required.', 12)
    ) v(col, idx)
)
SELECT
    ROW_NUMBER() OVER (ORDER BY d.doc_id, c.chunk_index) AS chunk_id,
    d.doc_id,
    c.chunk_index,
    'Section '||(c.chunk_index+1)||' of '||d.title||' - '||t.body AS chunk_text,
    d.doc_type,
    d.title,
    d.investor_id,
    d.tpo_id,
    d.published_at
FROM COMERGENCE.COMPLIANCE_DOCUMENT d
CROSS JOIN chunk_idx c
JOIN templates t ON t.idx = 1 + MOD(ABS(HASH(d.doc_id, c.chunk_index)), 12);

-- =====================================================================
-- Validation
-- =====================================================================
SELECT 'COMPLIANCE_DOCUMENT' AS tbl, COUNT(*) FROM COMERGENCE.COMPLIANCE_DOCUMENT
UNION ALL SELECT 'COMPLIANCE_DOC_CHUNK', COUNT(*) FROM COMERGENCE.COMPLIANCE_DOC_CHUNK;
