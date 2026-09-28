-- =====================================================================
-- 02_user_activation.sql
-- Investly (fictional investment app) - Onboarding funnel & activation
-- Question: How effectively does the app turn signups into activated users?
-- Uses clean tables from 01b_clean_data.sql.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Onboarding funnel: unique users reaching each step (any time)
-- COUNT(DISTINCT CASE WHEN ...) counts each user once per step,
-- so repeated events (e.g. multiple mf_discovery visits) don't inflate it.
--
-- Result:
--   signed_up 10,000 | kyc_started 8,514 | kyc_completed 6,465
--   bank_linked 4,882 | mf_discovered 3,867
-- ---------------------------------------------------------------------
SELECT
  COUNT(DISTINCT CASE WHEN event_name = 'signup_completed'    THEN user_id END) AS signed_up,
  COUNT(DISTINCT CASE WHEN event_name = 'kyc_started'         THEN user_id END) AS kyc_started,
  COUNT(DISTINCT CASE WHEN event_name = 'kyc_completed'       THEN user_id END) AS kyc_completed,
  COUNT(DISTINCT CASE WHEN event_name = 'bank_link_completed' THEN user_id END) AS bank_linked,
  COUNT(DISTINCT CASE WHEN event_name = 'mf_discovery'        THEN user_id END) AS mf_discovered
FROM events_clean;


-- ---------------------------------------------------------------------
-- 2. Step-to-step conversion rates
-- CTE: first count users per step, then calculate percentages.
-- 100.0 (not 100) forces decimal division; integer / integer = integer.
--
-- Result:
--   Signup -> KYC started          85.1%
--   KYC started -> KYC completed   75.9%
--   KYC completed -> Bank linked   75.5%   (lowest)
--   Bank linked -> MF discovery    79.2%
--   Overall signup -> MF discovery 38.7%
--
-- Finding: KYC completion (75.9%) and bank linking (75.5%) are almost
-- tied as the weakest steps. Treat KYC start -> bank linked as one
-- friction zone: only 57% of users who start KYC get a bank linked.
-- Largest absolute loss: 2,049 users start KYC but never complete it.
-- ---------------------------------------------------------------------
WITH funnel AS (
  SELECT
    COUNT(DISTINCT CASE WHEN event_name = 'signup_completed'    THEN user_id END) AS signed_up,
    COUNT(DISTINCT CASE WHEN event_name = 'kyc_started'         THEN user_id END) AS kyc_started,
    COUNT(DISTINCT CASE WHEN event_name = 'kyc_completed'       THEN user_id END) AS kyc_completed,
    COUNT(DISTINCT CASE WHEN event_name = 'bank_link_completed' THEN user_id END) AS bank_linked,
    COUNT(DISTINCT CASE WHEN event_name = 'mf_discovery'        THEN user_id END) AS mf_discovered
  FROM events_clean
)
SELECT
  ROUND(100.0 * kyc_started   / signed_up, 1)     AS pct_signup_to_kyc_start,
  ROUND(100.0 * kyc_completed / kyc_started, 1)   AS pct_kyc_start_to_complete,
  ROUND(100.0 * bank_linked   / kyc_completed, 1) AS pct_kyc_to_bank,
  ROUND(100.0 * mf_discovered / bank_linked, 1)   AS pct_bank_to_discovery,
  ROUND(100.0 * mf_discovered / signed_up, 1)     AS pct_overall
FROM funnel;


-- ---------------------------------------------------------------------
-- 3. 7-day activation rate
-- Definition: Activated = kyc_completed AND bank_link_completed AND
--             mf_discovery, all within 7 days of signup.
-- Why 7 days: a user who finishes onboarding months later is not a
--             healthy activation; the first week is when intent is highest.
-- Note: signup_date has no time, so the window starts at midnight of
--       the signup day (slightly under 7 x 24 hours).
--
-- MAX(CASE ... THEN 1 ELSE 0 END) turns each step into a per-user yes/no flag.
-- Multiplying flags = 1 only if all three steps happened.
-- LEFT JOIN keeps every user, so the denominator stays at 10,000.
--
-- Result: 3,525 of 10,000 users activated within 7 days = 35.3%
--
-- Finding: 38.7% reach MF discovery eventually, but only 35.3% within
-- 7 days. ~342 users are slow activators who finish onboarding after
-- week 1 -> opportunity for week-1 reminders / nudges to finish KYC and
-- bank linking.
-- ---------------------------------------------------------------------
WITH user_steps AS (
  SELECT u.user_id,
    MAX(CASE WHEN e.event_name = 'kyc_completed'
             AND e.event_timestamp < u.signup_date + INTERVAL '7 days' THEN 1 ELSE 0 END) AS kyc_7d,
    MAX(CASE WHEN e.event_name = 'bank_link_completed'
             AND e.event_timestamp < u.signup_date + INTERVAL '7 days' THEN 1 ELSE 0 END) AS bank_7d,
    MAX(CASE WHEN e.event_name = 'mf_discovery'
             AND e.event_timestamp < u.signup_date + INTERVAL '7 days' THEN 1 ELSE 0 END) AS discovery_7d
  FROM users_clean u
  LEFT JOIN events_clean e ON u.user_id = e.user_id
  GROUP BY u.user_id
)
SELECT
  COUNT(*)                                                          AS total_users,
  SUM(kyc_7d * bank_7d * discovery_7d)                              AS activated_7d,
  ROUND(100.0 * SUM(kyc_7d * bank_7d * discovery_7d) / COUNT(*), 1) AS activation_rate_7d
FROM user_steps;
