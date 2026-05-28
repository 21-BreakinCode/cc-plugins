---
name: ecommerce-orders
domain: ecommerce
description: E-commerce order data with products, customers, and transactions
---

## Context

- This data represents order-level transactions from an online store
- `order_id`: unique per order, one row per order line item (so one order can have multiple rows)
- `customer_id`: unique per customer, links to customer profile
- `order_date`: when the order was placed (UTC)
- `product_category`: top-level category (Electronics, Clothing, Home, Food, Sports)
- `quantity`: units ordered per line item
- `unit_price`: price per unit in USD (already in dollars, not cents)
- `total_amount`: quantity * unit_price (pre-tax, pre-discount)
- `discount_pct`: discount applied as percentage (0-100), loyalty and promo combined
- `region`: customer shipping region (North, South, East, West, International)
- `channel`: acquisition channel (organic, paid_search, social, email, referral)
- Data is from the company's Shopify export, refreshed daily

## Expected Patterns

- Order volume drops 30-50% on weekends — this is normal for B2B-heavy categories
- Electronics category has higher average order value but lower volume than Clothing
- International orders have higher discount_pct (10-15%) vs domestic (3-8%) due to market entry pricing
- Q4 (Oct-Dec) volume is 2-3x other quarters due to holiday season
- `discount_pct` of 0 is common (~40% of orders) — not all orders have promotions
- Referral channel has the highest conversion but lowest volume — this is expected

## Key Metrics

- Average Order Value (AOV): total_amount per order_id, healthy = $50-150
- Discount rate: average discount_pct, target = <10% blended
- Orders per customer: order count / distinct customers, healthy = >1.3 (indicates repeat purchases)
- Category concentration: top category should be <40% of total revenue (diversification)
- Regional balance: no single region should exceed 50% of orders

## Steps

1. Check data freshness and completeness — any gaps in order_date?
2. Compute AOV trend by month — is it growing or shrinking?
3. Break down revenue by product_category and region
4. Analyze discount impact — does higher discount_pct correlate with repeat purchases?
5. Identify top customer segments by channel and region
6. Flag any anomalies against the expected patterns above
