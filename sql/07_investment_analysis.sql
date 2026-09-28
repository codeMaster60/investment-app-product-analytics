-- =====================================================================
-- 07_investment_analysis.sql
-- Investly (fictional investment app) - Repeat investing & MF categories
-- Questions:
--   1. What separates one-time investors from repeat investors?
--   2. How long do users wait before investing again?
--   3. Which fund categories get attention but don't convert?
-- Uses clean tables from 01b_clean_data.sql.
-- =====================================================================


-- ---------------------------------------------------------------------
-- PART A: ROW_NUMBER() - number each user's investments in time order
-- PARTITION BY user_id -> restart numbering for each user
-- ORDER BY date, id    -> oldest first; id breaks same-day ties
-- Unlike GROUP BY, a window function keeps every row and adds a column.
-- Example seen: U00056 = SIP (#1), manual lumpsum (#2), then monthly
-- SIP auto-debits (#3-#9). U00033 started a SIP with no further debits.
-- ---------------------------------------------------------------------
SELECT user_id, investment_date, investment_type, amount, source,
       ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY investment_date, investment_id) AS inv_number
FROM investments_clean
ORDER BY user_id, inv_number
LIMIT 15;


-- ---------------------------------------------------------------------
-- PART B: One-time vs repeat investors, by first investment type
-- Definitions:
--   any repeat    = investments on 2+ different days (incl. SIP auto-debits)
--   manual repeat = 2+ different days where the USER invested in the app
--
-- Result:
--   First type  Investors  Avg first amt  Any repeat  Manual repeat
--   Lumpsum        465       Rs 12,044       43.2%        42.8%
--   SIP            436        Rs 2,664       91.3%        39.2%
--
-- Finding: SIP's 91% "repeat rate" is almost entirely automatic
-- debits. On actively choosing to invest again, SIP and lumpsum users
-- are similar (39% vs 43%). Counting auto-debits as engagement would
-- badly overstate SIP loyalty. For SIP, the right metric is SIP
-- persistence (does the mandate keep running), not repeat rate.
-- ---------------------------------------------------------------------
WITH ranked AS (
  SELECT user_id, investment_date, investment_type, amount, source,
         ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY investment_date, investment_id) AS inv_number
  FROM investments_clean
),
per_user AS (
  SELECT user_id,
         MAX(CASE WHEN inv_number = 1 THEN investment_type END)            AS first_type,
         MAX(CASE WHEN inv_number = 1 THEN amount END)                     AS first_amount,
         COUNT(DISTINCT investment_date)                                   AS invest_days,
         COUNT(DISTINCT CASE WHEN source = 'app' THEN investment_date END) AS manual_days
  FROM ranked
  GROUP BY user_id
)
SELECT first_type,
       COUNT(*) AS investors,
       ROUND(AVG(first_amount)) AS avg_first_amount,
       ROUND(100.0 * SUM(CASE WHEN invest_days >= 2 THEN 1 ELSE 0 END) / COUNT(*), 1) AS repeat_any_pct,
       ROUND(100.0 * SUM(CASE WHEN manual_days >= 2 THEN 1 ELSE 0 END) / COUNT(*), 1) AS repeat_manual_pct
FROM per_user
GROUP BY first_type;


-- ---------------------------------------------------------------------
-- PART C: LAG() - days between consecutive manual investments
-- LAG(date) returns the same user's previous investment date.
-- Subquery keeps one row per user per day of manual (app) investing.
-- Median reported alongside average because a few long gaps skew it.
--
-- Result: 478 repeat investments | average 17 days | median 11 days
--
-- Finding: most second investments happen within ~2 weeks of the
-- previous one. A nudge in that window is a natural test. Together with
-- retention (biggest drop week 1 -> week 2), the first two weeks are
-- the critical period for the product.
-- ---------------------------------------------------------------------
WITH manual AS (
  SELECT user_id, investment_date,
         LAG(investment_date) OVER (PARTITION BY user_id ORDER BY investment_date) AS prev_date
  FROM (SELECT DISTINCT user_id, investment_date
        FROM investments_clean
        WHERE source = 'app') t
)
SELECT COUNT(*) AS repeat_investments,
       ROUND(AVG(investment_date - prev_date)) AS avg_days_between,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY investment_date - prev_date) AS median_days_between
FROM manual
WHERE prev_date IS NOT NULL;


-- ---------------------------------------------------------------------
-- PART D: Mutual fund categories - attention vs conversion
-- Investors counted from investment_completed EVENTS (user-initiated),
-- not the investments table, so SIP auto-debits don't inflate
-- SIP-heavy categories.
--
-- Result:
--   Category  Viewers  Investors  View -> Invest
--   Equity     2,648      392        14.8%   (best)
--   Index      2,254      219         9.7%   (2nd most viewed, lowest conversion)
--   ELSS       1,682      171        10.2%
--   Hybrid     1,617      196        12.1%
--   Debt       1,580      168        10.6%
--
-- Finding: Index funds get the 2nd-most attention but convert the worst.
-- If Index converted like Equity (14.8%), ~115 more users would invest.
-- The gap warrants investigation into information clarity, perceived
-- risk/return, choice overload between similar index funds, or decision
-- friction. The data shows the gap, not its cause.
-- ---------------------------------------------------------------------
WITH views AS (
  SELECT fund_category, COUNT(DISTINCT user_id) AS viewers
  FROM events_clean
  WHERE event_name = 'mf_detail_view' AND fund_category IS NOT NULL
  GROUP BY fund_category
),
invs AS (
  SELECT fund_category, COUNT(DISTINCT user_id) AS investors
  FROM events_clean
  WHERE event_name = 'investment_completed' AND product_type = 'Mutual Fund'
  GROUP BY fund_category
)
SELECT v.fund_category,
       v.viewers,
       i.investors,
       ROUND(100.0 * i.investors / v.viewers, 1) AS view_to_invest_pct
FROM views v
LEFT JOIN invs i ON v.fund_category = i.fund_category
ORDER BY v.viewers DESC;
