-- =====================================================================
-- 08_final_insights.sql
-- Investly (fictional investment app) - Headline KPIs for the dashboard
-- One query that returns the top-line numbers from files 02-07.
-- Run inside psql:  \i sql/08_final_insights.sql
-- =====================================================================

\x on

SELECT
  (SELECT COUNT(*) FROM users_clean)                                          AS total_users,
  (SELECT ROUND(100.0 * SUM(activated_7d) / COUNT(*), 1) FROM user_summary)   AS activation_7d_pct,
  (SELECT SUM(invested) FROM user_summary)                                    AS mf_investors,
  (SELECT ROUND(100.0 * SUM(invested) / COUNT(*), 1) FROM user_summary)       AS signup_to_invest_pct,
  (SELECT ROUND(100.0 * SUM(CASE WHEN manual_days >= 2 THEN 1 ELSE 0 END) / COUNT(*), 1)
     FROM (SELECT user_id,
                  COUNT(DISTINCT CASE WHEN source = 'app' THEN investment_date END) AS manual_days
           FROM investments_clean
           GROUP BY user_id) x)                                              AS manual_repeat_investor_pct,
  (SELECT ROUND(SUM(amount)) FROM investments_clean)                          AS total_invested_rs;

\x off

-- Other headline numbers (from earlier files):
--   Day-30 retention (days 29-35 active)   ~20-22%      (05)
--   Biggest funnel drop: fund view -> invest start, 35.5%  (03)
--   Cheapest channel per investor: Referral, Rs 849       (04)
--   Calculator users invest at 2.3x non-users (association) (06)
--   Index: 2nd most viewed, lowest conversion 9.7%        (07)
