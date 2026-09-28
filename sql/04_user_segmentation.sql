-- =====================================================================
-- 04_user_segmentation.sql
-- Investly (fictional investment app) - Acquisition quality & segments
-- Questions:
--   1. Which acquisition channels produce users who actually invest?
--   2. What does an investor cost per channel?
--   3. Which user segments behave differently?
-- Uses clean tables from 01b_clean_data.sql.
-- =====================================================================


-- ---------------------------------------------------------------------
-- PART A: Acquisition channel -> investor conversion
--
-- Result:
--   Channel    Signups  Investors  Signup->Invest
--   Referral     1,175     143        12.2%   (best)
--   Organic      2,477     265        10.7%
--   Paid Ads     1,351     114         8.4%
--   Google       1,958     159         8.1%
--   YouTube      1,026      75         7.3%
--   Instagram    2,013     145         7.2%   (worst)
--
-- Finding: Instagram brings the 2nd-most signups but the worst
-- conversion. Instagram and Referral produce almost the same number of
-- investors (145 vs 143), but Instagram needed ~2x the signups.
-- "Most users" is not the same as "best users".
-- ---------------------------------------------------------------------
WITH flags AS (
  SELECT u.user_id, u.acquisition_channel,
    MAX(CASE WHEN e.event_name = 'investment_completed'
             AND e.product_type = 'Mutual Fund' THEN 1 ELSE 0 END) AS invested
  FROM users_clean u
  LEFT JOIN events_clean e ON u.user_id = e.user_id
  GROUP BY u.user_id, u.acquisition_channel
)
SELECT acquisition_channel,
       COUNT(*)      AS signups,
       SUM(invested) AS investors,
       ROUND(100.0 * SUM(invested) / COUNT(*), 1) AS pct_signup_to_invest
FROM flags
GROUP BY acquisition_channel
ORDER BY pct_signup_to_invest DESC;


-- ---------------------------------------------------------------------
-- PART B: Cost per signup and cost per investor
-- Three chained CTEs: per-user flag -> per-channel totals -> spend.
-- LEFT JOIN keeps Organic (no spend) in the result.
-- Referral "spend" = referral bonuses paid.
--
-- Result:
--   Channel    Cost/signup  Cost/investor
--   Referral       Rs 103        Rs 849    (cheapest)
--   Instagram      Rs 118      Rs 1,643
--   Paid Ads       Rs 156      Rs 1,849
--   Google         Rs 180      Rs 2,218
--   YouTube        Rs 222      Rs 3,031    (most expensive)
--   Organic         free          free
--
-- Finding: Instagram has the WORST conversion but is the 2nd CHEAPEST
-- per investor because its signups are cheap. Conversion alone would
-- have wrongly suggested cutting Instagram. The channel to question is
-- YouTube: 3.6x the cost per investor of Referral.
-- Caveats: referral may not scale linearly with bonus spend; this counts
-- investors, not investment value (a channel with fewer but larger
-- investors could still be worth more).
-- ---------------------------------------------------------------------
WITH flags AS (
  SELECT u.user_id, u.acquisition_channel,
    MAX(CASE WHEN e.event_name = 'investment_completed'
             AND e.product_type = 'Mutual Fund' THEN 1 ELSE 0 END) AS invested
  FROM users_clean u
  LEFT JOIN events_clean e ON u.user_id = e.user_id
  GROUP BY u.user_id, u.acquisition_channel
),
channel_results AS (
  SELECT acquisition_channel,
         COUNT(*)      AS signups,
         SUM(invested) AS investors
  FROM flags
  GROUP BY acquisition_channel
),
spend AS (
  SELECT channel, SUM(spend) AS total_spend
  FROM campaigns
  GROUP BY channel
)
SELECT c.acquisition_channel,
       c.signups,
       c.investors,
       s.total_spend,
       ROUND(s.total_spend / c.signups)   AS cost_per_signup,
       ROUND(s.total_spend / c.investors) AS cost_per_investor
FROM channel_results c
LEFT JOIN spend s ON c.acquisition_channel = s.channel
ORDER BY cost_per_investor;


-- ---------------------------------------------------------------------
-- PART C: Reusable user-level summary table
-- One row per user with yes/no flags, so every segment comparison is a
-- short GROUP BY instead of re-writing the same logic each time.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS user_summary;

CREATE TABLE user_summary AS
SELECT u.user_id, u.signup_date, u.age_group, u.city_tier,
       u.acquisition_channel, u.platform, u.risk_profile,
  MAX(CASE WHEN e.event_name = 'kyc_completed' THEN 1 ELSE 0 END)       AS kyc_done,
  MAX(CASE WHEN e.event_name = 'bank_link_completed' THEN 1 ELSE 0 END) AS bank_linked,
  MAX(CASE WHEN e.event_name = 'mf_discovery' THEN 1 ELSE 0 END)        AS discovered,
  MAX(CASE WHEN e.event_name = 'investment_completed'
           AND e.product_type = 'Mutual Fund' THEN 1 ELSE 0 END)         AS invested,
  MAX(CASE WHEN e.event_name = 'kyc_completed'
           AND e.event_timestamp < u.signup_date + INTERVAL '7 days' THEN 1 ELSE 0 END)
  * MAX(CASE WHEN e.event_name = 'bank_link_completed'
           AND e.event_timestamp < u.signup_date + INTERVAL '7 days' THEN 1 ELSE 0 END)
  * MAX(CASE WHEN e.event_name = 'mf_discovery'
           AND e.event_timestamp < u.signup_date + INTERVAL '7 days' THEN 1 ELSE 0 END) AS activated_7d
FROM users_clean u
LEFT JOIN events_clean e ON u.user_id = e.user_id
GROUP BY u.user_id, u.signup_date, u.age_group, u.city_tier,
         u.acquisition_channel, u.platform, u.risk_profile;


-- ---------------------------------------------------------------------
-- PART D: City tier
-- Result:
--   Tier 1  KYC 67.4%  Activation 36.6%  Invested 9.7%
--   Tier 2  KYC 64.5%  Activation 36.1%  Invested 9.5%
--   Tier 3  KYC 58.7%  Activation 30.5%  Invested 6.5%
-- Finding: Tier 1 and 2 are similar. Tier 3 lags at every step and the
-- gap starts at KYC -> users are lost during onboarding, not at the
-- investment decision.
-- ---------------------------------------------------------------------
SELECT city_tier,
       COUNT(*) AS users,
       ROUND(100.0 * SUM(kyc_done)     / COUNT(*), 1) AS kyc_pct,
       ROUND(100.0 * SUM(activated_7d) / COUNT(*), 1) AS activation_pct,
       ROUND(100.0 * SUM(invested)     / COUNT(*), 1) AS invest_pct
FROM user_summary
GROUP BY city_tier
ORDER BY city_tier;


-- ---------------------------------------------------------------------
-- PART E: Age group
-- Result:
--   18-24  KYC 65.2%  Activation 36.0%  Invested 9.1%
--   25-34  KYC 66.6%  Activation 37.4%  Invested 9.3%
--   35-44  KYC 66.5%  Activation 34.4%  Invested 9.1%
--   45+    KYC 55.8%  Activation 29.5%  Invested 7.9%
--   Unknown (8 users) - too small to interpret
-- Finding: 45+ is the weakest segment and, like Tier 3, the gap starts
-- at KYC (~11 points below other ages).
-- ---------------------------------------------------------------------
SELECT age_group,
       COUNT(*) AS users,
       ROUND(100.0 * SUM(kyc_done)     / COUNT(*), 1) AS kyc_pct,
       ROUND(100.0 * SUM(activated_7d) / COUNT(*), 1) AS activation_pct,
       ROUND(100.0 * SUM(invested)     / COUNT(*), 1) AS invest_pct
FROM user_summary
GROUP BY age_group
ORDER BY age_group;


-- ---------------------------------------------------------------------
-- PART F: Risk profile
-- Result: Aggressive 9.0%, Conservative 8.7%, Moderate 9.2% invested.
-- Finding: no meaningful difference. Risk profile does not explain who
-- invests. (A null result is still a result.)
-- ---------------------------------------------------------------------
SELECT risk_profile,
       COUNT(*) AS users,
       ROUND(100.0 * SUM(kyc_done)     / COUNT(*), 1) AS kyc_pct,
       ROUND(100.0 * SUM(activated_7d) / COUNT(*), 1) AS activation_pct,
       ROUND(100.0 * SUM(invested)     / COUNT(*), 1) AS invest_pct
FROM user_summary
GROUP BY risk_profile
ORDER BY risk_profile;


-- ---------------------------------------------------------------------
-- PART G: Platform
-- Result: Android 9.0%, iOS 9.2% invested.
-- Finding: no meaningful overall difference between platforms.
-- ---------------------------------------------------------------------
SELECT platform,
       COUNT(*) AS users,
       ROUND(100.0 * SUM(kyc_done)     / COUNT(*), 1) AS kyc_pct,
       ROUND(100.0 * SUM(activated_7d) / COUNT(*), 1) AS activation_pct,
       ROUND(100.0 * SUM(invested)     / COUNT(*), 1) AS invest_pct
FROM user_summary
GROUP BY platform
ORDER BY platform;


-- =====================================================================
-- SEGMENTATION SUMMARY
-- * The two weak segments are Tier 3 cities and users aged 45+.
-- * In both, the gap appears at KYC, not at the investment decision.
--   Hypothesis to test: KYC is harder for less digitally-native users
--   (documents, language, video verification). Possible product
--   response: assisted / vernacular KYC for these segments.
-- * Risk profile and platform show no meaningful differences.
-- * Differences under ~1 percentage point are treated as noise.
-- =====================================================================
