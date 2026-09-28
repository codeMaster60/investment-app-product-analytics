-- Investly: create tables and load CSVs (PostgreSQL)
-- Run in psql from the project root folder:  \i sql/00_setup.sql
-- No PRIMARY KEYs on purpose: the raw data contains duplicates that
-- 01_data_quality.sql is meant to find. We clean after checking.

DROP TABLE IF EXISTS events, investments, campaigns, users;

CREATE TABLE users (
    user_id             VARCHAR(10),
    signup_date         DATE,
    age_group           VARCHAR(10),
    city_tier           VARCHAR(10),
    acquisition_channel VARCHAR(20),
    platform            VARCHAR(10),
    risk_profile        VARCHAR(15)
);

CREATE TABLE events (
    event_id        VARCHAR(12),
    user_id         VARCHAR(10),
    event_timestamp TIMESTAMP,
    event_name      VARCHAR(30),
    session_id      VARCHAR(12),
    product_type    VARCHAR(20),
    screen_name     VARCHAR(20),
    fund_category   VARCHAR(10)
);

CREATE TABLE investments (
    investment_id   VARCHAR(10),
    user_id         VARCHAR(10),
    investment_date DATE,
    product_type    VARCHAR(20),
    investment_type VARCHAR(10),
    amount          NUMERIC(12,2),
    fund_category   VARCHAR(10),
    source          VARCHAR(20)
);

CREATE TABLE campaigns (
    campaign_id   VARCHAR(6),
    campaign_name VARCHAR(50),
    channel       VARCHAR(20),
    start_date    DATE,
    end_date      DATE,
    spend         NUMERIC(12,2)
);

\copy users       FROM 'data/users.csv'       CSV HEADER
\copy events      FROM 'data/events.csv'      CSV HEADER
\copy investments FROM 'data/investments.csv' CSV HEADER
\copy campaigns   FROM 'data/campaigns.csv'   CSV HEADER

SELECT 'users' AS tbl, COUNT(*) FROM users
UNION ALL SELECT 'events', COUNT(*) FROM events
UNION ALL SELECT 'investments', COUNT(*) FROM investments
UNION ALL SELECT 'campaigns', COUNT(*) FROM campaigns;
