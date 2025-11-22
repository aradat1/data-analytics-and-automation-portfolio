/* =========================================================
   GLOBAL SKINCARE E-COMMERCE – SQL ANALYTICS
   Dataset: data.csv  (single flat table)
   SQL style: Postgres/ANSI (small tweaks noted)
========================================================= */


/* ---------------------------------------------------------
   0) DATA QUALITY CHECKS
----------------------------------------------------------*/
-- Rows count
SELECT COUNT(*) AS total_rows FROM data;

-- Missing values per key columns
SELECT
  SUM(CASE WHEN "Order ID" IS NULL THEN 1 ELSE 0 END) AS missing_order_id,
  SUM(CASE WHEN "Order Date" IS NULL THEN 1 ELSE 0 END) AS missing_order_date,
  SUM(CASE WHEN "Customer ID" IS NULL THEN 1 ELSE 0 END) AS missing_customer_id,
  SUM(CASE WHEN "Category" IS NULL THEN 1 ELSE 0 END) AS missing_category,
  SUM(CASE WHEN "Product" IS NULL THEN 1 ELSE 0 END) AS missing_product,
  SUM(CASE WHEN "Sales" IS NULL THEN 1 ELSE 0 END) AS missing_sales
FROM data;

-- Duplicated lines (same Row ID)
SELECT "Row ID", COUNT(*) 
FROM data
GROUP BY "Row ID"
HAVING COUNT(*) > 1;


/* ---------------------------------------------------------
   1) OVERALL BUSINESS KPIs
----------------------------------------------------------*/
-- Total Sales, Profit, Avg Discount, Avg Order Line Value
SELECT
  SUM("Sales") AS total_sales,
  SUM("Profit") AS total_profit,
  AVG("Discount") AS avg_discount,
  AVG("Sales") AS avg_line_value
FROM data;

-- Average Order Value (AOV) = sales per order
SELECT
  AVG(order_sales) AS aov
FROM (
  SELECT "Order ID", SUM("Sales") AS order_sales
  FROM data
  GROUP BY "Order ID"
) t;

-- Orders count + customers count
SELECT
  COUNT(DISTINCT "Order ID") AS total_orders,
  COUNT(DISTINCT "Customer ID") AS total_customers
FROM data;


/* ---------------------------------------------------------
   2) TIME SERIES: SALES & PROFIT TRENDS
----------------------------------------------------------*/
-- Monthly Sales & Profit
SELECT
  DATE_TRUNC('month', "Order Date") AS month,
  SUM("Sales") AS sales,
  SUM("Profit") AS profit
FROM data
GROUP BY 1
ORDER BY 1;

-- YoY growth (if multiple years exist)
WITH monthly AS (
  SELECT
    DATE_TRUNC('month', "Order Date") AS month,
    SUM("Sales") AS sales
  FROM data
  GROUP BY 1
)
SELECT
  month,
  sales,
  LAG(sales, 12) OVER (ORDER BY month) AS sales_last_year,
  ROUND(
    (sales - LAG(sales, 12) OVER (ORDER BY month))
    / NULLIF(LAG(sales, 12) OVER (ORDER BY month), 0) * 100, 2
  ) AS yoy_growth_pct
FROM monthly
ORDER BY month;


/* ---------------------------------------------------------
   3) CATEGORY / SUBCATEGORY PERFORMANCE
----------------------------------------------------------*/
-- Sales & Profit by Category
SELECT
  "Category",
  SUM("Sales") AS category_sales,
  SUM("Profit") AS category_profit,
  ROUND(SUM("Profit")/NULLIF(SUM("Sales"),0) * 100, 2) AS profit_margin_pct
FROM data
GROUP BY "Category"
ORDER BY category_sales DESC;

-- Top Subcategories by Sales
SELECT
  "Category",
  "Subcategory",
  SUM("Sales") AS subcat_sales
FROM data
GROUP BY 1,2
ORDER BY subcat_sales DESC
LIMIT 15;


/* ---------------------------------------------------------
   4) PRODUCT PERFORMANCE (BEST SELLERS)
----------------------------------------------------------*/
-- Top 20 Products by Sales
SELECT
  "Product",
  "Category",
  "Subcategory",
  SUM("Sales") AS product_sales,
  SUM("Profit") AS product_profit
FROM data
GROUP BY 1,2,3
ORDER BY product_sales DESC
LIMIT 20;

-- Products with highest profit margin (min sales threshold to avoid noise)
SELECT
  "Product",
  SUM("Sales") AS sales,
  SUM("Profit") AS profit,
  ROUND(SUM("Profit")/NULLIF(SUM("Sales"),0) * 100, 2) AS margin_pct
FROM data
GROUP BY "Product"
HAVING SUM("Sales") >= 1000
ORDER BY margin_pct DESC
LIMIT 20;


/* ---------------------------------------------------------
   5) ANTI-AGING FOCUS (keyword based)
   We don't have explicit "anti-aging" column,
   so we detect by keywords in Product/Subcategory/Category.
----------------------------------------------------------*/
WITH anti_aging AS (
  SELECT *
  FROM data
  WHERE
    LOWER("Product") LIKE '%anti-aging%' OR
    LOWER("Product") LIKE '%anti aging%' OR
    LOWER("Product") LIKE '%age%' OR
    LOWER("Product") LIKE '%wrinkle%' OR
    LOWER("Subcategory") LIKE '%anti-aging%' OR
    LOWER("Subcategory") LIKE '%anti aging%'
)
SELECT
  "Category",
  "Subcategory",
  SUM("Sales") AS anti_aging_sales,
  SUM("Profit") AS anti_aging_profit
FROM anti_aging
GROUP BY 1,2
ORDER BY anti_aging_sales DESC;

-- Top Anti-Aging Products
WITH anti_aging AS (
  SELECT *
  FROM data
  WHERE
    LOWER("Product") LIKE '%anti-aging%' OR
    LOWER("Product") LIKE '%anti aging%' OR
    LOWER("Product") LIKE '%wrinkle%' OR
    LOWER("Product") LIKE '%retinol%' OR
    LOWER("Product") LIKE '%collagen%'
)
SELECT
  "Product",
  SUM("Sales") AS sales,
  SUM("Profit") AS profit
FROM anti_aging
GROUP BY "Product"
ORDER BY sales DESC
LIMIT 15;


/* ---------------------------------------------------------
   6) DISCOUNT IMPACT ON PROFIT
----------------------------------------------------------*/
-- Profit by discount buckets
WITH buckets AS (
  SELECT *,
    CASE
      WHEN "Discount" = 0 THEN '0%'
      WHEN "Discount" <= 0.1 THEN '0-10%'
      WHEN "Discount" <= 0.2 THEN '10-20%'
      WHEN "Discount" <= 0.3 THEN '20-30%'
      ELSE '30%+'
    END AS discount_bucket
  FROM data
)
SELECT
  discount_bucket,
  COUNT(*) AS lines,
  SUM("Sales") AS sales,
  SUM("Profit") AS profit,
  ROUND(SUM("Profit")/NULLIF(SUM("Sales"),0) * 100, 2) AS margin_pct
FROM buckets
GROUP BY discount_bucket
ORDER BY discount_bucket;


/* ---------------------------------------------------------
   7) CUSTOMER ANALYTICS: RFM-STYLE + REPEAT RATE
----------------------------------------------------------*/
-- Orders per customer & repeat customers
WITH cust_orders AS (
  SELECT
    "Customer ID",
    COUNT(DISTINCT "Order ID") AS orders_cnt,
    SUM("Sales") AS lifetime_sales
  FROM data
  GROUP BY "Customer ID"
)
SELECT
  COUNT(*) AS total_customers,
  COUNT(*) FILTER (WHERE orders_cnt > 1) AS repeat_customers,
  ROUND(
    COUNT(*) FILTER (WHERE orders_cnt > 1)::NUMERIC / COUNT(*) * 100
  ,2) AS repeat_rate_pct
FROM cust_orders;

-- Top customers by LTV (lifetime spend)
SELECT
  "Customer ID",
  SUM("Sales") AS lifetime_sales,
  COUNT(DISTINCT "Order ID") AS orders_cnt
FROM data
GROUP BY "Customer ID"
ORDER BY lifetime_sales DESC
LIMIT 20;


/* ---------------------------------------------------------
   8) COHORT RETENTION (by first purchase month)
----------------------------------------------------------*/
WITH first_purchase AS (
  SELECT
    "Customer ID",
    MIN(DATE_TRUNC('month', "Order Date")) AS cohort_month
  FROM data
  GROUP BY "Customer ID"
),
activity AS (
  SELECT
    "Customer ID",
    DATE_TRUNC('month', "Order Date") AS activity_month
  FROM data
  GROUP BY 1,2
)
SELECT
  fp.cohort_month,
  a.activity_month,
  COUNT(DISTINCT a."Customer ID") AS active_customers
FROM first_purchase fp
JOIN activity a USING ("Customer ID")
GROUP BY 1,2
ORDER BY 1,2;


/* ---------------------------------------------------------
   9) GEO / MARKET INSIGHTS
----------------------------------------------------------*/
-- Sales by Market & Region
SELECT
  "Market",
  "Region",
  SUM("Sales") AS sales,
  SUM("Profit") AS profit
FROM data
GROUP BY 1,2
ORDER BY sales DESC;

-- Top countries by sales
SELECT
  "Country",
  SUM("Sales") AS sales,
  SUM("Profit") AS profit
FROM data
GROUP BY "Country"
ORDER BY sales DESC
LIMIT 15;


/* ---------------------------------------------------------
   10) PARETO / LONG TAIL: % of products driving revenue
----------------------------------------------------------*/
WITH prod_sales AS (
  SELECT
    "Product",
    SUM("Sales") AS sales
  FROM data
  GROUP BY "Product"
),
ranked AS (
  SELECT
    "Product",
    sales,
    SUM(sales) OVER () AS total_sales,
    SUM(sales) OVER (ORDER BY sales DESC) AS cum_sales
  FROM prod_sales
)
SELECT
  "Product",
  sales,
  ROUND(cum_sales/total_sales * 100, 2) AS cum_sales_pct
FROM ranked
ORDER BY sales DESC;

