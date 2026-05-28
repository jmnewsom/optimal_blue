"""
Optimal Blue / Comergence - Counterparty Risk Dashboard (Wow Edition)
Generated from vignettes/06_streamlit_dashboard/prompt-contract.md.

Six wow blocks on a single scrollable page:
  1. AI "Today's Insight" hero (AI_COMPLETE on top findings)
  2. 6 KPI cards with 30-day sparklines
  3. Interactive US choropleth of high-risk TPOs
  4. Companion charts (findings, score-vs-pull-through, funnel, social trend)
  5. TPO Report Card drill-through (status pills, big numbers, finding/flag lists)
  6. Floating "Ask the Agent" bubble (st.dialog -> DATA_AGENT_RUN against V3 agent)

Theme: glass-morph dark over Optimal Blue navy gradient with magenta accents.

Run as:    OB_DEMO_RW @ OB_DEMO_WH @ OPTIMAL_BLUE_DEMO.AI
Deploy:    snow streamlit deploy ob_comergence_dashboard --replace
"""

import json
from decimal import Decimal
import altair as alt
import pandas as pd
import streamlit as st
from snowflake.snowpark.context import get_active_session

# ============================================================
# THEME
# ============================================================
OB_NAVY     = "#0B1E3F"
OB_NAVY_2   = "#152B5C"
OB_MAGENTA  = "#E6007E"
OB_AMBER    = "#F4B400"
OB_GREEN    = "#1F8A4C"
OB_TEXT     = "#E8ECF5"
OB_DIM      = "#9AA3B8"

st.set_page_config(
    page_title="Comergence | Counterparty Risk",
    page_icon="🛡️",
    layout="wide",
    initial_sidebar_state="collapsed",
)

st.markdown(
    f"""
    <style>
      .stApp {{
          background:
            radial-gradient(1200px 600px at 10% -10%, {OB_NAVY_2} 0%, transparent 60%),
            radial-gradient(900px 500px at 100% 0%, rgba(230,0,126,0.15) 0%, transparent 60%),
            linear-gradient(180deg, {OB_NAVY} 0%, #061229 100%);
          color: {OB_TEXT};
      }}
      .block-container {{ padding-top: 1.2rem; padding-bottom: 6rem; }}
      h1, h2, h3, h4 {{ color: {OB_TEXT} !important; letter-spacing: -0.01em; }}
      .ob-hero {{
          display:flex; align-items:center; justify-content:space-between;
          padding: 14px 22px;
          border-radius: 16px;
          background: linear-gradient(135deg, rgba(255,255,255,0.05), rgba(255,255,255,0.02));
          border: 1px solid rgba(255,255,255,0.08);
          margin-bottom: 16px;
      }}
      .ob-hero .title {{ font-size: 1.6rem; font-weight: 700; color: {OB_TEXT}; }}
      .ob-hero .subtitle {{ color: {OB_DIM}; font-size: 0.9rem; margin-top: 2px; }}
      .ob-pulse {{
          display:inline-flex; align-items:center; gap:8px;
          padding: 4px 12px; border-radius:999px;
          background: rgba(31,138,76,0.12); color:{OB_GREEN};
          font-size: 0.78rem; font-weight: 600; letter-spacing: 0.04em;
      }}
      .ob-pulse-dot {{
          width:8px; height:8px; border-radius:50%;
          background:{OB_GREEN}; box-shadow:0 0 0 0 {OB_GREEN};
          animation: pulse 1.8s infinite;
      }}
      @keyframes pulse {{
        0%   {{ box-shadow: 0 0 0 0 rgba(31,138,76,0.7); }}
        70%  {{ box-shadow: 0 0 0 10px rgba(31,138,76,0); }}
        100% {{ box-shadow: 0 0 0 0 rgba(31,138,76,0); }}
      }}
      .ob-glass {{
          background: rgba(255,255,255,0.04);
          backdrop-filter: blur(12px);
          -webkit-backdrop-filter: blur(12px);
          border: 1px solid rgba(255,255,255,0.08);
          border-radius: 16px;
          padding: 16px 18px;
          box-shadow: 0 6px 24px rgba(0,0,0,0.25);
      }}
      .ob-insight {{
          background: linear-gradient(135deg, rgba(230,0,126,0.10), rgba(11,30,63,0.10));
          border: 1px solid rgba(230,0,126,0.25);
          border-radius: 18px;
          padding: 18px 22px;
          margin-bottom: 16px;
      }}
      .ob-insight .label {{
          color: {OB_MAGENTA}; font-size: 0.82rem; font-weight: 700;
          letter-spacing: 0.10em; text-transform: uppercase;
      }}
      .ob-insight .body {{
          color: {OB_TEXT}; font-size: 1.02rem; line-height: 1.55; margin-top: 8px;
      }}
      .ob-kpi {{
          background: rgba(255,255,255,0.04);
          backdrop-filter: blur(12px);
          border: 1px solid rgba(255,255,255,0.08);
          border-radius: 16px;
          padding: 14px 16px;
          height: 152px;
          display:flex; flex-direction:column; justify-content:space-between;
          transition: transform 0.15s ease, box-shadow 0.15s ease;
      }}
      .ob-kpi:hover {{
          transform: translateY(-2px);
          box-shadow: 0 10px 32px rgba(230,0,126,0.18);
          border-color: rgba(230,0,126,0.35);
      }}
      .ob-kpi .label {{
          color: {OB_DIM}; font-size: 0.72rem; font-weight: 700;
          letter-spacing: 0.10em; text-transform: uppercase;
      }}
      .ob-kpi .value {{
          color: {OB_TEXT}; font-size: 1.85rem; font-weight: 700; line-height: 1;
      }}
      .ob-kpi .value.magenta {{ color: {OB_MAGENTA}; }}
      .ob-kpi .value.amber   {{ color: {OB_AMBER}; }}
      .ob-kpi .value.green   {{ color: {OB_GREEN}; }}
      .ob-kpi .sub   {{ color:{OB_DIM}; font-size: 0.78rem; }}
      .ob-pill {{
          display:inline-block; padding:3px 10px; border-radius:999px;
          font-size: 0.75rem; font-weight: 600; letter-spacing: 0.04em;
      }}
      .ob-pill.green   {{ background: rgba(31,138,76,0.15);  color:{OB_GREEN}; }}
      .ob-pill.amber   {{ background: rgba(244,180,0,0.15);  color:{OB_AMBER}; }}
      .ob-pill.magenta {{ background: rgba(230,0,126,0.18);  color:{OB_MAGENTA}; }}
      .ob-pill.dim     {{ background: rgba(154,163,184,0.15); color:{OB_DIM}; }}
      .ob-bignum {{ font-size: 2rem; font-weight: 700; color: {OB_TEXT}; line-height:1; }}
      .ob-floating {{
          position: fixed; bottom: 24px; right: 24px; z-index: 9999;
      }}
      div[data-testid="stDialog"] {{
          background: linear-gradient(180deg, {OB_NAVY_2} 0%, {OB_NAVY} 100%);
          color: {OB_TEXT};
      }}
      .stDataFrame, .stDataFrame * {{ color: {OB_TEXT} !important; }}
    </style>
    """,
    unsafe_allow_html=True,
)

session = get_active_session()

# ============================================================
# SiS DIAGNOSTIC STUB (per developing-with-streamlit-in-snowflake skill)
# Toggle at top so we can see CURRENT_ROLE/USER/WH/DB at a glance.
# ============================================================
if st.sidebar.toggle("Show SiS session info", value=False):
    try:
        ctx = session.sql(
            "SELECT CURRENT_ROLE() r, CURRENT_USER() u, CURRENT_WAREHOUSE() w, CURRENT_DATABASE() d, CURRENT_SCHEMA() s"
        ).collect()
        st.sidebar.info(
            f"role={ctx[0]['R']}\nuser={ctx[0]['U']}\nwh={ctx[0]['W']}\ndb={ctx[0]['D']}\nschema={ctx[0]['S']}"
        )
    except Exception as e:
        st.sidebar.error(f"Session probe failed: {e}")

# ============================================================
# DATA HELPERS (cached)
# ============================================================
def _decimal_safe(df: pd.DataFrame) -> pd.DataFrame:
    """Convert decimal.Decimal columns to float so plotly/altair JSON serializers don't choke.
    SiS's `session.sql(...).to_pandas()` returns NUMBER columns as Decimal which trips
    Plotly's encoder with: 'TypeError: bad argument type for built-in operation'.
    """
    if df is None or df.empty:
        return df
    for c in df.columns:
        s = df[c]
        if s.dtype == object and len(s) and isinstance(s.iloc[0], Decimal):
            df[c] = pd.to_numeric(s, errors="coerce")
    return df

@st.cache_data(ttl=300, show_spinner=False)
def q(sql: str) -> pd.DataFrame:
    """Run a SQL string and return a pandas DataFrame (Decimal-safe)."""
    return _decimal_safe(session.sql(sql).to_pandas())

@st.cache_data(ttl=600, show_spinner=False)
def todays_insight() -> str:
    """One AI_COMPLETE summary of top open findings + risky regions."""
    facts = q("""
        WITH top_states AS (
          SELECT s.region, COUNT_IF(t.risk_tier='HIGH') AS hi
          FROM OPTIMAL_BLUE_DEMO.COMERGENCE.TPO t
          JOIN OPTIMAL_BLUE_DEMO.COMERGENCE.STATE s ON s.state_code = t.state_code
          GROUP BY s.region ORDER BY hi DESC LIMIT 2
        ),
        worst AS (
          SELECT category, COUNT(*) AS c
          FROM OPTIMAL_BLUE_DEMO.COMERGENCE.AUDIT_FINDING
          WHERE severity='HIGH' AND status<>'CLOSED'
          GROUP BY category ORDER BY c DESC LIMIT 2
        ),
        soc AS (
          SELECT COUNT_IF(compliance_risk='HIGH') AS hi_social
          FROM OPTIMAL_BLUE_DEMO.COMERGENCE.SOCIAL_FLAG
          WHERE posted_at >= DATEADD('day',-7,CURRENT_TIMESTAMP())
        )
        SELECT
          (SELECT LISTAGG(region||':'||hi,', ') FROM top_states)             AS top_regions,
          (SELECT LISTAGG(category||':'||c,', ') FROM worst)                 AS top_finding_cats,
          (SELECT hi_social FROM soc)                                        AS social_high_7d
    """).iloc[0]
    prompt = (
        "You are a Comergence counterparty oversight analyst. Write ONE concise paragraph "
        "(max 3 sentences, professional tone, no preamble) summarizing today's posture for "
        "an executive. Numbers come from these facts and are ground truth: "
        f"top regions by high-risk TPO count = {facts['TOP_REGIONS']}; "
        f"largest open high-severity finding categories = {facts['TOP_FINDING_CATS']}; "
        f"high-risk social posts in last 7 days = {facts['SOCIAL_HIGH_7D']}. "
        "End with one specific recommended action. Do not invent any other numbers."
    )
    safe_prompt = prompt.replace("'", "''")
    try:
        out = session.sql(
            f"SELECT SNOWFLAKE.CORTEX.AI_COMPLETE('claude-4-sonnet','{safe_prompt}') AS s"
        ).collect()
        return str(out[0]["S"]) if out else ""
    except Exception:
        return ""

@st.cache_data(ttl=300, show_spinner=False)
def kpi_values():
    df = q("""
        WITH perf AS (SELECT * FROM OPTIMAL_BLUE_DEMO.SHARED.TPO_PERFORMANCE_V),
             social AS (
               SELECT COUNT_IF(compliance_risk='HIGH'
                                AND posted_at >= DATEADD('day',-7,CURRENT_TIMESTAMP())) AS social_high_7d
               FROM OPTIMAL_BLUE_DEMO.COMERGENCE.SOCIAL_FLAG
             ),
             vol AS (
               SELECT SUM(note_amount) AS funded_30d
               FROM OPTIMAL_BLUE_DEMO.PPE.LOCK
               WHERE lock_status='FUNDED' AND funded_at >= DATEADD('day',-30,CURRENT_TIMESTAMP())
             )
        SELECT
          (SELECT COUNT_IF(tpo_status='ACTIVE' AND compliance_score>=80) FROM perf) AS good_standing,
          (SELECT SUM(high_severity_findings) FROM perf)                            AS hi_findings,
          (SELECT SUM(licenses_expiring_30d)  FROM perf)                            AS exp_30,
          (SELECT social_high_7d FROM social)                                       AS social_high_7d,
          (SELECT AVG(pull_through_pct) FROM perf WHERE total_locks>0)              AS avg_pt,
          (SELECT funded_30d FROM vol)                                              AS funded_30d
    """)
    # Cast everything to plain Python floats / ints, defaulting None/NaN to 0.
    # SiS surfaces NaN/Decimal/None type mixes as "bad argument type for built-in operation".
    def _as_float(v):
        try:
            if v is None: return 0.0
            f = float(v)
            return 0.0 if f != f else f  # NaN guard
        except Exception:
            return 0.0
    row = df.iloc[0]
    return {
        "GOOD_STANDING":  int(_as_float(row.get("GOOD_STANDING"))),
        "HI_FINDINGS":    int(_as_float(row.get("HI_FINDINGS"))),
        "EXP_30":         int(_as_float(row.get("EXP_30"))),
        "SOCIAL_HIGH_7D": int(_as_float(row.get("SOCIAL_HIGH_7D"))),
        "AVG_PT":         _as_float(row.get("AVG_PT")),
        "FUNDED_30D":     _as_float(row.get("FUNDED_30D")),
    }

@st.cache_data(ttl=300, show_spinner=False)
def kpi_spark(kind: str) -> pd.DataFrame:
    """Daily 30-day series per KPI for the sparkline."""
    if kind == "findings":
        sql = """
          SELECT DATE_TRUNC('day', finding_date)::DATE AS d,
                 COUNT_IF(severity='HIGH') AS v
          FROM OPTIMAL_BLUE_DEMO.COMERGENCE.AUDIT_FINDING
          WHERE finding_date >= DATEADD('day',-30,CURRENT_DATE())
          GROUP BY 1 ORDER BY 1
        """
    elif kind == "social":
        sql = """
          SELECT DATE_TRUNC('day', posted_at)::DATE AS d,
                 COUNT_IF(compliance_risk='HIGH') AS v
          FROM OPTIMAL_BLUE_DEMO.COMERGENCE.SOCIAL_FLAG
          WHERE posted_at >= DATEADD('day',-30,CURRENT_TIMESTAMP())
          GROUP BY 1 ORDER BY 1
        """
    elif kind == "funded":
        sql = """
          SELECT DATE_TRUNC('day', funded_at)::DATE AS d,
                 SUM(note_amount)/1e6 AS v
          FROM OPTIMAL_BLUE_DEMO.PPE.LOCK
          WHERE lock_status='FUNDED' AND funded_at >= DATEADD('day',-30,CURRENT_TIMESTAMP())
          GROUP BY 1 ORDER BY 1
        """
    elif kind == "onboard":
        sql = """
          SELECT DATE_TRUNC('day', occurred_at)::DATE AS d,
                 COUNT_IF(stage='ACTIVE') AS v
          FROM OPTIMAL_BLUE_DEMO.COMERGENCE.ONBOARDING_EVENT
          WHERE occurred_at >= DATEADD('day',-30,CURRENT_TIMESTAMP())
          GROUP BY 1 ORDER BY 1
        """
    elif kind == "expiring":
        sql = """
          SELECT expires_at AS d, COUNT(*) AS v
          FROM OPTIMAL_BLUE_DEMO.COMERGENCE.NMLS_LICENSE
          WHERE expires_at BETWEEN CURRENT_DATE()
                              AND DATEADD('day', 30, CURRENT_DATE())
          GROUP BY 1 ORDER BY 1
        """
    else:  # good_standing - approximate by funded daily count
        sql = """
          SELECT DATE_TRUNC('day', funded_at)::DATE AS d,
                 COUNT(DISTINCT tpo_id) AS v
          FROM OPTIMAL_BLUE_DEMO.PPE.LOCK
          WHERE lock_status='FUNDED' AND funded_at >= DATEADD('day',-30,CURRENT_TIMESTAMP())
          GROUP BY 1 ORDER BY 1
        """
    return q(sql)

@st.cache_data(ttl=300, show_spinner=False)
def map_data():
    return q("""
        SELECT t.state_code, s.state_name,
               COUNT(*)                         AS tpos,
               COUNT_IF(t.risk_tier='HIGH')     AS high_risk_tpos,
               COUNT_IF(t.status='SUSPENDED')   AS suspended_tpos
        FROM OPTIMAL_BLUE_DEMO.COMERGENCE.TPO t
        JOIN OPTIMAL_BLUE_DEMO.COMERGENCE.STATE s ON s.state_code = t.state_code
        GROUP BY 1,2
    """)

@st.cache_data(ttl=300, show_spinner=False)
def findings_by_region():
    return q("""
        SELECT s.region,
               COUNT_IF(a.severity='HIGH' AND a.status<>'CLOSED') AS hi_findings
        FROM OPTIMAL_BLUE_DEMO.COMERGENCE.AUDIT_FINDING a
        JOIN OPTIMAL_BLUE_DEMO.COMERGENCE.TPO   t ON t.tpo_id = a.tpo_id
        JOIN OPTIMAL_BLUE_DEMO.COMERGENCE.STATE s ON s.state_code = t.state_code
        GROUP BY 1 ORDER BY 1
    """)

@st.cache_data(ttl=300, show_spinner=False)
def score_vs_pt():
    return q("""
        SELECT compliance_score, pull_through_pct, risk_tier, funded_volume_usd
        FROM OPTIMAL_BLUE_DEMO.SHARED.TPO_PERFORMANCE_V
        WHERE total_locks > 5
        LIMIT 5000
    """)

@st.cache_data(ttl=300, show_spinner=False)
def onboarding_funnel():
    return q("""
        SELECT stage, AVG(duration_days) AS avg_days, COUNT(*) AS events
        FROM OPTIMAL_BLUE_DEMO.COMERGENCE.ONBOARDING_EVENT
        GROUP BY stage ORDER BY MIN(occurred_at)
    """)

@st.cache_data(ttl=300, show_spinner=False)
def social_trend():
    return q("""
        SELECT DATE_TRUNC('day', posted_at)::DATE AS d,
               COUNT_IF(compliance_risk='HIGH') AS high_n,
               COUNT(*) AS total_n
        FROM OPTIMAL_BLUE_DEMO.COMERGENCE.SOCIAL_FLAG
        WHERE posted_at >= DATEADD('day',-30,CURRENT_TIMESTAMP())
        GROUP BY 1 ORDER BY 1
    """)

@st.cache_data(ttl=300, show_spinner=False)
def tpo_options():
    return q("""
        SELECT tpo_id, tpo_name FROM OPTIMAL_BLUE_DEMO.COMERGENCE.TPO
        ORDER BY tpo_id LIMIT 200
    """)

# ============================================================
# UI HELPERS
# ============================================================
def kpi_card(col, label, value, sub, color="", spark_kind=None):
    klass = f"value {color}".strip()
    col.markdown(
        f"""
        <div class='ob-kpi'>
          <div>
            <div class='label'>{label}</div>
            <div class='{klass}' style='margin-top:6px;'>{value}</div>
            <div class='sub' style='margin-top:4px;'>{sub}</div>
          </div>
          <div id='spark-{spark_kind}' style='height:36px;'></div>
        </div>
        """,
        unsafe_allow_html=True,
    )
    if spark_kind:
        try:
            df = kpi_spark(spark_kind)
            if df is not None and not df.empty:
                chart = (
                    alt.Chart(df)
                    .mark_area(opacity=0.55, color=OB_MAGENTA, line={"color": OB_MAGENTA, "strokeWidth": 1.5})
                    .encode(
                        x=alt.X("D:T", axis=None),
                        y=alt.Y("V:Q", axis=None),
                    )
                    .properties(height=36)
                    .configure_view(strokeWidth=0)
                )
                with col:
                    st.altair_chart(chart, use_container_width=True, theme=None)
        except Exception:
            pass  # never let a sparkline break the whole page

def status_pill(text, kind="dim"):
    return f"<span class='ob-pill {kind}'>{text}</span>"

# ============================================================
# 1) HERO
# ============================================================
st.markdown(
    f"""
    <div class='ob-hero'>
      <div>
        <div class='title'>Comergence Counterparty Risk</div>
        <div class='subtitle'>Powered by Snowflake Cortex - built from a prompt</div>
      </div>
      <div class='ob-pulse'><span class='ob-pulse-dot'></span>LIVE</div>
    </div>
    """,
    unsafe_allow_html=True,
)

# ============================================================
# 2) AI "TODAY'S INSIGHT"
# ============================================================
try:
    insight_text = todays_insight()
except Exception as e:
    insight_text = (
        "Insight engine warming up - showing a sample summary. "
        "Once Cortex is reachable, this paragraph rebuilds itself "
        "from your top open findings and recent social activity."
    )
st.markdown(
    f"""
    <div class='ob-insight'>
      <div class='label'>★ Today's Insight</div>
      <div class='body'>{insight_text}</div>
    </div>
    """,
    unsafe_allow_html=True,
)

# ============================================================
# 3) KPI ROW + SPARKLINES
# ============================================================
k = kpi_values()
c1, c2, c3, c4, c5, c6 = st.columns(6)
kpi_card(c1, "Good Standing",      f"{k['GOOD_STANDING']:,}",            "active & score >= 80", "green",   "good")
kpi_card(c2, "Hi-Sev Findings",    f"{k['HI_FINDINGS']:,}",              "open + in remediation", "magenta", "findings")
kpi_card(c3, "Lic Exp 30d",        f"{k['EXP_30']:,}",                   "across all states",     "amber",   "expiring")
kpi_card(c4, "Social Flags 7d",    f"{k['SOCIAL_HIGH_7D']:,}",           "AI_CLASSIFY = HIGH",    "magenta", "social")
kpi_card(c5, "Avg Pull-through",   f"{k['AVG_PT']:.1f}%",                "TPOs with locks",       "",        "onboard")
kpi_card(c6, "Funded 30d",         f"${k['FUNDED_30D']/1e9:.2f}B",       "PPE cross-org bridge",  "green",   "funded")

st.markdown("<div style='height:18px'></div>", unsafe_allow_html=True)

# ============================================================
# 4) HIGH-RISK TPOs BY STATE - top-15 horizontal bar (reliable in SiS)
# ============================================================
mdf = map_data().sort_values("HIGH_RISK_TPOS", ascending=False).head(15)
st.markdown("#### High-Risk TPOs by State (top 15)")
bar_chart = (
    alt.Chart(mdf)
    .mark_bar(color=OB_MAGENTA, cornerRadius=4)
    .encode(
        x=alt.X("HIGH_RISK_TPOS:Q", title="High-risk TPOs"),
        y=alt.Y("STATE_NAME:N", sort="-x", title=None),
        tooltip=["STATE_NAME", "HIGH_RISK_TPOS", "TPOS", "SUSPENDED_TPOS"],
    )
    .properties(height=380)
    .configure(background="transparent")
    .configure_view(stroke=None)
    .configure_axis(
        labelColor=OB_TEXT, titleColor=OB_TEXT,
        gridColor="rgba(255,255,255,0.06)", domainColor="rgba(255,255,255,0.2)",
    )
)
st.altair_chart(bar_chart, use_container_width=True, theme=None)

# ============================================================
# 5) CHARTS GRID
# ============================================================
def alt_dark(chart):
    """Apply dark theme. Pair with theme=None on st.altair_chart so Streamlit
    doesn't override our config."""
    return (
        chart
        .configure(background="transparent")
        .configure_view(stroke=None, strokeWidth=0)
        .configure_axis(
            labelColor=OB_TEXT, titleColor=OB_TEXT,
            gridColor="rgba(255,255,255,0.06)",
            domainColor="rgba(255,255,255,0.2)",
            tickColor="rgba(255,255,255,0.2)",
        )
        .configure_legend(
            labelColor=OB_TEXT, titleColor=OB_TEXT,
            symbolStrokeColor="rgba(255,255,255,0.2)",
        )
        .configure_title(color=OB_TEXT)
    )

cA, cB = st.columns(2)
with cA:
    st.markdown("#### High-Severity Findings by Region")
    df = findings_by_region()
    chart = alt_dark(
        alt.Chart(df).mark_bar(color=OB_MAGENTA, cornerRadius=4).encode(
            x=alt.X("REGION:N", sort="-y", title=None),
            y=alt.Y("HI_FINDINGS:Q", title="High-severity findings"),
            tooltip=["REGION", "HI_FINDINGS"],
        ).properties(height=280)
    )
    st.altair_chart(chart, use_container_width=True, theme=None)

with cB:
    st.markdown("#### Compliance Score vs Pull-through")
    df = score_vs_pt()
    if not df.empty:
        chart = alt_dark(
            alt.Chart(df).mark_circle(opacity=0.7).encode(
                x=alt.X("COMPLIANCE_SCORE:Q", title="Compliance score"),
                y=alt.Y("PULL_THROUGH_PCT:Q", title="Pull-through %"),
                color=alt.Color(
                    "RISK_TIER:N",
                    scale=alt.Scale(domain=["LOW","MED","HIGH"],
                                    range=[OB_GREEN, OB_AMBER, OB_MAGENTA]),
                    legend=alt.Legend(orient="top"),
                ),
                size=alt.Size("FUNDED_VOLUME_USD:Q",
                              scale=alt.Scale(range=[20, 400]),
                              legend=None),
                tooltip=["COMPLIANCE_SCORE","PULL_THROUGH_PCT","RISK_TIER","FUNDED_VOLUME_USD"],
            ).properties(height=280)
        )
        st.altair_chart(chart, use_container_width=True, theme=None)

cC, cD = st.columns(2)
with cC:
    st.markdown("#### Onboarding Funnel - Avg Days per Stage")
    df = onboarding_funnel()
    chart = alt_dark(
        alt.Chart(df).mark_bar(color=OB_NAVY_2, cornerRadius=4,
                               stroke=OB_MAGENTA, strokeWidth=1.5).encode(
            x=alt.X("STAGE:N", sort=None, title=None),
            y=alt.Y("AVG_DAYS:Q", title="Avg days"),
            tooltip=["STAGE","AVG_DAYS","EVENTS"],
        ).properties(height=280)
    )
    st.altair_chart(chart, use_container_width=True, theme=None)

with cD:
    st.markdown("#### Social-flag Trend (30d)")
    df = social_trend()
    chart = alt_dark(
        alt.Chart(df).mark_area(opacity=0.5, color=OB_MAGENTA,
                                line={"color": OB_MAGENTA, "strokeWidth": 2}).encode(
            x=alt.X("D:T", title=None),
            y=alt.Y("HIGH_N:Q", title="HIGH-risk posts"),
            tooltip=["D","HIGH_N","TOTAL_N"],
        ).properties(height=280)
    )
    st.altair_chart(chart, use_container_width=True, theme=None)

# ============================================================
# 6) TPO REPORT CARD
# ============================================================
st.markdown("<div style='height:20px'></div>", unsafe_allow_html=True)
st.markdown("### Counterparty Detail")
opts = tpo_options()
if not opts.empty:
    pick = st.selectbox(
        "Choose a TPO",
        opts["TPO_NAME"] + "  (#" + opts["TPO_ID"].astype(str) + ")",
        index=0,
        label_visibility="collapsed",
    )
    tpo_id = int(pick.split("#")[-1].rstrip(")"))

    perf = q(f"""
        SELECT * FROM OPTIMAL_BLUE_DEMO.SHARED.TPO_PERFORMANCE_V
        WHERE tpo_id = {tpo_id}
    """)
    findings = q(f"""
        SELECT finding_date, severity, category, status,
               LEFT(finding_text, 80) AS finding_text
        FROM OPTIMAL_BLUE_DEMO.COMERGENCE.AUDIT_FINDING
        WHERE tpo_id = {tpo_id}
        ORDER BY finding_date DESC LIMIT 10
    """)
    flags = q(f"""
        SELECT posted_at, platform, compliance_risk, sentiment,
               LEFT(post_text, 80) AS post_text
        FROM OPTIMAL_BLUE_DEMO.COMERGENCE.SOCIAL_FLAG
        WHERE tpo_id = {tpo_id}
        ORDER BY posted_at DESC LIMIT 10
    """)

    if not perf.empty:
        row = perf.iloc[0]
        # Defensive casts - SiS dies on Decimal/None mixes in f-strings.
        def _f(v, default=0.0):
            try:
                if v is None: return default
                f = float(v)
                return default if f != f else f
            except Exception:
                return default
        def _i(v):
            return int(_f(v))
        tpo_status_val = str(row.get("TPO_STATUS") or "UNKNOWN")
        risk_tier_val  = str(row.get("RISK_TIER")  or "UNKNOWN")
        state_val      = str(row.get("STATE_CODE") or "")
        channel_val    = str(row.get("CHANNEL_CODE") or "")
        tpo_name_val   = str(row.get("TPO_NAME") or "")

        status_kind = ("green" if tpo_status_val == "ACTIVE"
                       else "magenta" if tpo_status_val == "SUSPENDED"
                       else "amber")
        risk_kind = ("green" if risk_tier_val == "LOW"
                     else "amber" if risk_tier_val == "MED"
                     else "magenta")
        score = _i(row.get("COMPLIANCE_SCORE"))
        score_color = OB_GREEN if score >= 80 else OB_AMBER if score >= 60 else OB_MAGENTA
        pull_pct = _f(row.get("PULL_THROUGH_PCT"))
        funded_locks = _i(row.get("FUNDED_LOCKS"))
        open_findings = _i(row.get("OPEN_FINDINGS"))
        hi_sev = _i(row.get("HIGH_SEVERITY_FINDINGS"))
        funded_vol = _f(row.get("FUNDED_VOLUME_USD"))
        investor_breadth = _i(row.get("INVESTOR_BREADTH"))

        st.markdown(
            f"""
            <div class='ob-glass' style='margin-bottom:14px;'>
              <div style='display:flex; align-items:center; gap:14px; flex-wrap:wrap;'>
                <div style='font-size:1.4rem; font-weight:700;'>{tpo_name_val}</div>
                {status_pill(tpo_status_val, status_kind)}
                {status_pill(risk_tier_val+' RISK', risk_kind)}
                {status_pill(state_val, 'dim')}
                {status_pill(channel_val, 'dim')}
              </div>
            </div>
            """,
            unsafe_allow_html=True,
        )

        d1, d2, d3, d4 = st.columns(4)
        with d1:
            st.markdown(
                f"<div class='ob-glass'><div style='color:{OB_DIM};font-size:0.78rem;font-weight:600;letter-spacing:0.08em;'>COMPLIANCE</div>"
                f"<div class='ob-bignum' style='color:{score_color};margin-top:6px'>{score}</div>"
                f"<div style='color:{OB_DIM};font-size:0.78rem;'>0 - 100</div></div>",
                unsafe_allow_html=True,
            )
        with d2:
            st.markdown(
                f"<div class='ob-glass'><div style='color:{OB_DIM};font-size:0.78rem;font-weight:600;letter-spacing:0.08em;'>PULL-THROUGH</div>"
                f"<div class='ob-bignum' style='margin-top:6px'>{pull_pct:.1f}%</div>"
                f"<div style='color:{OB_DIM};font-size:0.78rem;'>{funded_locks} funded locks</div></div>",
                unsafe_allow_html=True,
            )
        with d3:
            st.markdown(
                f"<div class='ob-glass'><div style='color:{OB_DIM};font-size:0.78rem;font-weight:600;letter-spacing:0.08em;'>OPEN FINDINGS</div>"
                f"<div class='ob-bignum' style='margin-top:6px'>{open_findings}</div>"
                f"<div style='color:{OB_DIM};font-size:0.78rem;'>{hi_sev} high severity</div></div>",
                unsafe_allow_html=True,
            )
        with d4:
            st.markdown(
                f"<div class='ob-glass'><div style='color:{OB_DIM};font-size:0.78rem;font-weight:600;letter-spacing:0.08em;'>FUNDED VOLUME</div>"
                f"<div class='ob-bignum' style='margin-top:6px'>${funded_vol/1e6:.1f}M</div>"
                f"<div style='color:{OB_DIM};font-size:0.78rem;'>{investor_breadth} investors</div></div>",
                unsafe_allow_html=True,
            )

        st.markdown("<div style='height:14px'></div>", unsafe_allow_html=True)
        f1, f2 = st.columns(2)
        with f1:
            st.markdown("**Recent audit findings**")
            st.dataframe(findings, hide_index=True, use_container_width=True, height=260)
        with f2:
            st.markdown("**Recent social flags**")
            st.dataframe(flags, hide_index=True, use_container_width=True, height=260)

# ============================================================
# 7) FLOATING "ASK THE AGENT" BUBBLE -> st.dialog -> DATA_AGENT_RUN
# ============================================================
def parse_agent_response(raw_json: str) -> str:
    """Extract the assistant text from DATA_AGENT_RUN's content array."""
    try:
        obj = json.loads(raw_json)
    except Exception:
        return raw_json
    parts = []
    tools = []
    for item in obj.get("content", []):
        if item.get("type") == "text" and item.get("text"):
            parts.append(item["text"])
        elif item.get("type") == "tool_use":
            tools.append(item.get("tool_use", {}).get("name", "?"))
    answer = "\n\n".join([p for p in parts if p.strip()]) or "(no text in response)"
    if tools:
        answer += f"\n\n_Tools used: {', '.join(tools)}_"
    return answer

def call_agent(question: str) -> str:
    body = json.dumps({
        "messages": [{
            "role": "user",
            "content": [{"type": "text", "text": question}],
        }]
    })
    body_sql = body.replace("'", "''")
    rows = session.sql(
        f"SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN("
        f"'OPTIMAL_BLUE_DEMO.AI.COUNTERPARTY_AGENT', $${body}$$) AS r"
    ).collect()
    return parse_agent_response(rows[0]["R"])

if "agent_history" not in st.session_state:
    st.session_state.agent_history = []

# st.dialog is gated behind newer Streamlit versions; an always-visible
# expander is more SiS-portable and still feels like a chat panel.
st.markdown("<div style='height:24px'></div>", unsafe_allow_html=True)
with st.expander("💬  Ask the Counterparty Oversight Agent", expanded=False):
    st.caption("Ask anything about TPO risk, guidelines, or remediation. Powered by V3 agent.")
    for q_text, a_text in st.session_state.agent_history:
        with st.chat_message("user"):
            st.write(q_text)
        with st.chat_message("assistant"):
            st.markdown(a_text)
    user_q = st.chat_input("Type a question...")
    if user_q:
        with st.spinner("Calling agent..."):
            try:
                answer = call_agent(user_q)
            except Exception as e:
                answer = f"Agent call failed: {e}"
        st.session_state.agent_history.append((user_q, answer))
        st.rerun()
