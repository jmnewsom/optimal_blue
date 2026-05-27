"""
Optimal Blue / Comergence - Counterparty Risk Dashboard
Generated from vignettes/06_streamlit_dashboard/prompt-contract.md.

Run as: OB_DEMO_RW @ OB_DEMO_WH @ OPTIMAL_BLUE_DEMO.AI

Talking points:
  - One app surfaces all 7 vignettes' value props.
  - Built from a prompt contract; regenerable, reviewable, repeatable.
  - Optimal Blue navy/magenta theme to feel native.
"""

import streamlit as st
import pandas as pd
import altair as alt
from snowflake.snowpark.context import get_active_session

# ---------- Theme ----------
OB_NAVY    = "#0B1E3F"
OB_MAGENTA = "#E6007E"
OB_LIGHT   = "#F4F6FB"

st.set_page_config(
    page_title="Comergence | Counterparty Risk",
    page_icon="🛡️",
    layout="wide",
)

st.markdown(
    f"""
    <style>
      .ob-kpi {{
          background: white; border: 1px solid #E5E7EB; border-radius: 12px;
          padding: 16px 18px; box-shadow: 0 1px 2px rgba(0,0,0,0.04);
      }}
      .ob-kpi .label  {{ color: {OB_NAVY}; font-size: 0.85rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.04em; }}
      .ob-kpi .value  {{ color: {OB_MAGENTA}; font-size: 1.9rem; font-weight: 700; line-height: 1.1; }}
      .ob-kpi .sub    {{ color: #6B7280; font-size: 0.85rem; }}
      .stApp {{ background-color: {OB_LIGHT}; }}
    </style>
    """,
    unsafe_allow_html=True,
)

session = get_active_session()

st.markdown(
    f"<h1 style='color:{OB_NAVY};margin-bottom:0;'>Comergence Counterparty Risk</h1>"
    f"<p style='color:#6B7280;margin-top:4px;'>Powered by Snowflake - Optimal Blue demo</p>",
    unsafe_allow_html=True,
)

# ---------- KPI helpers ----------
def kpi(col, label, value, sub=""):
    col.markdown(
        f"<div class='ob-kpi'><div class='label'>{label}</div>"
        f"<div class='value'>{value}</div>"
        f"<div class='sub'>{sub}</div></div>",
        unsafe_allow_html=True,
    )

@st.cache_data(ttl=300)
def fetch_kpis():
    sql = """
    WITH perf AS (
      SELECT * FROM OPTIMAL_BLUE_DEMO.SHARED.TPO_PERFORMANCE_V
    ), social AS (
      SELECT COUNT_IF(compliance_risk = 'HIGH - likely violation'
                      AND posted_at >= DATEADD('day',-7,CURRENT_TIMESTAMP())) AS social_high_7d
      FROM OPTIMAL_BLUE_DEMO.COMERGENCE.SOCIAL_FLAG
    ), volume AS (
      SELECT SUM(note_amount) AS funded_30d
      FROM OPTIMAL_BLUE_DEMO.PPE.LOCK
      WHERE lock_status = 'FUNDED'
        AND funded_at >= DATEADD('day',-30,CURRENT_TIMESTAMP())
    )
    SELECT
      (SELECT COUNT_IF(tpo_status='ACTIVE' AND compliance_score >= 80) FROM perf) AS good_standing,
      (SELECT SUM(high_severity_findings) FROM perf)                              AS hi_findings,
      (SELECT SUM(licenses_expiring_30d)  FROM perf)                              AS exp_30,
      (SELECT social_high_7d FROM social)                                         AS social_high_7d,
      (SELECT AVG(pull_through_pct) FROM perf WHERE total_locks > 0)              AS avg_pt,
      (SELECT funded_30d FROM volume)                                             AS funded_30d
    """
    return session.sql(sql).to_pandas().iloc[0]

k = fetch_kpis()

c1, c2, c3, c4, c5, c6 = st.columns(6)
kpi(c1, "TPOs in Good Standing",  f"{int(k['GOOD_STANDING']):,}",     "active & score >= 80")
kpi(c2, "High-Severity Findings", f"{int(k['HI_FINDINGS']):,}",       "open + in remediation")
kpi(c3, "Licenses Expiring 30d",  f"{int(k['EXP_30']):,}",            "across all states")
kpi(c4, "Social Flags (7d)",      f"{int(k['SOCIAL_HIGH_7D']):,}",    "AI_CLASSIFY = HIGH risk")
kpi(c5, "Avg Pull-through",       f"{(k['AVG_PT'] or 0):.1f}%",       "TPOs with locks only")
kpi(c6, "Funded Volume (30d)",    f"${(k['FUNDED_30D'] or 0)/1e9:.2f}B", "PPE - cross-org bridge")

st.divider()

# ---------- Charts ----------
@st.cache_data(ttl=300)
def findings_by_region():
    return session.sql("""
        SELECT s.region, COUNT_IF(a.severity='HIGH' AND a.status<>'CLOSED') AS hi_findings
        FROM OPTIMAL_BLUE_DEMO.COMERGENCE.AUDIT_FINDING a
        JOIN OPTIMAL_BLUE_DEMO.COMERGENCE.TPO t   ON t.tpo_id = a.tpo_id
        JOIN OPTIMAL_BLUE_DEMO.COMERGENCE.STATE s ON s.state_code = t.state_code
        GROUP BY 1 ORDER BY 1
    """).to_pandas()

@st.cache_data(ttl=300)
def score_vs_pt():
    return session.sql("""
        SELECT compliance_score, pull_through_pct, risk_tier, funded_volume_usd
        FROM OPTIMAL_BLUE_DEMO.SHARED.TPO_PERFORMANCE_V
        WHERE total_locks > 5
        SAMPLE (5000 ROWS)
    """).to_pandas()

@st.cache_data(ttl=300)
def onboarding_funnel():
    return session.sql("""
        SELECT stage, AVG(duration_days) AS avg_days, COUNT(*) AS events
        FROM OPTIMAL_BLUE_DEMO.COMERGENCE.ONBOARDING_EVENT
        GROUP BY stage
        ORDER BY MIN(occurred_at)
    """).to_pandas()

@st.cache_data(ttl=300)
def social_trend():
    return session.sql("""
        SELECT DATE_TRUNC('day', posted_at) AS d,
               COUNT_IF(compliance_risk = 'HIGH - likely violation') AS high_n,
               COUNT(*) AS total_n
        FROM OPTIMAL_BLUE_DEMO.COMERGENCE.SOCIAL_FLAG
        WHERE posted_at >= DATEADD('day',-30,CURRENT_TIMESTAMP())
        GROUP BY 1 ORDER BY 1
    """).to_pandas()

cA, cB = st.columns(2)
with cA:
    st.markdown("#### High-Severity Findings by Region")
    df = findings_by_region()
    chart = alt.Chart(df).mark_bar(color=OB_MAGENTA).encode(
        x=alt.X("REGION:N", sort="-y", title=None),
        y=alt.Y("HI_FINDINGS:Q", title="High-severity findings"),
        tooltip=["REGION", "HI_FINDINGS"],
    ).properties(height=280)
    st.altair_chart(chart, use_container_width=True)

with cB:
    st.markdown("#### Compliance Score vs Pull-through")
    df = score_vs_pt()
    if not df.empty:
        chart = alt.Chart(df).mark_circle(opacity=0.6).encode(
            x=alt.X("COMPLIANCE_SCORE:Q", title="Compliance score"),
            y=alt.Y("PULL_THROUGH_PCT:Q", title="Pull-through %"),
            color=alt.Color("RISK_TIER:N",
                            scale=alt.Scale(domain=["LOW","MED","HIGH"],
                                            range=["#1F8A4C", OB_NAVY, OB_MAGENTA])),
            tooltip=["COMPLIANCE_SCORE","PULL_THROUGH_PCT","RISK_TIER"],
        ).properties(height=280)
        st.altair_chart(chart, use_container_width=True)

cC, cD = st.columns(2)
with cC:
    st.markdown("#### Onboarding Funnel - Avg Days per Stage")
    df = onboarding_funnel()
    chart = alt.Chart(df).mark_bar(color=OB_NAVY).encode(
        x=alt.X("STAGE:N", sort=None, title=None),
        y=alt.Y("AVG_DAYS:Q", title="Avg days"),
        tooltip=["STAGE","AVG_DAYS","EVENTS"],
    ).properties(height=280)
    st.altair_chart(chart, use_container_width=True)

with cD:
    st.markdown("#### Social-flag Trend (30d)")
    df = social_trend()
    chart = alt.Chart(df).mark_line(color=OB_MAGENTA, point=True).encode(
        x=alt.X("D:T", title=None),
        y=alt.Y("HIGH_N:Q", title="HIGH-risk posts"),
        tooltip=["D","HIGH_N","TOTAL_N"],
    ).properties(height=280)
    st.altair_chart(chart, use_container_width=True)

st.divider()

# ---------- TPO drill-through ----------
st.markdown("### Drill into a TPO")

@st.cache_data(ttl=300)
def tpo_options():
    return session.sql("""
        SELECT tpo_id, tpo_name FROM OPTIMAL_BLUE_DEMO.COMERGENCE.TPO ORDER BY tpo_id LIMIT 200
    """).to_pandas()

opts = tpo_options()
if not opts.empty:
    pick = st.selectbox("Choose a TPO", opts["TPO_NAME"] + "  (#" + opts["TPO_ID"].astype(str) + ")")
    tpo_id = int(pick.split("#")[-1].rstrip(")"))

    perf = session.sql(f"""
        SELECT * FROM OPTIMAL_BLUE_DEMO.SHARED.TPO_PERFORMANCE_V WHERE tpo_id = {tpo_id}
    """).to_pandas()
    findings = session.sql(f"""
        SELECT finding_date, severity, category, status, finding_text
        FROM OPTIMAL_BLUE_DEMO.COMERGENCE.AUDIT_FINDING
        WHERE tpo_id = {tpo_id} ORDER BY finding_date DESC LIMIT 15
    """).to_pandas()
    flags = session.sql(f"""
        SELECT posted_at, platform, compliance_risk, sentiment, post_text
        FROM OPTIMAL_BLUE_DEMO.COMERGENCE.SOCIAL_FLAG
        WHERE tpo_id = {tpo_id} ORDER BY posted_at DESC LIMIT 15
    """).to_pandas()

    if not perf.empty:
        row = perf.iloc[0]
        d1, d2, d3, d4 = st.columns(4)
        kpi(d1, "Compliance Score",  f"{int(row['COMPLIANCE_SCORE'])}",   row["RISK_TIER"])
        kpi(d2, "Pull-through",      f"{row['PULL_THROUGH_PCT']:.1f}%",   f"{int(row['FUNDED_LOCKS'])} funded")
        kpi(d3, "Open Findings",     f"{int(row['OPEN_FINDINGS'])}",      f"{int(row['HIGH_SEVERITY_FINDINGS'])} high sev")
        kpi(d4, "Funded Volume",     f"${row['FUNDED_VOLUME_USD']/1e6:.1f}M", f"{int(row['INVESTOR_BREADTH'])} investors")

    f1, f2 = st.columns(2)
    with f1:
        st.markdown("**Recent audit findings**")
        st.dataframe(findings, hide_index=True, use_container_width=True)
    with f2:
        st.markdown("**Recent social flags**")
        st.dataframe(flags, hide_index=True, use_container_width=True)
