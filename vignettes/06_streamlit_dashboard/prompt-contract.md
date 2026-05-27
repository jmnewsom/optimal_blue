---
id: 06_streamlit_dashboard
inherits: ../../infrastructure/prompt-contract.md
depends_on: [04_cross_org_bridge]
role: OB_DEMO_RW
warehouse: OB_DEMO_WH
database: OPTIMAL_BLUE_DEMO
schema: AI
output_files: [app.py, requirements.txt, 06_streamlit_dashboard_deploy.sql]
est_runtime_min: 4
cortex_code_skills: [developing-with-streamlit-in-snowflake]
---

# V6 - Streamlit Counterparty Risk Dashboard

## Goal
Deploy a Streamlit-in-Snowflake (SiS) app branded for Optimal Blue that
surfaces every Comergence + cross-org KPI in one screen, with drill-through
to a single TPO. This is the "this is your team's daily tool" moment.

## KPIs (top row metric cards)
- TPOs in good standing (status=ACTIVE AND compliance_score >= 80)
- Open high-severity findings
- Licenses expiring in 30 days
- Social posts flagged HIGH (last 7d)
- Average pull-through %
- Funded volume (last 30d, USD)

## Charts
- Findings by region (bar)
- Compliance score vs pull-through (scatter, color = risk_tier)
- Onboarding funnel (avg duration_days per stage, bar)
- Social-flag trend (last 30d daily, line)

## Drill-through
- TPO selector -> shows audit history, social flags, lock metrics, score.

## Deliverables
- `app.py` (Snowflake-flavored Streamlit, OB navy/magenta accent)
- `requirements.txt`
- `deploy.sql` (snow streamlit deploy convenience SQL)

## Cortex Code talk track (live demo - 5-block runbook)

NOTE: V6 is the one vignette where we do NOT live-generate the full
artifact. `app.py` is too long to safely regenerate on stage. Instead,
we pre-deploy in pre-flight and use Cortex Code to *explain* the app,
then open the live SiS URL.

### 1. Setup (done in pre-flight, NOT live)
- Pre-flight: `snow streamlit deploy ob_comergence_dashboard --replace`
  using files in `vignettes/06_streamlit_dashboard/`
- Confirm SiS URL is reachable as `OB_DEMO_RW`

### 2. Prompt to paste verbatim (live, for explanation only)
> @vignettes/06_streamlit_dashboard/app.py
> Walk me through the KPI section and the cross-org bridge query that
> powers "Funded Volume (30d)". Highlight where this app is reading
> SHARED.TPO_PERFORMANCE_V from V4.

### 3. Expected output
- A short explanation tying the cards back to V1, V2, V4 outputs
- No file generation; this is narration

### 4. Verify
- Open the deployed SiS URL inline in Snowsight
- All 6 KPI cards render with non-zero values
- TPO drill-through populates lock + finding tables

### 5. Recovery move
If the SiS app fails to load: run `streamlit run app.py` locally with
`SNOWFLAKE_CONNECTION_NAME` set; same UI on localhost.
