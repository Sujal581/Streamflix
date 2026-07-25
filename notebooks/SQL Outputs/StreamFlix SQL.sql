-- ============================================================
-- StreamFlix Database Schema (Updated to Match CSV Headers)
-- PostgreSQL
-- ============================================================

-- ==========================
-- 1. Subscribers
-- ==========================
CREATE TABLE subscribers (
    subscriber_id VARCHAR(12) PRIMARY KEY,
    signup_date DATE,
    country VARCHAR(40),
    region VARCHAR(40),
    age INTEGER,
    gender VARCHAR(20),
    plan_type VARCHAR(30),
    monthly_price_usd DECIMAL(6,2),
    household_size INTEGER,
    primary_device VARCHAR(30),
    payment_method VARCHAR(30),
    tenure_months INTEGER,
    is_active BOOLEAN,
    churn_date DATE
);

-- ==========================
-- 2. Titles
-- ==========================
CREATE TABLE titles (
    title_id VARCHAR(12) PRIMARY KEY,
    title_name VARCHAR(200),
    type VARCHAR(20),
    primary_genre VARCHAR(40),
    country VARCHAR(40),
    language VARCHAR(40),
    release_year INTEGER,
    date_added DATE,
    maturity_rating VARCHAR(20),
    seasons INTEGER,
    content_duration_min INTEGER,
    is_original BOOLEAN,
    license_type VARCHAR(40),
    director VARCHAR(150),
    cast_members VARCHAR(500),
    quality_score DECIMAL(5,2),
    popularity_score DECIMAL(5,2),
    license_cost_usd DECIMAL(14,2),
    license_expiry DATE,
    total_watch_hours DECIMAL(14,2),
    total_plays INTEGER
);

-- ==========================
-- 3. Watch History
-- ==========================
CREATE TABLE watch_history (
    watch_id BIGINT PRIMARY KEY,
    subscriber_id VARCHAR(12),
    title_id VARCHAR(12),
    watch_date DATE,
    device VARCHAR(30),
    region VARCHAR(40),
    content_duration_min INTEGER,
    watch_duration_min DECIMAL(10,2),
    completion_pct DECIMAL(5,2),
    completed BOOLEAN,
    calculated_completion DECIMAL(10,6),
    difference DECIMAL(10,6),

    CONSTRAINT fk_watch_subscriber
        FOREIGN KEY (subscriber_id)
        REFERENCES subscribers(subscriber_id),

    CONSTRAINT fk_watch_title
        FOREIGN KEY (title_id)
        REFERENCES titles(title_id)
);

-- ==========================
-- 4. Ratings
-- ==========================
CREATE TABLE ratings (
    rating_id BIGINT PRIMARY KEY,
    subscriber_id VARCHAR(12),
    title_id VARCHAR(12),
    rating INTEGER,
    rating_date DATE,

    CONSTRAINT fk_rating_subscriber
        FOREIGN KEY (subscriber_id)
        REFERENCES subscribers(subscriber_id),

    CONSTRAINT fk_rating_title
        FOREIGN KEY (title_id)
        REFERENCES titles(title_id)
);

-- ==========================
-- 5. Reviews
-- ==========================
CREATE TABLE reviews (
    review_id BIGINT PRIMARY KEY,
    subscriber_id VARCHAR(12),
    title_id VARCHAR(12),
    review_text TEXT,
    sentiment VARCHAR(20),
    helpful_votes INTEGER,
    review_date DATE,

    CONSTRAINT fk_review_subscriber
        FOREIGN KEY (subscriber_id)
        REFERENCES subscribers(subscriber_id),

    CONSTRAINT fk_review_title
        FOREIGN KEY (title_id)
        REFERENCES titles(title_id)
);

-- ==========================
-- 6. Watchlist
-- ==========================
CREATE TABLE watchlist (
    watchlist_id BIGINT PRIMARY KEY,
    subscriber_id VARCHAR(12),
    title_id VARCHAR(12),
    added_date DATE,
    watched BOOLEAN,

    CONSTRAINT fk_watchlist_subscriber
        FOREIGN KEY (subscriber_id)
        REFERENCES subscribers(subscriber_id),

    CONSTRAINT fk_watchlist_title
        FOREIGN KEY (title_id)
        REFERENCES titles(title_id)
);

-- ============================================================
-- STREAMFLIX ANALYTICAL QUERIES (PostgreSQL)
-- ============================================================

-- Q1. Top Genres by Watch Hours
SELECT
    t.primary_genre,
    ROUND(SUM(w.watch_duration_min)/60.0,1) AS watch_hours,
    COUNT(*) AS plays
FROM watch_history w
JOIN titles t
ON w.title_id = t.title_id
GROUP BY t.primary_genre
ORDER BY watch_hours DESC;

--------------------------------------------------------------

-- Q2. Top Countries by Watch Hours
SELECT
    t.country,
    ROUND(SUM(w.watch_duration_min)/60.0,1) AS watch_hours,
    COUNT(DISTINCT t.title_id) AS total_titles,
    ROUND(
        SUM(w.watch_duration_min)/60.0 /
        COUNT(DISTINCT t.title_id),
        1
    ) AS hours_per_title
FROM watch_history w
JOIN titles t
ON w.title_id=t.title_id
GROUP BY t.country
ORDER BY watch_hours DESC;

--------------------------------------------------------------

-- Q3. Engagement by Release Year

SELECT
    t.release_year,
    COUNT(DISTINCT t.title_id) AS total_titles,
    ROUND(SUM(w.watch_duration_min)/60.0,1) AS watch_hours,
    ROUND(
        SUM(w.watch_duration_min)/60.0 /
        COUNT(DISTINCT t.title_id),
        1
    ) AS hours_per_title
FROM watch_history w
JOIN titles t
ON w.title_id=t.title_id
GROUP BY t.release_year
ORDER BY t.release_year;

--------------------------------------------------------------

-- Q4. Movies vs TV Shows

SELECT
    t.type,
    ROUND(SUM(w.watch_duration_min)/60.0,1) AS watch_hours,
    COUNT(*) AS plays,
    ROUND(AVG(w.completion_pct),1) AS avg_completion_pct
FROM watch_history w
JOIN titles t
ON w.title_id=t.title_id
GROUP BY t.type
ORDER BY watch_hours DESC;

--------------------------------------------------------------

-- Q5. Language Performance

SELECT
    t.language,
    ROUND(SUM(w.watch_duration_min)/60.0,1) AS watch_hours,
    COUNT(*) AS plays
FROM watch_history w
JOIN titles t
ON w.title_id=t.title_id
GROUP BY t.language
ORDER BY watch_hours DESC;

--------------------------------------------------------------

-- Q6. Genre Completion Rate

SELECT
    t.primary_genre,
    ROUND(AVG(w.completion_pct),1) AS avg_completion_pct,
    SUM(CASE WHEN w.completed THEN 1 ELSE 0 END) AS completed_sessions,
    COUNT(*) AS total_sessions
FROM watch_history w
JOIN titles t
ON w.title_id=t.title_id
GROUP BY t.primary_genre
ORDER BY avg_completion_pct DESC;

--------------------------------------------------------------

-- Q7. Engagement by Subscription Plan

SELECT
    s.plan_type,
    COUNT(DISTINCT s.subscriber_id) AS subscribers,
    ROUND(
        SUM(w.watch_duration_min)/60.0 /
        COUNT(DISTINCT s.subscriber_id),
        1
    ) AS avg_hours_per_subscriber
FROM watch_history w
JOIN subscribers s
ON w.subscriber_id=s.subscriber_id
GROUP BY s.plan_type
ORDER BY avg_hours_per_subscriber DESC;

--------------------------------------------------------------

-- Q8. Device Usage Share

SELECT
    device,
    COUNT(*) AS sessions,
    ROUND(
        COUNT(*)*100.0 /
        (SELECT COUNT(*) FROM watch_history),
        1
    ) AS pct_of_sessions
FROM watch_history
GROUP BY device
ORDER BY sessions DESC;

--------------------------------------------------------------

-- Q9. Subscriber Churn

SELECT
    COUNT(*) AS total_subscribers,
    SUM(CASE WHEN is_active THEN 1 ELSE 0 END) AS active,
    ROUND(
        SUM(CASE WHEN is_active THEN 1 ELSE 0 END)*100.0/
        COUNT(*),
        1
    ) AS active_rate_pct,
    ROUND(
        SUM(CASE WHEN NOT is_active THEN 1 ELSE 0 END)*100.0/
        COUNT(*),
        1
    ) AS churn_rate_pct
FROM subscribers;

--------------------------------------------------------------

-- Q10. Monthly Recurring Revenue

SELECT
    ROUND(SUM(monthly_price_usd),2) AS mrr_usd,
    COUNT(*) AS active_subscribers,
    ROUND(AVG(monthly_price_usd),2) AS arpu_usd
FROM subscribers
WHERE is_active=TRUE;

--------------------------------------------------------------

-- Q11. Watchlist Conversion

SELECT
    COUNT(*) AS watchlist_entries,
    SUM(CASE WHEN watched THEN 1 ELSE 0 END) AS converted,
    ROUND(
        SUM(CASE WHEN watched THEN 1 ELSE 0 END)*100.0/
        COUNT(*),
        1
    ) AS conversion_rate_pct
FROM watchlist;

--------------------------------------------------------------

-- Q12. Content Investment Efficiency

SELECT
    primary_genre,
    ROUND(SUM(license_cost_usd)/1000.0,0) AS spend_thousand_usd,
    ROUND(SUM(total_watch_hours),0) AS watch_hours,
    ROUND(
        SUM(total_watch_hours)/
        (SUM(license_cost_usd)/1000.0),
        3
    ) AS hours_per_1000_usd
FROM titles
GROUP BY primary_genre
ORDER BY hours_per_1000_usd DESC;

-- ============================================================
-- END
-- ============================================================