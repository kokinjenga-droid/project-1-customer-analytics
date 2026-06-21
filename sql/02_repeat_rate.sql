WITH customer_orders AS (
    -- One row per customer per invoice, tagged with that customer's
    -- very first purchase date (computed with a window function).
    SELECT
        CustomerID,
        InvoiceMonth,
        MIN(InvoiceDate) OVER (PARTITION BY CustomerID) AS first_purchase_date,
        InvoiceDate
    FROM retail
),
flagged AS (
    -- For each transaction, decide: is this a brand-new customer this month,
    -- or someone who had already bought before?
    SELECT
        InvoiceMonth,
        CustomerID,
        CASE
            WHEN InvoiceDate > first_purchase_date THEN 'returning'
            ELSE 'new'
        END AS customer_type
    FROM customer_orders
)
SELECT
    InvoiceMonth,
    COUNT(DISTINCT CustomerID) AS active_customers,
    COUNT(DISTINCT CASE WHEN customer_type = 'returning' THEN CustomerID END) AS returning_customers,
    ROUND(
        100.0 * COUNT(DISTINCT CASE WHEN customer_type = 'returning' THEN CustomerID END)
        / COUNT(DISTINCT  CustomerID),
    1) AS repeat_rate_pct
FROM flagged
GROUP BY InvoiceMonth
ORDER BY InvoiceMonth;
