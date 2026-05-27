# V3 - Counterparty Oversight Agent demo script

Run these prompts live in Snowsight's Agent Run UI.

## The five money prompts

1. **Structured KPI** -
   *"How many TPOs in Texas have licenses expiring within 30 days AND open high-severity findings?"*
   Expected: agent picks `TPO_RISK_SV`, returns a single number with a small breakout.

2. **Document lookup** -
   *"Summarize the FHA overlay differences between Investor 005 and Investor 042 from our guideline documents."*
   Expected: agent picks `COMPLIANCE_SEARCH`, cites titles + chunk text.

3. **Cross-tool** -
   *"Has TPO 2210 had any open audit findings in the last 60 days, and which investors are they exposed to?"*
   Expected: agent calls `TPO_RISK_SV` for both metrics in one composed query.

4. **Remediation drafting** -
   *"Draft a remediation note for TPO 2210 referencing the most recent open high-severity findings."*
   Expected: agent calls `TPO_RISK_SV` to fetch open / high-severity findings for that TPO and formats a 4-bullet remediation note. Note: the analyst tool composes the SQL on the fly (no dedicated function tool).

5. **Onboarding bottleneck** -
   *"Which onboarding stage is slowest on average, and which 5 TPOs are stuck there longest?"*
   Expected: agent uses `TPO_RISK_SV` for the metric and follow-up SQL.

6. **Out-of-scope refusal** -
   *"What rate should I lock today on a 30-year FHA in Texas?"*
   Expected: agent politely declines (this is a PPE / capital markets
   question, not a Comergence oversight question), suggests reframing.

## Talk-track moments

- After prompt 2: highlight that the agent is citing real chunk titles -
  this is governed grounding, not hallucination.
- After prompt 4: note that we never wrote SQL by hand - the analyst tool
  generated the per-TPO finding lookup from the semantic view. Same
  governed metrics, no extra plumbing.
- After prompt 6: show the refusal as proof of guardrails - "this is how
  enterprise agents stay in their lane."
