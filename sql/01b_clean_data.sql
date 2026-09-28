-- =====================================================================
-- 01b_clean_data.sql
-- Investly (fictional investment app) - Create clean analysis tables
-- Fixes every issue found in 01_data_quality.sql.
-- Raw tables are left untouched so removals can always be audited.
-- All analysis from 02 onwards uses the *_clean tables.
-- =====================================================================

DROP TABLE IF EXISTS events_clean, investments_clean, users_clean;


-- ---------------------------------------------------------------------
-- events_clean
-- DISTINCT              -> removes 600 duplicate event rows
-- INNER JOIN users      -> removes 25 events from unknown users
-- timestamp >= signup   -> removes 30 events logged before signup
-- Result: 125,149 raw rows -> 124,494 clean rows
-- ---------------------------------------------------------------------
CREATE TABLE events_clean AS
SELECT DISTINCT e.*
FROM events e
JOIN users u ON e.user_id = u.user_id
WHERE e.event_timestamp >= u.signup_date;


-- ---------------------------------------------------------------------
-- investments_clean
-- DISTINCT     -> removes 4 duplicate transactions
-- amount > 0   -> removes 6 zero / negative amounts
-- Result: 2,729 raw rows -> 2,719 clean rows
-- ---------------------------------------------------------------------
CREATE TABLE investments_clean AS
SELECT DISTINCT *
FROM investments
WHERE amount > 0;


-- ---------------------------------------------------------------------
-- users_clean
-- COALESCE(age_group, 'Unknown') -> fills 8 missing ages without
-- dropping those users (they still signed up and used the app).
-- Result: 10,000 users kept
-- ---------------------------------------------------------------------
CREATE TABLE users_clean AS
SELECT user_id,
       signup_date,
       COALESCE(age_group, 'Unknown') AS age_group,
       city_tier,
       acquisition_channel,
       platform,
       risk_profile
FROM users;


-- ---------------------------------------------------------------------
-- Verification: every value should be 0
-- Result: 0 | 0 | 0
-- ---------------------------------------------------------------------
SELECT
  (SELECT COUNT(*) - COUNT(DISTINCT event_id) FROM events_clean)       AS dup_events_left,
  (SELECT COUNT(*) FROM investments_clean WHERE amount <= 0)           AS bad_amounts_left,
  (SELECT COUNT(*) FROM users_clean WHERE age_group IS NULL)           AS missing_age_left;
