# V2 - Sample Cortex Search queries

Use these in Snowsight to demo `AI.COMPLIANCE_CSS`:

1. "FHA overlay credit score requirements"
2. "VA cash-out refi LTV cap"
3. "social media policy on guaranteed approval language"
4. "best execution rationale documentation"
5. "BSA AML reporting thresholds"

Sample social-flag drilldown after V2 runs:

```sql
SELECT compliance_risk, sentiment, COUNT(*) AS posts
FROM COMERGENCE.SOCIAL_FLAG
GROUP BY 1,2
ORDER BY 1, posts DESC;
```

```sql
SELECT post_text, topic, compliance_risk
FROM COMERGENCE.SOCIAL_FLAG
WHERE compliance_risk = 'HIGH - likely violation'
LIMIT 10;
```
