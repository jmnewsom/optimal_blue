---
id: 06_streamlit_dashboard
inherits: ../../infrastructure/prompt-contract.md
depends_on: [04_cross_org_bridge, 03_counterparty_oversight_agent]
role: OB_DEMO_RW
warehouse: OB_DEMO_WH
database: OPTIMAL_BLUE_DEMO
schema: AI
output_files: [app.py, requirements.txt, 06_streamlit_dashboard_deploy.sql]
est_runtime_min: 5
cortex_code_skills: [developing-with-streamlit-in-snowflake]
---

# V6 - Streamlit Counterparty Risk Dashboard (Wow Edition)

## Goal
Deploy a Streamlit-in-Snowflake app branded for Optimal Blue that
showcases six wow-factor blocks on a single scrollable page, all built
from a single prompt contract. This is the "this is your team's daily
tool" moment - an analytics dashboard a Cortex Code prompt produced.

## Six wow blocks (binding)

1. **AI "Today's Insight" hero** - calls `SNOWFLAKE.CORTEX.AI_COMPLETE`
   on top open findings + risky regions and renders a one-paragraph
   executive summary. Cached `ttl=600`. **Model: `claude-4-sonnet`**
   (do NOT use `claude-3-5-sonnet` - unavailable in many regions
   including `WWC76537`).
2. **6 KPI cards with 30-day sparklines** beneath each value
   (Good Standing / Hi-Sev Findings / Lic Exp 30d / Social Flags 7d /
   Avg Pull-through / Funded 30d). The expiring-licenses sparkline
   MUST use a direct `GROUP BY expires_at BETWEEN CURRENT_DATE() AND
   DATEADD('day',30,...)` - a `TABLE(GENERATOR(...))` cross-join with
   `SEQ4()` returns 0 rows because of scope mismatch.
3. **Interactive US choropleth map** of high-risk TPOs by state, OB
   navy -> magenta gradient, hover shows TPO totals + suspended counts.
   Uses `plotly.express.choropleth(locationmode='USA-states')`.
4. **Companion charts**: Findings by Region (bar), Compliance Score
   vs Pull-through (sized scatter), Onboarding Funnel (bar), Social
   Trend (gradient area).
5. **TPO Report Card** drill-through with status pills, big numbers
   (compliance score / pull-through / open findings / funded volume),
   recent audit findings + recent social flags.
6. **Floating "Ask the Agent" bubble** bottom-right opens an
   `@st.dialog` chat that calls
   `SNOWFLAKE.CORTEX.DATA_AGENT_RUN('OPTIMAL_BLUE_DEMO.AI.COUNTERPARTY_AGENT', ...)`
   and renders the response text + tools used.

## Theme (binding)
- Dark glass-morph over Optimal Blue navy gradient
- Magenta `#E6007E` accents, amber `#F4B400` warnings, green `#1F8A4C`
  good-standing
- Translucent cards with `backdrop-filter: blur(12px)` borders
- Animated LIVE pulse indicator in hero
- Hover lift on KPI cards (`translateY(-2px)` + magenta glow)

## Inputs
- V1: `OPTIMAL_BLUE_DEMO.AI.TPO_RISK_SV` (indirect, via fact tables)
- V2: `OPTIMAL_BLUE_DEMO.COMERGENCE.SOCIAL_FLAG`
- V3: `OPTIMAL_BLUE_DEMO.AI.COUNTERPARTY_AGENT` (agent chat)
- V4: `OPTIMAL_BLUE_DEMO.SHARED.TPO_PERFORMANCE_V`
- Cortex AI: `AI_COMPLETE`, `DATA_AGENT_RUN`

## Deliverables
- `app.py` (~450 lines, all 6 wow blocks)
- `requirements.txt` (streamlit / snowpark / pandas / altair / plotly)
- `06_streamlit_dashboard_deploy.sql` (stage + CREATE STREAMLIT)

## Acceptance criteria (10-point)

1. App deploys to SiS with `snow streamlit deploy ob_comergence_dashboard --replace`.
2. Hero renders with non-empty AI insight (cache miss path verified).
3. 6 KPI cards each with a 30-day sparkline that has > 0 data points.
4. US choropleth renders with non-zero `high_risk_tpos` for the top 5 states.
5. All 4 companion charts (findings, score-vs-pt, funnel, social trend) render with data.
6. TPO selector loads top 200 TPOs; selecting one populates report card with non-empty finding + flag tables.
7. Floating "Ask the Agent" button visible bottom-right.
8. Clicking the bubble opens a dialog. Test prompt "Top 5 high-risk states" returns a tool-routed answer including "_Tools used: TPO_RISK_SV_".
9. Theme: navy gradient bg, magenta accents, glass cards visibly translucent.
10. App load time < 6s on warm cache, < 12s cold.

## Cortex Code talk track (live demo - 5-block runbook)

NOTE: V6 is the one vignette where we don't live-generate the full
artifact. `app.py` is too long to safely regenerate on stage. We
pre-deploy in pre-flight and use Cortex Code to *explain* the app
during the demo.

### 1. Setup (done in pre-flight)
- `snow streamlit deploy ob_comergence_dashboard --replace`
- Confirm SiS URL loads as `OB_DEMO_RW`

### 2. Prompt to paste verbatim (live, narration only)
> @vignettes/06_streamlit_dashboard/app.py
> Walk me through the AI Today's Insight hero block - which Snowflake
> function it calls, which tables it reads from, how the cache works,
> and how a Comergence persona would interpret the output.

### 3. Expected output
A short explanation tying the AI_COMPLETE call to V1 + V2 sources and
the cache_data TTL. No file generation; this is narration.

### 4. Verify (live)
- Open the deployed SiS URL inline in Snowsight
- Confirm hero insight, 6 KPIs with sparklines, US map, charts, report card
- Click the bubble; ask "Which states have the most high-risk TPOs?";
  confirm tool-routed answer cites `TPO_RISK_SV`

### 5. Recovery move
If the SiS app fails to load: `streamlit run app.py` locally with
`SNOWFLAKE_CONNECTION_NAME` set; same UI on localhost.
