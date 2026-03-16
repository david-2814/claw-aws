---
name: cost-explorer
description: Analyze AWS costs, usage, forecasts, and savings opportunities via AWS Cost Explorer CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "💰",
        "requires": { "bins": ["aws"] },
      },
  }
---

# AWS Cost Explorer

Use this skill for cost analysis: viewing spending by service/account/tag, forecasting future costs, finding savings opportunities, analyzing Reserved Instance and Savings Plan utilization, and identifying cost anomalies.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `ce:*` for full access (Cost Explorer APIs)
- Cost Explorer must be activated in the AWS console (free, but takes 24h for data)
- Most Cost Explorer APIs operate in `us-east-1` regardless of resource region

## Common Operations

### View Costs (Read-Only)

```bash
# Get total cost for the current month
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --region us-east-1

# Get daily costs for the last 7 days
aws ce get-cost-and-usage \
  --time-period Start=$(date -v-7d +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics UnblendedCost \
  --region us-east-1

# Get costs broken down by service
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --region us-east-1

# Get costs by linked account (for Organizations)
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=LINKED_ACCOUNT \
  --region us-east-1

# Get costs by region
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=REGION \
  --region us-east-1

# Get costs by tag
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=TAG,Key=Environment \
  --region us-east-1

# Get costs for a specific service
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics UnblendedCost \
  --filter '{"Dimensions": {"Key": "SERVICE", "Values": ["Amazon Elastic Compute Cloud - Compute"]}}' \
  --region us-east-1

# Get last month's total
aws ce get-cost-and-usage \
  --time-period Start=$(date -v-1m +%Y-%m-01),End=$(date +%Y-%m-01) \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --region us-east-1
```

### Forecasts

```bash
# Forecast cost for the rest of the month
aws ce get-cost-forecast \
  --time-period Start=$(date +%Y-%m-%d),End=$(date -v+1m +%Y-%m-01) \
  --granularity MONTHLY \
  --metric UNBLENDED_COST \
  --region us-east-1

# Forecast with prediction intervals
aws ce get-cost-forecast \
  --time-period Start=$(date +%Y-%m-%d),End=$(date -v+1m +%Y-%m-01) \
  --granularity MONTHLY \
  --metric UNBLENDED_COST \
  --prediction-interval-level 80 \
  --region us-east-1
```

### Savings Recommendations

```bash
# Get right-sizing recommendations
aws ce get-rightsizing-recommendation \
  --service "AmazonEC2" \
  --region us-east-1

# Get Savings Plans recommendations
aws ce get-savings-plans-purchase-recommendation \
  --savings-plans-type COMPUTE_SP \
  --term-in-years ONE_YEAR \
  --payment-option NO_UPFRONT \
  --lookback-period-in-days SIXTY_DAYS \
  --region us-east-1

# Get Reserved Instance recommendations
aws ce get-reservation-purchase-recommendation \
  --service "Amazon Elastic Compute Cloud - Compute" \
  --term-in-years ONE_YEAR \
  --payment-option NO_UPFRONT \
  --lookback-period-in-days SIXTY_DAYS \
  --region us-east-1

# Get RI utilization
aws ce get-reservation-utilization \
  --time-period Start=$(date -v-30d +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --region us-east-1

# Get Savings Plans utilization
aws ce get-savings-plans-utilization \
  --time-period Start=$(date -v-30d +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --region us-east-1
```

### Cost Anomalies

```bash
# List cost anomaly monitors
aws ce get-anomaly-monitors --region us-east-1

# List recent anomalies
aws ce get-anomalies \
  --date-interval '{"StartDate": "'$(date -v-30d +%Y-%m-%d)'", "EndDate": "'$(date +%Y-%m-%d)'"}' \
  --region us-east-1

# Create an anomaly monitor (by service)
aws ce create-anomaly-monitor \
  --anomaly-monitor '{
    "MonitorName": "ServiceMonitor",
    "MonitorType": "DIMENSIONAL",
    "MonitorDimension": "SERVICE"
  }' \
  --region us-east-1

# Create an anomaly subscription (email alerts)
aws ce create-anomaly-subscription \
  --anomaly-subscription '{
    "SubscriptionName": "CostAlerts",
    "MonitorArnList": ["<monitor-arn>"],
    "Subscribers": [{"Type": "EMAIL", "Address": "<email>"}],
    "Threshold": 100,
    "Frequency": "DAILY"
  }' \
  --region us-east-1
```

### Budgets

```bash
# List budgets
aws budgets describe-budgets \
  --account-id <account-id> \
  --query 'Budgets[].{Name:BudgetName,Limit:BudgetLimit.Amount,Actual:CalculatedSpend.ActualSpend.Amount}' \
  --output table

# Create a monthly budget with alert
aws budgets create-budget \
  --account-id <account-id> \
  --budget '{
    "BudgetName": "MonthlyBudget",
    "BudgetLimit": {"Amount": "1000", "Unit": "USD"},
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST"
  }' \
  --notifications-with-subscribers '[{
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 80,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [{"SubscriptionType": "EMAIL", "Address": "<email>"}]
  }]'
```

## Safety Rules

1. **NEVER** expose or log AWS credentials, access keys, or secret keys.
2. **NEVER** share cost data in group chats without explicit permission (it may be sensitive).
3. **ALWAYS** use `us-east-1` region for Cost Explorer API calls.
4. **ALWAYS** clarify whether the user wants blended, unblended, or amortized costs.
5. **NOTE** that cost data can be up to 24 hours delayed.

## Best Practices

- Set up AWS Budgets with alerts before costs become a problem.
- Use cost allocation tags (Environment, Team, Project) to track spending by business unit.
- Review right-sizing recommendations monthly — oversized instances are the #1 waste.
- Use Savings Plans (Compute SP) over Reserved Instances for flexibility.
- Enable Cost Anomaly Detection to catch unexpected spikes early.

## Common Patterns

### Pattern: Monthly Cost Summary Report

```bash
# Top 5 services this month
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --region us-east-1 \
  --query 'ResultsByTime[0].Groups | sort_by(@, &Metrics.UnblendedCost.Amount) | [-5:].[Keys[0], Metrics.UnblendedCost.Amount]' \
  --output table
```

### Pattern: Month-over-Month Comparison

```bash
# This month
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY --metrics UnblendedCost --region us-east-1

# Last month
aws ce get-cost-and-usage \
  --time-period Start=$(date -v-1m +%Y-%m-01),End=$(date +%Y-%m-01) \
  --granularity MONTHLY --metrics UnblendedCost --region us-east-1
```

### Pattern: Find Untagged Resource Costs

```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=TAG,Key=Environment \
  --region us-east-1
# Resources without the "Environment" tag show as empty key
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `DataUnavailableException` | Cost Explorer not activated or data not ready | Activate in console; wait 24h for initial data |
| `BillExpirationException` | Querying beyond available billing data | Check date range; data typically available for 12 months |
| `RequestChangedException` | Forecast date range in the past | End date must be in the future for forecasts |
| `UnresolvableUsageUnitException` | Invalid metric or dimension combination | Check supported metrics: BlendedCost, UnblendedCost, AmortizedCost, UsageQuantity |
| Empty results for tags | Tags not activated for billing | Activate cost allocation tags in Billing console |
