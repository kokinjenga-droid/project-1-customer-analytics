WITH customer_cohort AS (
    -- Each customer's cohort = the month of their first-ever purchase.
    SELECT
        CustomerID,
        MIN(InvoiceMonth) AS cohort_month
    FROM retail
    GROUP BY CustomerID
),
activity AS (
    -- Every distinct month a customer was active, stamped with their cohort.
    SELECT DISTINCT
        r.CustomerID,
        cc.cohort_month,
        r.InvoiceMonth AS active_month
    FROM retail r
    JOIN customer_cohort cc ON r.CustomerID = cc.CustomerID
),
indexed AS (
    -- Turn two 'YYYY-MM' strings into "how many months after acquisition is this?"
    SELECT
        cohort_month,
        CustomerID,
        (CAST(substr(active_month, 1, 4) AS INTEGER) * 12 + CAST(substr(active_month, 6, 2) AS INTEGER))
      - (CAST(substr(cohort_month, 1, 4) AS INTEGER) * 12 + CAST(substr(cohort_month, 6, 2) AS INTEGER))
        AS month_offset
    FROM activity
),
cohort_counts AS (
    -- How many customers from each cohort were active at offset 0,1,2...6?
    SELECT
        cohort_month,
        month_offset,
        COUNT(DISTINCT CustomerID) AS customers
    FROM indexed
    WHERE month_offset BETWEEN 0 AND 6
    GROUP BY cohort_month, month_offset
),
cohort_size AS (
    -- The starting size of each cohort = its count at month 0.
    SELECT cohort_month, customers AS size
    FROM cohort_counts
    WHERE month_offset = 0
)
SELECT
    cc.cohort_month,
    cs.size                                        AS cohort_size,
    cc.month_offset,
    cc.customers                                   AS active_customers,
    ROUND(100.0 * cc.customers / cs.size, 1)       AS retention_pct
FROM cohort_counts cc
JOIN cohort_size cs ON cc.cohort_month = cs.cohort_month
ORDER BY cc.cohort_month, cc.month_offset;

