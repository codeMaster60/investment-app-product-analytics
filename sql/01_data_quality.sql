-- =====================================================================
-- 01_data_quality.sql
-- Investly (fictional investment app) - Data quality checks
-- Purpose: validate the raw data BEFORE any product analysis.
-- Results below are from running these queries on the synthetic dataset.
-- =====================================================================


-- ---------------------------------------------------------------------
-- CHECK 1: Row counts vs unique users per event
-- Why: COUNT(*) counts rows, not people. Funnels must count people.
-- Result: signup_completed = 10,048 rows but 10,000 unique users
--         -> duplicate rows exist. app_open has 10,012 unique users
--         but only 10,000 users exist -> events from unknown users.
-- ---------------------------------------------------------------------
SELECT event_name,
       COUNT(*)                AS total_rows,
       COUNT(DISTINCT user_id) AS unique_users
FROM events
GROUP BY event_name
ORDER BY unique_users DESC;


-- ---------------------------------------------------------------------
-- CHECK 2: Duplicate event rows
-- Why: duplicates inflate every funnel stage and event count.
-- Result: 600 duplicate rows (~0.5% of events). Each duplicated
--         event_id appears exactly twice.
-- Action: keep one row per event_id.
-- ---------------------------------------------------------------------
SELECT COUNT(*)                            AS total_rows,
       COUNT(DISTINCT event_id)            AS unique_events,
       COUNT(*) - COUNT(DISTINCT event_id) AS duplicate_rows
FROM events;

SELECT event_id, COUNT(*) AS times_seen
FROM events
GROUP BY event_id
HAVING COUNT(*) > 1
LIMIT 5;


-- ---------------------------------------------------------------------
-- CHECK 3: Events from users not in the users table (referential integrity)
-- Why: we cannot segment or attribute behaviour to unknown users.
-- Result: 25 events from 25 user IDs (U99xxx) outside the valid range.
--         Likely test accounts or a logging issue.
-- Action: exclude these events.
-- Note: LEFT JOIN keeps unmatched events visible; INNER JOIN would hide them.
-- ---------------------------------------------------------------------
SELECT COUNT(*)                  AS orphan_rows,
       COUNT(DISTINCT e.user_id) AS orphan_users
FROM events e
LEFT JOIN users u ON e.user_id = u.user_id
WHERE u.user_id IS NULL;


-- ---------------------------------------------------------------------
-- CHECK 4: Events before the user's signup date
-- Why: a user cannot act in the app before signing up.
-- Result: 30 events from 30 users, ~200 days before signup.
--         Too far off to be a timezone issue -> likely a logging /
--         device clock bug.
-- Action: exclude these events (correct time cannot be recovered).
-- Note: signup_date has no time, so same-day events before signup
--       (e.g. app_open just before registering) are NOT flagged.
-- ---------------------------------------------------------------------
SELECT COUNT(*)                  AS rows_before_signup,
       COUNT(DISTINCT e.user_id) AS users_affected
FROM events e
JOIN users u ON e.user_id = u.user_id
WHERE e.event_timestamp < u.signup_date;


-- ---------------------------------------------------------------------
-- CHECK 5: Missing values in users
-- Why: missing attributes break segmentation.
-- Result: 8 users with missing age_group; all other columns complete.
-- Action: keep these users, label age as 'Unknown' in age analysis.
-- Note: COUNT(column) skips NULLs, so COUNT(*) - COUNT(col) = NULL count.
-- ---------------------------------------------------------------------
SELECT COUNT(*)                              AS total_users,
       COUNT(*) - COUNT(age_group)           AS missing_age,
       COUNT(*) - COUNT(city_tier)           AS missing_tier,
       COUNT(*) - COUNT(acquisition_channel) AS missing_channel,
       COUNT(*) - COUNT(risk_profile)        AS missing_risk
FROM users;


-- ---------------------------------------------------------------------
-- CHECK 6: Duplicate users
-- Result: 0 duplicates. users table is clean on user_id.
-- ---------------------------------------------------------------------
SELECT COUNT(*) - COUNT(DISTINCT user_id) AS duplicate_users
FROM users;


-- ---------------------------------------------------------------------
-- CHECK 7: Investments with zero or negative amounts
-- Why: a real investment cannot be <= 0.
-- Result: 6 rows (three at 0, and -500, -2000, -100).
--         Possibly failed or reversed transactions.
-- Action: exclude from investment analysis.
-- ---------------------------------------------------------------------
SELECT investment_id, user_id, amount
FROM investments
WHERE amount <= 0;


-- ---------------------------------------------------------------------
-- CHECK 8: Duplicate investment IDs
-- Why: duplicate transactions double-count investment value.
-- Result: 4 investment IDs appear twice.
-- Action: keep one row per investment_id.
-- ---------------------------------------------------------------------
SELECT investment_id, COUNT(*) AS times_seen
FROM investments
GROUP BY investment_id
HAVING COUNT(*) > 1;


-- =====================================================================
-- EXPECTED NULLS (not an error)
-- product_type and fund_category are NULL on events like kyc_started or
-- app_open because those events are not about a product. This is by
-- design, so it is not treated as a data quality issue.
-- =====================================================================

-- =====================================================================
-- SUMMARY
-- Issue                              | Rows  | Action
-- -----------------------------------|-------|---------------------------
-- Duplicate event rows               | 600   | Deduplicate on event_id
-- Events from unknown users          | 25    | Exclude
-- Events before signup               | 30    | Exclude
-- Users with missing age_group       | 8     | Keep, label 'Unknown'
-- Duplicate users                    | 0     | None needed
-- Investments with amount <= 0       | 6     | Exclude
-- Duplicate investment IDs           | 4     | Deduplicate on investment_id
-- =====================================================================
