# V7 - Snowflake Intelligence talk track

## Setup (90 seconds)
1. In Snowsight, navigate to **AI & ML -> Snowflake Intelligence**.
2. Create a workspace named "Optimal Blue - Comergence".
3. Add the agent: `OPTIMAL_BLUE_DEMO.AI.COUNTERPARTY_AGENT`.
4. Add the semantic views:
   - `OPTIMAL_BLUE_DEMO.AI.TPO_RISK_SV` (V1)
   - `OPTIMAL_BLUE_DEMO.AI.TPO_PERFORMANCE_SV` (V7)
5. Add the search service: `OPTIMAL_BLUE_DEMO.AI.COMPLIANCE_CSS` (V2).

## Closing prompts to run live (3-4 minutes)

1. *"Show me my riskiest TPOs and how they're performing on locks."*
   - SI orchestrates V7 SV -> V4 join logic.

2. *"For the top 5 by funded volume, are there any open audit findings or expiring licenses?"*
   - SI uses TPO_RISK_SV + REMEDIATION_LOOKUP via the agent.

3. *"Which guideline policies most affect FHA pull-through this quarter?"*
   - SI cites Cortex Search + analytic context.

## The close (60 seconds)

> "Same governed data, three surfaces:
>  - Cortex Code built it.
>  - Streamlit visualizes it.
>  - Snowflake Intelligence answers any question over it.
>  All grounded in one Snowflake foundation, all reproducible from the
>  prompt contracts in this workspace - including on your trial instance,
>  starting tomorrow."
