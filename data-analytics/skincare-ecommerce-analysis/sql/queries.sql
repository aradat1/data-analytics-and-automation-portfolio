-- Preview first 20 rows
SELECT *
FROM data
LIMIT 20;

-- Total sales
SELECT SUM(Sales) AS total_sales
FROM data;

-- Average product price
SELECT AVG(Sales) AS avg_price
FROM data;

-- Sales by category
SELECT Category, SUM(Sales) AS category_sales
FROM data
GROUP BY Category
ORDER BY category_sales DESC;

-- Top 10 best-selling products
SELECT Product, SUM(Sales) AS product_sales
FROM data
GROUP BY Product
ORDER BY product_sales DESC
LIMIT 10;

-- Profitability analysis
SELECT Category, SUM(Profit) AS total_profit
FROM data
GROUP BY Category
ORDER BY total_profit DESC;

-- Discount impact
SELECT Discount, AVG(Profit) AS avg_profit
FROM data
GROUP BY Discount
ORDER BY Discount;

-- Sales by country
SELECT Country, SUM(Sales) AS total_country_sales
FROM data
GROUP BY Country
ORDER BY total_country_sales DESC;
