---
id: 06_streamlit_dashboard
inherits: ../../infrastructure/prompt-contract.md
depends_on: [04_cross_org_bridge, 03_counterparty_oversight_agent]
role: OB_DEMO_RW
warehouse: OB_DEMO_WH
database: OPTIMAL_BLUE_DEMO
schema: AI
output_files: [app.py, environment.yml, 06_streamlit_dashboard_deploy.sql]
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
3. **Reliable top-N bar of high-risk TPOs by state** (Altair horizontal
   bar of top 15). The earlier choropleth path (`plotly.express.choropleth`)
   was rejected: plotly geo renders blank in some SiS warehouse runtimes
   and adds a heavy dependency we don't otherwise need.
4. **Companion charts**: Findings by Region (bar), Compliance Score
   vs Pull-through (sized scatter), Onboarding Funnel (bar), Social
   Trend (gradient area).
5. **TPO Report Card** drill-through with status pills, big numbers
   (compliance score / pull-through / open findings / funded volume),
   recent audit findings + recent social flags.
6. **Inline "Ask the Agent" expander** (NOT `@st.dialog`) that calls
   `SNOWFLAKE.CORTEX.DATA_AGENT_RUN('OPTIMAL_BLUE_DEMO.AI.COUNTERPARTY_AGENT', $$...$$)`
   and renders the response text + tools used. **`@st.dialog` is gated
   behind newer Streamlit versions and is unreliable in SiS warehouse
   runtime; use `st.expander` for portability.**

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
- `app.py` (~480 lines, all 6 wow blocks)
- `environment.yml` (conda format - SiS warehouse runtime reads this,
  NOT `requirements.txt`). Channel: `snowflake`. Dependencies:
  `streamlit`, `pandas`, `altair`. Do not add `plotly` - we removed
  the choropleth so plotly is no longer needed.
- `06_streamlit_dashboard_deploy.sql` (stage + CREATE STREAMLIT)

## SiS-specific binding rules (all REQUIRED, learned the hard way)

These rules are the difference between a clean SiS run and a 30-minute
debug loop. Bake them into any regenerated `app.py`.

### 1. Decimal -> float coercion on every query
`session.sql(...).to_pandas()` returns NUMBER columns as
`decimal.Decimal`. Plotly and some Altair encoders raise:
`TypeError: bad argument type for built-in operation` on Decimal.
Wrap every `q()` helper with a `_decimal_safe(df)` post-processor that
converts object-dtype columns whose first value is `Decimal` via
`pd.to_numeric`. Apply on every read.

### 2. Defensive numeric casts before f-strings
Never do `f"{row['COL']}"` directly on a possibly-None / NaN / Decimal
value inside a card. Use a helper:
```python
def _f(v, default=0.0):
    try:
        if v is None: return default
        f = float(v)
        return default if f != f else f  # NaN guard
    except Exception:
        return default
```
Mixing `Decimal` and float in `Decimal / 1e9` raises a TypeError that
reads as "bad argument type" in SiS. Cast first, divide second.

### 3. `theme=None` on every `st.altair_chart`
Streamlit injects its own light theme on top of Altair's
`configure_axis(...)` calls, causing dark text to flip back to light
grey on white. Pair every chart with:
```python
st.altair_chart(chart, use_container_width=True, theme=None)
```
AND apply a chart-level helper:
```python
chart.configure(background="transparent")
     .configure_view(stroke=None, strokeWidth=0, fill=None)
     .configure_axis(labelColor=OB_TEXT, titleColor=OB_TEXT,
                     gridColor="rgba(255,255,255,0.06)",
                     domainColor="rgba(255,255,255,0.2)")
     .configure_legend(labelColor=OB_TEXT, titleColor=OB_TEXT)
     .configure_title(color=OB_TEXT)
```
This applies to sparklines too - the most-missed case.

### 4. SQL gotchas
- `SAMPLE (n ROWS)` is a TABLE-clause modifier and must come
  immediately after the table reference, BEFORE any `WHERE`. If you
  need both filtering and a row cap, use `LIMIT n` instead.
- `RANDOM(<col>)` does not compile - use `RANDOM()` (no args).
- Correlated subqueries are not supported - use a `numbered_<dim>` CTE
  with a deterministic index and a JOIN.
- `IDENTIFIER(CURRENT_USER())` does not compile inline; SET it to a
  variable first then `IDENTIFIER($var)`.

### 5. Diagnostic stub (per developing-with-streamlit-in-snowflake skill)
Add a sidebar toggle that prints `CURRENT_ROLE / USER / WAREHOUSE /
DATABASE / SCHEMA`. The skill calls this the #1 first-line debug for
any SiS "why is this failing" question. Costs ~10 lines, saves hours.

### 6. Use `st.expander`, not `st.dialog`
`@st.dialog` is gated behind Streamlit >= 1.30; many SiS warehouse
runtimes don't ship a recent enough Streamlit. `st.expander` is
universally available and feels like a chat panel when paired with
`st.chat_input` + `st.chat_message`.

### 7. SiS package management
Use `environment.yml` (conda format with `channels: [snowflake]`),
NOT `requirements.txt`. SiS warehouse runtime reads `environment.yml`
directly. `snow streamlit deploy` translates either, but a manual
stage upload only honors `environment.yml`.

### 8. Cortex AI calls from Python in SiS
- Model pin: `claude-4-sonnet`. Do NOT use `claude-3-5-sonnet`
  (region-restricted in `WWC76537` and similar accounts).
- Wrap `session.sql("SELECT SNOWFLAKE.CORTEX.AI_COMPLETE(...)")` in
  try/except - if Cortex is rate-limited or unreachable, the page
  must still render with a fallback string.
- For agent calls, use `SNOWFLAKE.CORTEX.DATA_AGENT_RUN`
  (NOT `AGENT_RUN`) with a `$$...$$` body literal so embedded JSON
  doesn't need quote-escaping.

## Acceptance criteria (10-point)

1. App deploys to SiS via `snow stage put` (app.py + environment.yml)
   followed by `CREATE OR REPLACE STREAMLIT`.
2. Hero renders with non-empty AI insight (cache miss path verified).
3. 6 KPI cards each with a 30-day sparkline that has > 0 data points
   AND a transparent background (no white rectangle behind the area).
4. Top-15 high-risk-TPO bar chart renders with non-zero values for the
   top 5 states; axis labels readable in white on dark.
5. All 4 companion charts (findings, score-vs-pt, funnel, social trend)
   render with white axis text on dark background (theme=None applied).
6. TPO selector loads top 200 TPOs; selecting one populates report card
   with non-empty finding + flag tables.
7. "Ask the Agent" expander visible above the floating-bubble area.
8. Expanding the panel and asking "Top 5 high-risk states" returns a
   tool-routed answer including "_Tools used: TPO_RISK_SV_".
9. Theme: navy gradient bg, magenta accents, glass cards visibly
   translucent, NO stray white rectangles anywhere.
10. Sidebar diagnostic toggle prints session info on demand. App load
    time < 6s warm cache, < 12s cold.

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
