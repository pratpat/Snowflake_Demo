# Sample Questions for Fabric Data Agent — Capital Markets

Grouped by complexity. Use these to test or demo a Data Agent built on the
8-table Capital Markets dataset.

## 1. Basic Lookup & Filter
1. How many securities do we trade?
2. List all clients in Germany.
3. Show the top 10 trades by notional today.
4. Which trading desks do we have?
5. What is the AUM of client `C00000123`?
6. Show me all positions for account `A000001234`.
7. Which exchanges do we list securities on?
8. List all hedge fund clients.

## 2. Aggregations & Rankings
9. What is the total notional traded last week?
10. Top 5 traders by total notional traded this month.
11. Average bid-ask spread per exchange today.
12. Total unrealized P&L by client type.
13. Top 10 securities by trading volume in the last 30 days.
14. Which sector had the highest dollar volume yesterday?
15. Average trade size (notional) by order type.
16. Count of cancelled vs filled trades by venue.

## 3. Time-Series & Trends
17. Show the daily traded notional for the past 30 days.
18. Plot the closing price of `AAPL` over the last 6 months.
19. Which securities had the highest volatility last week?
20. Day-over-day change in total trade count.
21. Hourly trade volume profile for the last 5 days.
22. Trend of total AUM by quarter for the last 2 years.
23. Compare today's trading volume vs the same day last week.

## 4. Joins Across Tables (ontology-powered)
24. Which clients have the largest exposure to the Technology sector?
25. Total notional traded per trader's region.
26. Show me top 5 institutional clients by realized trading volume.
27. Which sectors are most traded on the EMEA desk?
28. List positions held by hedge fund clients in the Energy sector.
29. For each industry, show count of distinct securities and total trades.
30. Average client AUM by KYC tier and country.

## 5. Risk & Compliance
31. Find clients with concentration risk — any single position > 25% of portfolio MV.
32. Identify trades larger than 10x the average trade size for that security.
33. Which accounts have negative unrealized P&L greater than $1M?
34. Show trades placed outside regular market hours.
35. Alert on traders whose daily notional exceeds $50M.
36. Identify wash-trade candidates: same account buying and selling the same security within 60s.
37. Top 10 risky clients (high AUM, aggressive risk profile, large unrealized losses).

## 6. Market Microstructure
38. Average bid-ask spread for the most actively quoted symbols today.
39. Which venue offers the tightest spreads on average?
40. Time-weighted average price (TWAP) of `MSFT` over the last 5 days.
41. Quote update frequency per second per security — top 10.
42. Bid-ask imbalance by sector.

## 7. Portfolio & Performance
43. Show portfolio composition for client `C00001234` by sector.
44. Top performing accounts by unrealized P&L this quarter.
45. Average position size by account type.
46. List clients whose portfolio is concentrated in a single country.
47. Generate a P&L report by trader region.
48. Which positions have moved more than 20% from their average cost?

## 8. Cross-Domain "Why" Questions
49. Why did total trading volume drop yesterday?
50. Explain the spike in cancelled trades this morning.
51. Which factors are driving the high P&L for trader `T0007`?
52. Compare the trading patterns of pension funds vs hedge funds.
53. Has anything unusual happened in the Technology sector this week?
54. Summarize today's trading activity for an executive briefing.

## 9. Forecasting & ML-style
55. Forecast next week's daily volume for `NVDA`.
56. Detect anomalies in trade prices for the last 24 hours.
57. Cluster clients by trading behavior.
58. Predict end-of-day price for `AAPL` based on intraday quotes.

## 10. Operational / Meta
59. How fresh is the trades table?
60. How many rows are in each table?
61. Show the schema of `positions`.
62. Which tables are sourced from Snowflake vs native to Fabric?
63. Top 10 most-queried securities this week.

---

## Recommended Demo Script (10 questions)

| # | Question | Demonstrates |
|---|---|---|
| 1 | Show me total notional traded today by sector. | Aggregations + dim join |
| 2 | Top 5 clients by AUM in EMEA. | Filter + ranking + region hierarchy |
| 3 | Which trader has the largest exposure to Technology? | Multi-hop join |
| 4 | Plot daily trading volume for the past month. | Visualization + time series |
| 5 | Find clients with positions > 25% of portfolio value. | Window functions + risk logic |
| 6 | Average bid-ask spread for XNAS-listed securities. | Streaming-style data |
| 7 | Compare today's trading vs same day last week. | Temporal comparison |
| 8 | Why did volume spike at 14:00 today? | Agentic reasoning |
| 9 | Generate an executive summary of today's market activity. | Narrative generation |
| 10 | Forecast next week's average daily volume. | ML / Copilot integration |
