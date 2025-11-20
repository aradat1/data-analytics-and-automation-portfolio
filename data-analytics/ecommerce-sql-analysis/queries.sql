/* ----------------------------------------------------------
   1) Monthly Revenue (Revenue per Month)
-----------------------------------------------------------*/
SELECT 
    DATE_TRUNC('month', order_date) AS month,
    SUM(total_amount) AS monthly_revenue
FROM orders
GROUP BY 1
ORDER BY 1;


/* ----------------------------------------------------------
   2) Daily Active Customers (Basic Activity Metric)
-----------------------------------------------------------*/
SELECT
    order_date,
    COUNT(DISTINCT customer_id) AS active_customers
FROM orders
GROUP BY order_date
ORDER BY order_date;


/* ----------------------------------------------------------
   3) First-Time vs Returning Customers
-----------------------------------------------------------*/
WITH first_purchase AS (
    SELECT 
        customer_id,
        MIN(order_date) AS first_order_date
    FROM orders
    GROUP BY customer_id
),
orders_classified AS (
    SELECT 
        o.customer_id,
        o.order_id,
        o.order_date,
        CASE 
            WHEN o.order_date = fp.first_order_date THEN 'first_time'
            ELSE 'returning'
        END AS customer_type
    FROM orders o
    JOIN first_purchase fp USING (customer_id)
)
SELECT 
    customer_type, 
    COUNT(*) AS orders_count
FROM orders_classified
GROUP BY customer_type;


/* ----------------------------------------------------------
   4) Cohort Analysis (Retention Matrix)
-----------------------------------------------------------*/
WITH cohort AS (
    SELECT
        customer_id,
        MIN(DATE_TRUNC('month', order_date)) AS cohort_month
    FROM orders
    GROUP BY customer_id
),
activity AS (
    SELECT
        o.customer_id,
        DATE_TRUNC('month', o.order_date) AS activity_month
    FROM orders o
)
SELECT
    c.cohort_month,
    a.activity_month,
    COUNT(DISTINCT a.customer_id) AS customers
FROM cohort c
JOIN activity a USING (customer_id)
GROUP BY 1, 2
ORDER BY 1, 2;


/* ----------------------------------------------------------
   5) Top 10 Products by Revenue
-----------------------------------------------------------*/
SELECT 
    p.product_id,
    p.product_name,
    SUM(oi.quantity * oi.price) AS revenue
FROM order_items oi
JOIN products p USING (product_id)
GROUP BY p.product_id, p.product_name
ORDER BY revenue DESC
LIMIT 10;


/* ----------------------------------------------------------
   6) Average Order Value (AOV)
-----------------------------------------------------------*/
SELECT 
    AVG(total_amount) AS average_order_value
FROM orders;


/* ----------------------------------------------------------
   7) Total Customers, Repeat Customers, Repeat Rate
-----------------------------------------------------------*/
WITH customer_stats AS (
    SELECT 
        customer_id,
        COUNT(order_id) AS orders_count
    FROM orders
    GROUP BY customer_id
)
SELECT
    COUNT(*) AS total_customers,
    COUNT(*) FILTER (WHERE orders_count > 1) AS repeat_customers,
    ROUND(
        COUNT(*) FILTER (WHERE orders_count > 1)::NUMERIC 
        / COUNT(*) * 100, 2
    ) AS repeat_rate_percentage
FROM customer_stats;


/* ----------------------------------------------------------
   8) Customer Lifetime Revenue (Simple LTV)
-----------------------------------------------------------*/
SELECT
    customer_id,
    SUM(total_amount) AS lifetime_value
FROM orders
GROUP BY customer_id
ORDER BY lifetime_value DESC;


/* ----------------------------------------------------------
   9) Funnel Analysis:
      - Step 1: First Purchase
      - Step 2: Second Purchase
      - Step 3: High-Value Customer (LTV > threshold)
-----------------------------------------------------------*/
WITH purchases AS (
    SELECT
        customer_id,
        order_id,
        order_date,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS order_num,
        SUM(total_amount) OVER (PARTITION BY customer_id) AS lifetime_value
    FROM orders
)
SELECT
    COUNT(*) FILTER (WHERE order_num = 1) AS first_purchase,
    COUNT(*) FILTER (WHERE order_num = 2) AS second_purchase,
    COUNT(*) FILTER (WHERE lifetime_value > 300) AS high_value_customers;
