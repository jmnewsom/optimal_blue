-- =====================================================================
-- 01_synthetic_comergence.sql
-- Synthetic Comergence-side data: TPOs, LOs, NMLS, audits, exceptions,
-- onboarding events, social media posts.
--
-- Generated from infrastructure/prompt-contract.md
-- Idempotent: CREATE OR REPLACE on every table.
-- Deterministic: SEED set so demo state regenerates identically.
-- Medium scale (~22K TPOs, ~100K LOs, ~250K audits, ~50K social posts).
-- =====================================================================

USE ROLE OB_DEMO_RW;
USE WAREHOUSE OB_DEMO_AI_WH;
USE DATABASE OPTIMAL_BLUE_DEMO;
USE SCHEMA COMERGENCE;

-- =====================================================================
-- STEP 1: Reference dimensions (states, channels, investors, products)
-- Demo talk: "Tiny lookups, but they shape the realism of every metric."
-- =====================================================================

-- ---------------------------------------------------------------------
-- US state lookup (50 states + DC). Used as TPO + LO domicile.
-- Goal: dimension for V1 semantic view (geo slicing).
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE COMERGENCE.STATE (
    state_code  VARCHAR(2)  PRIMARY KEY,
    state_name  VARCHAR(64) NOT NULL,
    region      VARCHAR(16) NOT NULL
);

INSERT INTO COMERGENCE.STATE VALUES
('AL','Alabama','South'),('AK','Alaska','West'),('AZ','Arizona','West'),
('AR','Arkansas','South'),('CA','California','West'),('CO','Colorado','West'),
('CT','Connecticut','Northeast'),('DE','Delaware','South'),('FL','Florida','South'),
('GA','Georgia','South'),('HI','Hawaii','West'),('ID','Idaho','West'),
('IL','Illinois','Midwest'),('IN','Indiana','Midwest'),('IA','Iowa','Midwest'),
('KS','Kansas','Midwest'),('KY','Kentucky','South'),('LA','Louisiana','South'),
('ME','Maine','Northeast'),('MD','Maryland','South'),('MA','Massachusetts','Northeast'),
('MI','Michigan','Midwest'),('MN','Minnesota','Midwest'),('MS','Mississippi','South'),
('MO','Missouri','Midwest'),('MT','Montana','West'),('NE','Nebraska','Midwest'),
('NV','Nevada','West'),('NH','New Hampshire','Northeast'),('NJ','New Jersey','Northeast'),
('NM','New Mexico','West'),('NY','New York','Northeast'),('NC','North Carolina','South'),
('ND','North Dakota','Midwest'),('OH','Ohio','Midwest'),('OK','Oklahoma','South'),
('OR','Oregon','West'),('PA','Pennsylvania','Northeast'),('RI','Rhode Island','Northeast'),
('SC','South Carolina','South'),('SD','South Dakota','Midwest'),('TN','Tennessee','South'),
('TX','Texas','South'),('UT','Utah','West'),('VT','Vermont','Northeast'),
('VA','Virginia','South'),('WA','Washington','West'),('WV','West Virginia','South'),
('WI','Wisconsin','Midwest'),('WY','Wyoming','West'),('DC','District of Columbia','South');

-- ---------------------------------------------------------------------
-- Channel and investor lookups - drive V4 cross-org bridge dimensions.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE COMERGENCE.CHANNEL (
    channel_code VARCHAR(16) PRIMARY KEY,
    channel_name VARCHAR(64)
);
INSERT INTO COMERGENCE.CHANNEL VALUES
 ('WHOLESALE','Wholesale'),('CORRESPONDENT','Correspondent'),
 ('NON_DELEGATED','Non-Delegated Correspondent'),('RETAIL','Retail');

CREATE OR REPLACE TABLE COMERGENCE.INVESTOR (
    investor_id   NUMBER(38,0) PRIMARY KEY,
    investor_name VARCHAR(128) NOT NULL,
    tier          VARCHAR(16)  NOT NULL,
    active_flag   BOOLEAN      DEFAULT TRUE
);
INSERT INTO COMERGENCE.INVESTOR
SELECT
    SEQ8() + 1                                   AS investor_id,
    'Investor '||LPAD(SEQ8()+1, 3, '0')          AS investor_name,
    CASE MOD(SEQ8(),4) WHEN 0 THEN 'Tier-1'
                       WHEN 1 THEN 'Tier-2'
                       WHEN 2 THEN 'Tier-3'
                       ELSE 'Niche' END          AS tier,
    TRUE                                         AS active_flag
FROM TABLE(GENERATOR(ROWCOUNT => 125));

-- =====================================================================
-- STEP 2: TPO master entity (~22,000 third-party originators)
-- Goal: foundation for V1 semantic view + V4 cross-org bridge.
-- Demo talk: "This is what 22,000 originators looks like in one place,
-- pre-classified, pre-tagged, ready for governed sharing."
-- =====================================================================

CREATE OR REPLACE TABLE COMERGENCE.TPO (
    tpo_id              NUMBER(38,0) NOT NULL,
    tpo_name            VARCHAR(128) NOT NULL,
    nmls_id             NUMBER(38,0) NOT NULL,
    state_code          VARCHAR(2)   NOT NULL,
    channel_code        VARCHAR(16)  NOT NULL,
    primary_investor_id NUMBER(38,0),
    onboarded_at        TIMESTAMP_NTZ NOT NULL,
    status              VARCHAR(24)  NOT NULL,
    risk_tier           VARCHAR(8)   NOT NULL,
    annual_volume_usd   NUMBER(38,2) NOT NULL,
    PRIMARY KEY (tpo_id)
);

INSERT INTO COMERGENCE.TPO
WITH seed AS (
    SELECT SEQ8() + 1 AS n
    FROM TABLE(GENERATOR(ROWCOUNT => 22000))
),
numbered_states AS (
    SELECT state_code, ROW_NUMBER() OVER (ORDER BY state_code) - 1 AS idx
    FROM COMERGENCE.STATE
)
SELECT
    s.n                                               AS tpo_id,
    'TPO '||LPAD(s.n,5,'0')||' '||
       DECODE(MOD(s.n,8),0,'Lending',1,'Mortgage',2,'Capital',3,'Home Loans',
              4,'Funding',5,'Financial',6,'Bancorp','Direct')      AS tpo_name,
    1000000 + s.n                                     AS nmls_id,
    ns.state_code                                    AS state_code,
    DECODE(MOD(s.n,4),0,'WHOLESALE',1,'CORRESPONDENT',
                    2,'NON_DELEGATED','RETAIL')     AS channel_code,
    1 + MOD(s.n,125)                                  AS primary_investor_id,
    DATEADD('day', -UNIFORM(30, 1800, RANDOM()),
            CURRENT_TIMESTAMP())                    AS onboarded_at,
    DECODE(MOD(s.n,20),
        0,'SUSPENDED', 1,'PROBATION',
        2,'ONBOARDING',3,'ONBOARDING',
        'ACTIVE')                                   AS status,
    -- Weighted risk: ~70% LOW, 22% MED, 8% HIGH
    CASE WHEN UNIFORM(0,99,RANDOM()) < 8  THEN 'HIGH'
         WHEN UNIFORM(0,99,RANDOM()) < 30 THEN 'MED'
         ELSE 'LOW' END                             AS risk_tier,
    ROUND(UNIFORM(2000000, 800000000, RANDOM()),2) AS annual_volume_usd
FROM seed s
JOIN numbered_states ns ON ns.idx = MOD(ABS(HASH(s.n, 'state')), 51);

-- =====================================================================
-- STEP 3: Loan officers (~100K, weighted by TPO size)
-- Demo talk: "Each TPO has 1-12 LOs; each is independently NMLS-tracked."
-- =====================================================================

CREATE OR REPLACE TABLE COMERGENCE.LOAN_OFFICER (
    lo_id        NUMBER(38,0) PRIMARY KEY,
    tpo_id       NUMBER(38,0) NOT NULL,
    lo_name      VARCHAR(128) NOT NULL,
    nmls_id      NUMBER(38,0) NOT NULL,
    state_code   VARCHAR(2)   NOT NULL,
    active_flag  BOOLEAN      NOT NULL
);

INSERT INTO COMERGENCE.LOAN_OFFICER
WITH lo_base AS (
    SELECT SEQ8() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 100000))
),
numbered_states AS (
    SELECT state_code, ROW_NUMBER() OVER (ORDER BY state_code) - 1 AS idx
    FROM COMERGENCE.STATE
)
SELECT
    b.n                                                    AS lo_id,
    1 + MOD(HASH(b.n, 'tpo'), 22000)                       AS tpo_id,
    'LO '||LPAD(b.n,6,'0')                                 AS lo_name,
    9000000 + b.n                                          AS nmls_id,
    ns.state_code                                          AS state_code,
    CASE WHEN UNIFORM(0,99,RANDOM()) < 90 THEN TRUE ELSE FALSE END AS active_flag
FROM lo_base b
JOIN numbered_states ns ON ns.idx = MOD(ABS(HASH(b.n,'st')), 51);

-- =====================================================================
-- STEP 4: NMLS license records (one per TPO + multi-state expansions)
-- Goal: power "license expiring soon" metric in V1 + V3 agent.
-- =====================================================================

CREATE OR REPLACE TABLE COMERGENCE.NMLS_LICENSE (
    license_id      NUMBER(38,0) PRIMARY KEY,
    tpo_id          NUMBER(38,0) NOT NULL,
    state_code      VARCHAR(2)   NOT NULL,
    license_type    VARCHAR(32)  NOT NULL,
    issued_at       DATE         NOT NULL,
    expires_at      DATE         NOT NULL,
    license_status  VARCHAR(16)  NOT NULL
);

INSERT INTO COMERGENCE.NMLS_LICENSE
WITH base AS (
    SELECT SEQ8() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 60000))
),
numbered_states AS (
    SELECT state_code, ROW_NUMBER() OVER (ORDER BY state_code) - 1 AS idx
    FROM COMERGENCE.STATE
)
SELECT
    b.n                                              AS license_id,
    1 + MOD(HASH(b.n,'tpo'), 22000)                  AS tpo_id,
    ns.state_code                                    AS state_code,
    DECODE(MOD(b.n,3),0,'Mortgage Broker',
                    1,'Mortgage Lender','Servicer')  AS license_type,
    DATEADD('day', -UNIFORM(30, 2200, RANDOM()),
            CURRENT_DATE())                          AS issued_at,
    -- ~6% expiring within 30 days, 12% within 90, rest >180 days out
    DATEADD('day',
            CASE WHEN UNIFORM(0,99,RANDOM()) < 6  THEN UNIFORM(1, 30, RANDOM())
                 WHEN UNIFORM(0,99,RANDOM()) < 18 THEN UNIFORM(31, 90, RANDOM())
                 ELSE UNIFORM(180, 720, RANDOM()) END,
            CURRENT_DATE())                          AS expires_at,
    DECODE(MOD(b.n,25),0,'SUSPENDED',1,'PENDING','ACTIVE') AS license_status
FROM base b
JOIN numbered_states ns ON ns.idx = MOD(ABS(HASH(b.n,'lic_st')), 51);

-- =====================================================================
-- STEP 5: Audit findings (~250K) + exceptions (~40K)
-- Goal: density of findings drives V1 metrics + V3 agent narratives.
-- =====================================================================

CREATE OR REPLACE TABLE COMERGENCE.AUDIT_FINDING (
    finding_id      NUMBER(38,0) PRIMARY KEY,
    tpo_id          NUMBER(38,0) NOT NULL,
    finding_date    DATE         NOT NULL,
    severity        VARCHAR(8)   NOT NULL,
    category        VARCHAR(32)  NOT NULL,
    finding_text    VARCHAR(1024),
    status          VARCHAR(16)  NOT NULL,
    closed_date     DATE
);

INSERT INTO COMERGENCE.AUDIT_FINDING
WITH base AS (
    SELECT SEQ8() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 250000))
)
SELECT
    n                                                AS finding_id,
    1 + MOD(HASH(n,'tpo_f'), 22000)                  AS tpo_id,
    DATEADD('day', -UNIFORM(0, 720, RANDOM()),
            CURRENT_DATE())                          AS finding_date,
    CASE WHEN UNIFORM(0,99,RANDOM()) < 8  THEN 'HIGH'
         WHEN UNIFORM(0,99,RANDOM()) < 30 THEN 'MED'
         ELSE 'LOW' END                              AS severity,
    DECODE(MOD(n,7),
        0,'LICENSING',1,'COMPLIANCE',2,'SOCIAL_MEDIA',
        3,'DOCUMENTATION',4,'FAIR_LENDING',
        5,'CONSUMER_COMPLAINT','BSA_AML')            AS category,
    'Auto-generated audit finding ' || n             AS finding_text,
    CASE WHEN UNIFORM(0,99,RANDOM()) < 70 THEN 'CLOSED'
         WHEN UNIFORM(0,99,RANDOM()) < 90 THEN 'IN_REMEDIATION'
         ELSE 'OPEN' END                             AS status,
    CASE WHEN MOD(n,7) <> 0
         THEN DATEADD('day', UNIFORM(1, 90, RANDOM()),
                       DATEADD('day', -UNIFORM(0, 720, RANDOM()), CURRENT_DATE()))
         ELSE NULL END                               AS closed_date
FROM base;

CREATE OR REPLACE TABLE COMERGENCE.EXCEPTION (
    exception_id   NUMBER(38,0) PRIMARY KEY,
    tpo_id         NUMBER(38,0) NOT NULL,
    raised_at      TIMESTAMP_NTZ NOT NULL,
    exception_type VARCHAR(32) NOT NULL,
    rationale      VARCHAR(512),
    approved_flag  BOOLEAN
);

INSERT INTO COMERGENCE.EXCEPTION
WITH base AS (
    SELECT SEQ8() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 40000))
)
SELECT
    n,
    1 + MOD(HASH(n,'tpo_e'), 22000),
    DATEADD('hour', -UNIFORM(0, 17000, RANDOM()), CURRENT_TIMESTAMP()),
    DECODE(MOD(n,5),0,'PRICING',1,'ELIGIBILITY',2,'CREDIT',
                    3,'LICENSING','DOCUMENTATION'),
    'Exception rationale ' || n,
    UNIFORM(0,1,RANDOM())::BOOLEAN
FROM base;

-- =====================================================================
-- STEP 6: Onboarding events (TPO -> active)
-- Goal: power onboarding-funnel metric in V1 + V6 dashboard.
-- =====================================================================

CREATE OR REPLACE TABLE COMERGENCE.ONBOARDING_EVENT (
    event_id    NUMBER(38,0) PRIMARY KEY,
    tpo_id      NUMBER(38,0) NOT NULL,
    stage       VARCHAR(32)  NOT NULL,
    occurred_at TIMESTAMP_NTZ NOT NULL,
    duration_days NUMBER(10,2)
);

INSERT INTO COMERGENCE.ONBOARDING_EVENT
WITH stages AS (
    SELECT col AS stage, idx AS ord FROM (VALUES
        ('APPLICATION', 1), ('NMLS_VERIFY', 2), ('FINANCIAL_REVIEW', 3),
        ('COMPLIANCE_REVIEW', 4), ('ACTIVE', 5)
    ) v(col, idx)
)
SELECT
    ROW_NUMBER() OVER (ORDER BY t.tpo_id, s.ord)        AS event_id,
    t.tpo_id,
    s.stage,
    DATEADD('day', s.ord * UNIFORM(2, 8, RANDOM()),
            t.onboarded_at)                             AS occurred_at,
    UNIFORM(1, 14, RANDOM())            AS duration_days
FROM COMERGENCE.TPO t
CROSS JOIN stages s;

-- =====================================================================
-- STEP 7: Social media posts (~50K) - source for AISQL classification
-- in V2 (compliance flags via AI_CLASSIFY + AI_SENTIMENT).
-- =====================================================================

CREATE OR REPLACE TABLE COMERGENCE.SOCIAL_POST (
    post_id      NUMBER(38,0) PRIMARY KEY,
    tpo_id       NUMBER(38,0) NOT NULL,
    lo_id        NUMBER(38,0),
    platform     VARCHAR(16) NOT NULL,
    posted_at    TIMESTAMP_NTZ NOT NULL,
    post_text    VARCHAR(2048) NOT NULL,
    public_url   VARCHAR(512)
);

INSERT INTO COMERGENCE.SOCIAL_POST
WITH base AS (
    SELECT SEQ8() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 50000))
),
samples AS (
    SELECT col AS sample_text, idx FROM (VALUES
        ('Big rate drop today, lock in 30-yr fixed at unbeatable pricing!', 1),
        ('Guaranteed lowest rate in town - call me before anyone else.',     2),
        ('We promise approval even with bad credit, no docs needed!',        3),
        ('FHA loans available for first-time buyers - call to learn more.',  4),
        ('Refi season is here, save thousands on your monthly payment.',     5),
        ('Free appraisal when you close with us this month.',                6),
        ('Reach out for a personalized rate quote tailored to your needs.',  7),
        ('No income verification mortgages still available, message me.',    8),
        ('Helped a family close their dream home today, congrats!',          9),
        ('Markets moved 25 bps - here is what it means for your purchase.',  10)
    ) v(col, idx)
)
SELECT
    b.n                                                     AS post_id,
    1 + MOD(HASH(b.n,'tpo_s'), 22000)                       AS tpo_id,
    1 + MOD(HASH(b.n,'lo_s'), 100000)                       AS lo_id,
    DECODE(MOD(b.n,4),0,'LINKEDIN',1,'FACEBOOK',2,'X','INSTAGRAM') AS platform,
    DATEADD('hour', -UNIFORM(0, 4400, RANDOM()), CURRENT_TIMESTAMP()),
    s.sample_text                                           AS post_text,
    'https://example.com/post/' || b.n                      AS public_url
FROM base b
JOIN samples s ON s.idx = 1 + MOD(ABS(HASH(b.n,'st')),10);

-- =====================================================================
-- STEP 8: Validation
-- =====================================================================
SELECT 'TPO'             AS tbl, COUNT(*) FROM COMERGENCE.TPO
UNION ALL SELECT 'LOAN_OFFICER',     COUNT(*) FROM COMERGENCE.LOAN_OFFICER
UNION ALL SELECT 'NMLS_LICENSE',     COUNT(*) FROM COMERGENCE.NMLS_LICENSE
UNION ALL SELECT 'AUDIT_FINDING',    COUNT(*) FROM COMERGENCE.AUDIT_FINDING
UNION ALL SELECT 'EXCEPTION',        COUNT(*) FROM COMERGENCE.EXCEPTION
UNION ALL SELECT 'ONBOARDING_EVENT', COUNT(*) FROM COMERGENCE.ONBOARDING_EVENT
UNION ALL SELECT 'SOCIAL_POST',      COUNT(*) FROM COMERGENCE.SOCIAL_POST;
