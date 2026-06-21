WITH snapshot AS (
    -- A fixed "today" to measure recency against: the day after the data ends.
    -- (You always anchor recency to a reference date, not the real today,
    --  or every customer would look ancient.)
    SELECT DATE(MAX(InvoiceDate), '+1 day') AS snapshot_date
    FROM retail
),
customer_rfm AS (
    -- Collapse every customer to ONE row with their raw R, F, M values.
    SELECT
        CustomerID,
        CAST(julianday((SELECT snapshot_date FROM snapshot))
             - julianday(MAX(InvoiceDate)) AS INTEGER)   AS recency_days,
        COUNT(DISTINCT Invoice)                          AS frequency,
        ROUND(SUM(Revenue), 2)                           AS monetary
    FROM retail
    GROUP BY CustomerID
),
rfm_scored AS (
    -- Score each dimension into 1-5 quintiles with NTILE.
    SELECT
        CustomerID, recency_days, frequency, monetary,
        6 - NTILE(5) OVER (ORDER BY recency_days) AS r_score,  -- reversed: recent = high
        NTILE(5) OVER (ORDER BY frequency)        AS f_score,
        NTILE(5) OVER (ORDER BY monetary)         AS m_score
    FROM customer_rfm
)
SELECT
    CustomerID, recency_days, frequency, monetary,
    r_score, f_score, m_score,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'New / Promising'
        WHEN r_score <= 2 AND m_score >= 4 THEN 'At Risk'        -- valuable, gone quiet
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost'
        ELSE 'Needs Attention'
    END AS segment
FROM rfm_scored
ORDER BY monetary DESC;
