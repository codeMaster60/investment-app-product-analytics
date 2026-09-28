-- =====================================================================
-- 06_product_usage.sql
-- Investly (fictional investment app) - Feature usage vs investing
-- Question: Do users who use the SIP calculator, search, or watchlist
--           invest more often than users who don't?
-- Uses clean tables from 01b_clean_data.sql.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Fair comparison design
-- Only users who viewed at least one fund (mf_detail_view) are compared.
-- Calculator users have, by definition, already reached a fund page;
-- comparing them against ALL users would inflate the gap simply because
-- one group is further down the funnel.
--
-- UNION ALL stacks three separate comparisons into one result table.
--
-- Result (among 3,684 users who viewed a fund):
--   Feature     Used?  Users  Invested
--   Calculator   no    2,705   18.3%
--   Calculator   yes     979   41.5%   (2.3x - biggest gap)
--   Watchlist    no    2,446   20.2%
--   Watchlist    yes   1,238   33.0%
--   Search       no    1,658   21.7%
--   Search       yes   2,026   26.7%   (small gap)
--
-- Findings:
-- 1. Calculator users invested at 2.3x the rate of non-users.
--    Only ~27% of fund viewers use it (979 of 3,684).
-- 2. Watchlist users also invest more (33.0% vs 20.2%).
-- 3. Search shows only a small difference.
--
-- IMPORTANT - correlation, not causation:
-- This analysis identifies behavioural associations and does not
-- establish causality. Users who open the calculator may simply be
-- more serious about investing already (self-selection). Making every
-- user see the calculator will not necessarily produce the same lift.
-- Watchlist caveat: some watchlist adds happen in later sessions,
-- possibly after a user has already invested, so the order of events
-- is not controlled here.
--
-- Product implication: the calculator is the strongest candidate for
-- a controlled A/B test (e.g. show SIP projection directly on the fund
-- page) to find out whether it actually CAUSES more investing.
-- ---------------------------------------------------------------------
WITH u AS (
  SELECT user_id,
    MAX(CASE WHEN event_name = 'mf_detail_view'     THEN 1 ELSE 0 END) AS viewed,
    MAX(CASE WHEN event_name = 'mf_calculator_used' THEN 1 ELSE 0 END) AS used_calc,
    MAX(CASE WHEN event_name = 'mf_search'          THEN 1 ELSE 0 END) AS searched,
    MAX(CASE WHEN event_name = 'watchlist_added'    THEN 1 ELSE 0 END) AS watchlisted,
    MAX(CASE WHEN event_name = 'investment_completed'
             AND product_type = 'Mutual Fund'       THEN 1 ELSE 0 END) AS invested
  FROM events_clean
  GROUP BY user_id
)
SELECT 'calculator' AS feature, used_calc AS used, COUNT(*) AS users,
       ROUND(100.0 * SUM(invested) / COUNT(*), 1) AS invest_pct
FROM u WHERE viewed = 1 GROUP BY used_calc
UNION ALL
SELECT 'search', searched, COUNT(*),
       ROUND(100.0 * SUM(invested) / COUNT(*), 1)
FROM u WHERE viewed = 1 GROUP BY searched
UNION ALL
SELECT 'watchlist', watchlisted, COUNT(*),
       ROUND(100.0 * SUM(invested) / COUNT(*), 1)
FROM u WHERE viewed = 1 GROUP BY watchlisted
ORDER BY feature, used;
