---
name: my-playbook-name
domain: e.g., ecommerce, healthcare, fintech, saas, logistics
description: One-line description of what this playbook covers
---

## Context

Describe the business domain and what the data represents. This section teaches the
analysis skill your internal vocabulary so it can interpret findings correctly.

Include:
- What each important column means in your business context
- Key business definitions (e.g., "churn = no login in 60 days")
- Who generates this data and how (e.g., "exported from Salesforce weekly")
- Any known data quirks (e.g., "amounts are in cents, not dollars")

Example:
```
- `status` column: 1=active, 2=paused, 3=cancelled, 4=expired
- `revenue` is monthly recurring revenue (MRR) in USD cents
- Data is exported from Stripe every Monday morning, so weekend transactions
  appear in the following Monday's export
```

## Expected Patterns

Patterns that are NORMAL in your business and should NOT be flagged as anomalies.
Without this section, the analysis skill might raise false alarms on patterns that
are perfectly expected in your domain.

Example:
```
- Stage A count < Stage B count is normal because Stage A excludes
  self-serve signups while Stage B includes all sources
- Transaction volume drops 40-60% on weekends — this is expected
- Q4 revenue is typically 2-3x other quarters due to annual renewals
- Null values in `referral_source` are expected for organic traffic (~30%)
```

## Key Metrics (optional)

Define the metrics that matter and what good/bad looks like. This helps the
Yellow Hat (findings) phase focus on what your business actually cares about.

Example:
```
- Conversion rate: signups / visitors, healthy = >3%, concerning = <1.5%
- Average order value: revenue / orders, target = $85-120
- Churn rate: cancelled / total active, healthy = <5% monthly
```

## Steps (optional)

If present, these steps OVERRIDE the default analysis plan (Blue Hat).
Use this when your team has a specific analysis workflow they always follow.

Example:
```
1. Check data freshness — latest record should be within 24 hours
2. Compute MRR by cohort month
3. Calculate month-over-month retention by cohort
4. Flag any cohort with retention below 70% at month 3
5. Break down churn reasons by plan tier
```
