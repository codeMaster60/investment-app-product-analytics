-- =====================================================================
-- 05_retention_cohort.sql
-- Investly (fictional investment app) - Cohort retention
-- Question: Do users keep coming back after signup, and does retention
--           differ by signup month?
-- Uses clean tables from 01b_clean_data.sql.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Definitions
-- Cohort    = users grouped by signup month (DATE_TRUNC('month', ...)).
-- Retained  = the user has at least one event of any kind inside the
--             window. Windows are counted from midnight of signup day.
-- Windows (all exactly 7 days long, so they are comparable):
--   week1       = days 1-7  after signup
--   week2       = days 8-14
--   day30_week  = days 29-35 (still active ~1 month later)
--
-- LESSON LEARNED (first attempt, not kept):
-- An earlier version used D1 = day 1 only, D7 = days 7-13, D30 = days
-- 30-59. It showed D7 (~50%) HIGHER than D1 (~38%), which is impossible
-- for real retention. Cause: windows of different length (1, 7 and 30
-- days) are not comparable - longer windows catch more users.
-- Fix: equal-length 7-day windows below.
-- ---------------------------------------------------------------------


-- ---------------------------------------------------------------------
-- Result:
--   Cohort    Users  Week1  Week2  Day30-week
--   Jan 2026  1,387  74.9%  49.2%   22.2%
--   Feb 2026  1,412  76.7%  50.1%   22.0%
--   Mar 2026  1,634  76.6%  47.4%   19.5%
--   Apr 2026  1,737  75.0%  46.3%   19.9%
--   May 2026  1,904  75.4%  48.9%   20.0%
--   Jun 2026  1,926  76.9%  49.6%   21.7%
--
-- Findings:
-- 1. About 1 in 5 users (~20-22%) is still active one month after signup.
-- 2. The steepest loss is between week 1 (~76%) and week 2 (~48%):
--    over a third of week-1 users don't return in week 2.
-- 3. All six cohorts are within ~3 points of each other, so retention
--    is stable month to month; no cohort stands out.
-- Caveat: week-1 activity includes onboarding events (e.g. finishing
-- KYC a few days after signup), which inflates week-1 retention compared
-- with later weeks.
-- ---------------------------------------------------------------------
WITH activity AS (
  SELECT u.user_id,
         DATE_TRUNC('month', u.signup_date)::date AS cohort_month,
         MAX(CASE WHEN e.event_timestamp >= u.signup_date + INTERVAL '1 day'
                   AND e.event_timestamp <  u.signup_date + INTERVAL '8 days'  THEN 1 ELSE 0 END) AS week1,
         MAX(CASE WHEN e.event_timestamp >= u.signup_date + INTERVAL '8 days'
                   AND e.event_timestamp <  u.signup_date + INTERVAL '15 days' THEN 1 ELSE 0 END) AS week2,
         MAX(CASE WHEN e.event_timestamp >= u.signup_date + INTERVAL '29 days'
                   AND e.event_timestamp <  u.signup_date + INTERVAL '36 days' THEN 1 ELSE 0 END) AS week5
  FROM users_clean u
  LEFT JOIN events_clean e ON u.user_id = e.user_id
  GROUP BY u.user_id, u.signup_date
)
SELECT cohort_month,
       COUNT(*) AS users,
       ROUND(100.0 * SUM(week1) / COUNT(*), 1) AS week1_pct,
       ROUND(100.0 * SUM(week2) / COUNT(*), 1) AS week2_pct,
       ROUND(100.0 * SUM(week5) / COUNT(*), 1) AS day30_week_pct
FROM activity
GROUP BY cohort_month
ORDER BY cohort_month;
