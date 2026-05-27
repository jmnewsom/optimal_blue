-- =====================================================================
-- 02_synthetic_ppe.sql
-- PPE-side synthetic data: products, rate sheets, locks, fallout.
-- This is the cross-org bridge: every TPO in COMERGENCE.TPO can appear
-- here as a lock counterparty, enabling V4 (TPO performance + lock
-- pull-through) and V5 (Marketplace scorecard).
-- =====================================================================

USE ROLE OB_DEMO_RW;
USE WAREHOUSE OB_DEMO_AI_WH;
USE DATABASE OPTIMAL_BLUE_DEMO;
USE SCHEMA PPE;

-- =====================================================================
-- STEP 1: Product catalog (small dim - 12 standard product codes)
-- =====================================================================

CREATE OR REPLACE TABLE PPE.PRODUCT (
    product_code VARCHAR(16) PRIMARY KEY,
    product_name VARCHAR(64),
    loan_type    VARCHAR(16),
    term_months  NUMBER(6)
);

INSERT INTO PPE.PRODUCT VALUES
 ('CONV30','Conventional 30Yr Fixed','CONV',360),
 ('CONV15','Conventional 15Yr Fixed','CONV',180),
 ('CONV20','Conventional 20Yr Fixed','CONV',240),
 ('FHA30','FHA 30Yr Fixed','FHA',360),
 ('FHA15','FHA 15Yr Fixed','FHA',180),
 ('VA30','VA 30Yr Fixed','VA',360),
 ('USDA30','USDA 30Yr Fixed','USDA',360),
 ('JUMBO30','Jumbo 30Yr Fixed','JUMBO',360),
 ('JUMBO15','Jumbo 15Yr Fixed','JUMBO',180),
 ('ARM5_1','5/1 ARM','CONV',360),
 ('ARM7_1','7/1 ARM','CONV',360),
 ('NONQM30','Non-QM 30Yr','NONQM',360);

-- =====================================================================
-- STEP 2: Rate sheets (~200K rows - one per investor x product x day)
-- Demo talk: "This is a daily rate-sheet feed. Today many lenders FTP
-- this; in Snowflake it's a governed table everyone shares."
-- =====================================================================

CREATE OR REPLACE TABLE PPE.RATE_SHEET (
    rate_sheet_id NUMBER(38,0) PRIMARY KEY,
    investor_id   NUMBER(38,0) NOT NULL,
    product_code  VARCHAR(16)  NOT NULL,
    quote_date    DATE         NOT NULL,
    base_rate_bps NUMBER(10,2) NOT NULL,
    margin_bps    NUMBER(10,2) NOT NULL,
    eligibility   VARCHAR(32)
);

INSERT INTO PPE.RATE_SHEET
WITH base AS (
    SELECT SEQ8() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 200000))
),
numbered_products AS (
    SELECT product_code, ROW_NUMBER() OVER (ORDER BY product_code) - 1 AS idx
    FROM PPE.PRODUCT
)
SELECT
    b.n                                                         AS rate_sheet_id,
    1 + MOD(HASH(b.n,'inv'), 125)                               AS investor_id,
    np.product_code,
    DATEADD('day', -MOD(b.n, 365), CURRENT_DATE())              AS quote_date,
    UNIFORM(550, 825, RANDOM())                                 AS base_rate_bps,
    UNIFORM(50, 250, RANDOM())                                  AS margin_bps,
    DECODE(MOD(b.n,5),0,'PRIME',1,'NEAR_PRIME',
                    2,'GOV',3,'JUMBO','SPECIALTY')              AS eligibility
FROM base b
JOIN numbered_products np ON np.idx = MOD(ABS(HASH(b.n,'pc')), 12);

-- =====================================================================
-- STEP 3: Locks (~500K) - a lock is a TPO-driven commitment to a
-- specific rate/product/investor. This is the cross-org join key.
-- Goal: power V4 pull-through metrics joined back to COMERGENCE.TPO.
-- =====================================================================

CREATE OR REPLACE TABLE PPE.LOCK (
    lock_id        NUMBER(38,0) PRIMARY KEY,
    tpo_id         NUMBER(38,0) NOT NULL,
    investor_id    NUMBER(38,0) NOT NULL,
    product_code   VARCHAR(16)  NOT NULL,
    locked_at      TIMESTAMP_NTZ NOT NULL,
    note_amount    NUMBER(38,2) NOT NULL,
    rate_bps       NUMBER(10,2) NOT NULL,
    lock_status    VARCHAR(16)  NOT NULL,  -- LOCKED / FUNDED / FALLOUT
    funded_at      TIMESTAMP_NTZ,
    fallout_reason VARCHAR(64)
);

INSERT INTO PPE.LOCK
WITH base AS (
    SELECT SEQ8() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 500000))
),
numbered_products AS (
    SELECT product_code, ROW_NUMBER() OVER (ORDER BY product_code) - 1 AS idx
    FROM PPE.PRODUCT
)
SELECT
    b.n                                                          AS lock_id,
    1 + MOD(HASH(b.n,'tpo_l'), 22000)                            AS tpo_id,
    1 + MOD(HASH(b.n,'inv_l'), 125)                              AS investor_id,
    np.product_code,
    DATEADD('hour', -UNIFORM(0, 8760, RANDOM()),
            CURRENT_TIMESTAMP())                                 AS locked_at,
    ROUND(UNIFORM(75000, 1500000, RANDOM()), 2)                  AS note_amount,
    UNIFORM(550, 850, RANDOM())                                  AS rate_bps,
    -- ~75% funded, ~18% locked-in-flight, ~7% fallout
    CASE WHEN UNIFORM(0,99,RANDOM()) < 75 THEN 'FUNDED'
         WHEN UNIFORM(0,99,RANDOM()) < 93 THEN 'LOCKED'
         ELSE 'FALLOUT' END                                      AS lock_status,
    CASE WHEN UNIFORM(0,99,RANDOM()) < 75
         THEN DATEADD('day', UNIFORM(15, 60, RANDOM()),
                       DATEADD('hour', -UNIFORM(0, 8760, RANDOM()),
                               CURRENT_TIMESTAMP()))
         ELSE NULL END                                            AS funded_at,
    CASE WHEN UNIFORM(0,99,RANDOM()) >= 93
         THEN DECODE(MOD(b.n,5),0,'BORROWER_WITHDREW',
                              1,'CREDIT_DECLINE',
                              2,'APPRAISAL_LOW',
                              3,'INVESTOR_INELIGIBLE','RATE_RENEGOTIATED')
         ELSE NULL END                                            AS fallout_reason
FROM base b
JOIN numbered_products np ON np.idx = MOD(ABS(HASH(b.n,'pc_l')), 12);

-- =====================================================================
-- STEP 4: Validation
-- =====================================================================
SELECT 'PRODUCT'    AS tbl, COUNT(*) FROM PPE.PRODUCT
UNION ALL SELECT 'RATE_SHEET',  COUNT(*) FROM PPE.RATE_SHEET
UNION ALL SELECT 'LOCK',        COUNT(*) FROM PPE.LOCK;
