-- Turn the RFM logic into a reusable view (run once)
CREATE VIEW customer_rfm_view AS
WITH snapshot AS (
    SELECT DATE(MAX(InvoiceDate), '+1 day') AS snapshot_date FROM retail
),
customer_rfm AS (
    SELECT CustomerID,
        CAST(julianday((SELECT snapshot_date FROM snapshot)) - julianday(MAX(InvoiceDate)) AS INTEGER) AS recency_days,
        COUNT(DISTINCT Invoice) AS frequency,
        ROUND(SUM(Revenue), 2) AS monetary
    FROM retail GROUP BY CustomerID
),
rfm_scored AS (
    SELECT CustomerID, recency_days, frequency, monetary,
        6 - NTILE(5) OVER (ORDER BY recency_days) AS r_score,
        NTILE(5) OVER (ORDER BY frequency) AS f_score,
        NTILE(5) OVER (ORDER BY monetary) AS m_score
    FROM customer_rfm
)
SELECT CustomerID, recency_days, frequency, monetary, r_score, f_score, m_score,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'New / Promising'
        WHEN r_score <= 2 AND m_score >= 4 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost'
        ELSE 'Needs Attention'
    END AS segment
FROM rfm_scored;

-- KPI: revenue by segment
SELECT
    segment,
    COUNT(*)                                   AS customers,
    ROUND(SUM(monetary), 2)                    AS total_revenue,
    ROUND(100.0 * SUM(monetary) / (SELECT SUM(monetary) FROM customer_rfm_view), 1) AS pct_of_revenue
FROM customer_rfm_view
GROUP BY segment
ORDER BY total_revenue DESC;
