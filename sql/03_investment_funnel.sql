-- =====================================================================
-- 03_investment_funnel.sql
-- Investly (fictional investment app) - Mutual fund investment funnel
-- Question: Once users reach mutual funds, where do they abandon the
--           journey to their first investment?
-- Uses clean tables from 01b_clean_data.sql.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Design choices
-- * Only Mutual Fund events are included (product_type filter), so later
--   stock / ETF investments don't mix into an MF funnel.
-- * mf_search and mf_calculator_used are NOT funnel steps. They are
--   optional: users can invest without them. Including them would show
--   fake "drop-offs" from users who simply skipped an optional feature.
--   They are analysed separately in 06_product_usage.sql.
-- * Counts are unique users (COUNT DISTINCT), not events.
--
-- Result:
--   discovered 3,867 -> viewed a fund 3,684 -> started 1,306 -> completed 901
--
--   Discovery -> Fund detail view      95.3%
--   Fund detail view -> Invest started 35.5%   (lowest in entire journey)
--   Invest started -> Completed        69.0%
--   Overall discovery -> invested      23.3%
--
--   End to end: 901 of 10,000 signups (9.0%) made an MF investment.
--
-- Findings:
-- 1. Decision drop-off: 2,378 users viewed a fund but never started an
--    investment. Only about 1 in 3 fund viewers moves forward.
--    Possible causes to investigate (not proven): unclear fund info,
--    perceived risk, too many choices, minimum amount, low trust.
-- 2. Checkout drop-off: 405 users (31%) started an investment but did
--    not complete it. These users had clear intent, so losses here are
--    likely friction (payment failure, mandate setup, errors) and are
--    probably the cheapest to recover.
-- 3. Discovery -> view is healthy (95%); users are not getting lost
--    before seeing funds.
-- These are observed patterns, not causal explanations.
-- ---------------------------------------------------------------------
WITH mf AS (
  SELECT
    COUNT(DISTINCT CASE WHEN event_name = 'mf_discovery'         THEN user_id END) AS discovered,
    COUNT(DISTINCT CASE WHEN event_name = 'mf_detail_view'       THEN user_id END) AS viewed_fund,
    COUNT(DISTINCT CASE WHEN event_name = 'investment_started'   THEN user_id END) AS started,
    COUNT(DISTINCT CASE WHEN event_name = 'investment_completed' THEN user_id END) AS completed
  FROM events_clean
  WHERE product_type = 'Mutual Fund'
)
SELECT
  discovered, viewed_fund, started, completed,
  ROUND(100.0 * viewed_fund / discovered, 1)  AS pct_discovery_to_view,
  ROUND(100.0 * started     / viewed_fund, 1) AS pct_view_to_start,
  ROUND(100.0 * completed   / started, 1)     AS pct_start_to_complete,
  ROUND(100.0 * completed   / discovered, 1)  AS pct_overall
FROM mf;
