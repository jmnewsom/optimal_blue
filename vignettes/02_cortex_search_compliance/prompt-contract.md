---
id: 02_cortex_search_compliance
inherits: ../../infrastructure/prompt-contract.md
depends_on: [infrastructure]
role: OB_DEMO_RW
warehouse: OB_DEMO_AI_WH
database: OPTIMAL_BLUE_DEMO
schema: AI
output_files: [02_compliance_search_and_aisql.sql, sample_queries.md]
est_runtime_min: 4
cortex_code_skills: [search-optimization, document-intelligence]
---

# V2 - Cortex Search + AISQL on Compliance Docs & Social Media

## Goal
Index Comergence's compliance corpus (investor guidelines, audit reports,
NMLS filings, policies) into a Cortex Search service AND classify the
~50K social media posts via AI_CLASSIFY + AI_SENTIMENT to produce a
materialized "social compliance flag" table.

## Business context
This vignette directly addresses Shawnee's stated wishes:
- "Let customers query financial documents directly through their system"
- "Modernize ad-hoc Excel review of guidelines and audit reports"
- Comergence's Social Media Compliance product becomes AI-powered.

## Inputs (FQNs)
- `COMERGENCE.COMPLIANCE_DOC_CHUNK` (text corpus)
- `COMERGENCE.SOCIAL_POST` (posts to classify)

## Deliverables
- `OPTIMAL_BLUE_DEMO.AI.COMPLIANCE_CSS` - Cortex Search service
- `OPTIMAL_BLUE_DEMO.COMERGENCE.SOCIAL_FLAG` - materialized AI labels
- `vignettes/02_cortex_search_compliance/sample_queries.md`

## Acceptance criteria
- Cortex Search service answers 5 sample queries with >=2 relevant chunks each.
- `SOCIAL_FLAG` table has ~5,000 rows (sampled from 50K SOCIAL_POST) including `topic`, `sentiment`, `compliance_risk` for every input post.
- AISQL materialization runtime <= 90 seconds on `OB_DEMO_AI_WH` (Medium).
- Service refresh lag <= 5 minutes.

## Cortex Code talk track (live demo - 5-block runbook)

### 1. Setup
- Active role: `OB_DEMO_RW`
- Active warehouse: `OB_DEMO_AI_WH`
- DB=OPTIMAL_BLUE_DEMO; schema set per step (AI for CSS, COMERGENCE for SOCIAL_FLAG)

### 2. Prompt to paste verbatim
> @vignettes/02_cortex_search_compliance/prompt-contract.md
> Use the `search-optimization` and `document-intelligence` skills.
> Generate the SQL exactly per this contract into a file named
> `02_compliance_search_and_aisql.sql`. Include CREATE CORTEX SEARCH
> SERVICE AI.COMPLIANCE_CSS over COMPLIANCE_DOC_CHUNK, then a CREATE
> OR REPLACE TABLE COMERGENCE.SOCIAL_FLAG using AI_CLASSIFY +
> AI_SENTIMENT, plus smoke-test queries.

### 3. Expected output
- File `02_compliance_search_and_aisql.sql`, ~80 lines
- `CREATE OR REPLACE CORTEX SEARCH SERVICE AI.COMPLIANCE_CSS ON chunk_text ...`
- `CREATE OR REPLACE TABLE COMERGENCE.SOCIAL_FLAG AS SELECT ... AI_CLASSIFY ... AI_SENTIMENT ...`
- Two smoke tests (search preview + flag distribution)

### 4. Verify after running
```sql
-- search returns relevant chunks
SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
  'OPTIMAL_BLUE_DEMO.AI.COMPLIANCE_CSS',
  '{"query":"FHA overlay credit score","limit":3}'));

-- AISQL flags populated
SELECT compliance_risk, COUNT(*) FROM COMERGENCE.SOCIAL_FLAG GROUP BY 1;
```

### 5. Recovery move
Open `02_compliance_search_and_aisql.sql` in this folder and run it.
