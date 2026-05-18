-- ============================================
-- RETAIL SALES PERFORMANCE ANALYSIS
-- Author: Dave
-- Dataset: Sample Superstore (Kaggle)
-- Tool: MySQL Workbench
-- Description: Data cleaning and exploratory 
--              analysis of retail sales data
--              covering 9,994 transactions across
--              4 regions, 3 categories and 4 years
-- ============================================


-- ============================================
-- PHASE 1: DATA CLEANING
-- ============================================

-- CREATING A STAGING DATASET(TABLE) AS NEW COPY OF THE ORIGINAL

CREATE TABLE superstore_staging AS
SELECT *
FROM superstore;

SELECT *
FROM superstore_staging;

-- CHECKING FOR DUPLICATES

SELECT `Row ID` AS COUNT
FROM superstore_staging
GROUP BY `Row ID`
HAVING COUNT(*) > 1;

-- CHECKING FOR NULLS

SELECT 
SUM(CASE WHEN `Order ID` IS NULL THEN 1 ELSE 0 END) null_order_id,
SUM(CASE WHEN `Customer ID` IS NULL THEN 1 ELSE 0 END) null_customer_id,
SUM(CASE WHEN `Sales` IS NULL THEN 1 ELSE 0 END) null_sales,
SUM(CASE WHEN `Profit` IS NULL THEN 1 ELSE 0 END) null_profit,
SUM(CASE WHEN `Quantity` IS NULL THEN 1 ELSE 0 END) null_quantity
FROM superstore_staging;

-- CHECKING FOR ZERO OR NEGATIVE SALES

SELECT COUNT(*) AS suspicious_sales
FROM superstore_staging
WHERE Sales <= 0;

-- CHECKING DISTINCT CATEGORY VALUES

SELECT DISTINCT Segment 
FROM superstore_staging;

SELECT DISTINCT Region 
FROM superstore_staging;

SELECT DISTINCT Category
FROM superstore_staging;

SELECT DISTINCT `Sub-Category`
FROM superstore_staging;

-- FIXING THE DATA TYPE IN THE ORDER DATE AND SHIP DATE FIELD

SHOW COLUMNS 
FROM superstore_staging;

SELECT `Order Date`, `Ship Date`
FROM superstore_staging
LIMIT 5;

-- ADDING TWO NEW COLUMNS TO HOLD THE CONVERTED DATE

ALTER TABLE superstore_staging
ADD COLUMN Order_Date_Cleaned DATE,
ADD COLUMN Ship_Date_Cleaned DATE;

-- POPULATING WITH CONVERTED VALUES
UPDATE superstore_staging
SET
   Order_Date_Cleaned = STR_TO_DATE(`Order Date`, '%c/%e/%Y'),
   Ship_Date_Cleaned = STR_TO_DATE(`Ship Date`, '%c/%e/%Y');
   
   SELECT `Order Date`, Order_Date_Cleaned, `Ship Date`, Ship_Date_Cleaned
   FROM superstore_staging;
   
   
-- ============================================
-- PHASE 2: EXPLORATORY DATA ANALYSIS
-- ============================================

-- Analyse revenue, profit and margin by product category
-- to identify which categories drive the most business value

SELECT 
	  Category,
	  COUNT(`Order ID`) AS total_orders,
	  ROUND(SUM(Sales), 2) AS total_sales,
	  ROUND(SUM(Profit), 2) AS total_profit,
	  ROUND((SUM(Profit) / SUM(Sales)) * 100, 2) AS profit_margin_pct
FROM superstore_staging
GROUP BY Category
ORDER BY total_sales DESC;

-- Analyse revenue, profit and margin by geographic region
-- to identify which areas are the strongest and weakest performers

SELECT 
	  Region,
      COUNT(`Order ID`) as total_orders,
      ROUND(SUM(Sales), 2) AS total_sales,
      ROUND(SUM(Profit), 2) AS total_profit,
      ROUND((SUM(Profit) / SUM(Sales)) * 100, 2) AS profit_margin_pct
FROM superstore_staging
GROUP BY Region
ORDER BY total_sales DESC;

-- Analyse year over year sales and profit growth
-- to identify whether the business is trending in the right direction

SELECT
     YEAR(Order_Date_Cleaned) AS order_year,
     COUNT(`Order ID`) AS total_orders,
     ROUND(SUM(Sales), 2) AS total_sales,
     ROUND(SUM(Profit), 2) AS total_profit
FROM superstore_staging
GROUP BY YEAR(Order_Date_Cleaned)
ORDER BY order_year ASC;

-- JOINS 
-- CREATING A CUSTOMERS SUMMARY TABLE

CREATE TABLE customers AS 
SELECT 
`Customer ID`,
`Customer Name`,
Segment,
Region,
COUNT(`Order ID`) AS total_orders,
ROUND(SUM(Sales), 2) AS total_spent
FROM superstore_staging
GROUP BY `Customer ID`, `Customer Name`, Segment, Region;

SELECT *
FROM customers;

-- FINDING HIGH VALUE REPEAT BUYERS

SELECT 
      c.`Customer Name`,
      c.Segment,
      c.Region, 
      c.total_orders,
      c.total_spent,
      s.Category,
ROUND(SUM(s.Sales), 2) AS category_spend
FROM customers c
JOIN superstore_staging s
    ON c.`Customer ID` = s.`Customer ID`
    WHERE c.total_orders > 5
    AND c.total_spent > 1000
GROUP BY 
        c.`Customer Name`,
        c.Segment,
        c.Region,
        c.total_orders,
        c.total_spent,
        s.Category
ORDER BY c.total_spent DESC;

-- TOP 10 OVERALL HIGHEST VALUE CUSTOMERS

SELECT
      c.`Customer Name`,
      c.Region,
      c.Segment,
      c.total_orders,
      c.total_spent,
      ROUND(c.total_spent / c.total_orders) AS avg_order_value
FROM customers c
JOIN superstore_staging s
ON c.`Customer ID` = s.`Customer ID`
GROUP BY 
	c.`Customer Name`,
    c.Region,
    c.Segment,
    c.total_orders,
    c.total_spent
ORDER BY total_spent DESC
LIMIT 10;

-- TOP 5 MOST PROFITABLE PRODUCTS IN THE CATEGORY USING CTEs

WITH product_profit AS 
 (
 -- Step 1: Calculate total profit and sales per product
 SELECT
       Category,
       `Product Name`,
       ROUND(SUM(Sales), 2) AS total_sales,
       ROUND(SUM(Profit), 2) AS total_profit,
       ROUND((SUM(Profit) / SUM(Sales)) * 100, 2) AS profit_margin_pct
FROM superstore_staging
GROUP BY Category, `Product Name`
),
ranked_product AS
(
-- Step 2: Rank product within each category by profit
SELECT
      Category,
      `Product Name`,
      total_sales,
      total_profit,
      profit_margin_pct,
      RANK() OVER(PARTITION BY Category ORDER BY total_profit DESC) AS profit_rank
      FROM product_profit
)
-- Step 3: Filter to only top 5 category
SELECT *
FROM ranked_product
WHERE profit_rank <= 5
ORDER BY Category, profit_rank;

-- TOP MOST PROFITABLE PRODUCT PER REGION

WITH region_product_profit AS
(
-- Step 1: Calculate total profit per region
SELECT 
      Region,
      `Product Name`, 
      Category,
      ROUND(SUM(Sales), 2) AS total_sales,
      ROUND(SUM(Profit), 2) AS total_profit,
      ROUND((SUM(profit) / SUM(Sales)) * 100, 2) AS profit_margin_pct
      FROM superstore_staging
      GROUP  BY Region, `Product Name`, Category
),
ranked_by_region AS 
(
-- Step 2: Rank product within each region by profit
SELECT
      Region,
      `Product Name`,
      Category,
      total_sales,
      total_profit,
      profit_margin_pct,
RANK() OVER(PARTITION BY Region ORDER BY total_profit DESC) AS profit_rank
FROM region_product_profit
)
-- Step 3: Filter only top 5 region
SELECT *
FROM ranked_by_region
WHERE profit_rank <= 5
ORDER BY Region, profit_rank;


-- MONTH OVER MONTH SALES GROWTH USING LAG()

WITH monthly_sales AS 
(
-- Step 1: Summarize total sales per month per year
SELECT
      YEAR(Order_Date_Cleaned) AS order_year,
      MONTH(Order_Date_Cleaned) AS order_month,
      ROUND(SUM(Sales), 2) AS total_sales
FROM superstore_staging
GROUP BY 
        YEAR(Order_Date_Cleaned),
        MONTH(Order_Date_Cleaned)
),
sales_with_lag AS 
(
-- Step 2: Use LAG to pull the previous month sale
SELECT 
      order_year,
      order_month,
      total_sales,
      LAG(total_sales) OVER(ORDER BY order_year, order_month) AS prev_month_sales
      FROM monthly_sales
)
-- Step 3: Calculate growth percentage
SELECT
      order_year,
      order_month,
      total_sales,
      prev_month_sales,
      ROUND(
      ((total_sales - prev_month_sales) / prev_month_sales) * 100, 2) AS growth_pct
FROM sales_with_lag
ORDER BY order_year, order_month;
      
      
-- RANK CUSTOMERS BY TOTAL SPEND WITHIN EACH REGION USING RANK()
      
WITH customer_spending AS 
(
-- Step 1: Summarize total spending per customer per region
SELECT 
	  Region,
	  `Customer Name`,
	  Segment,
	  ROUND(SUM(sales), 2) AS total_spent,
	  COUNT(`Order ID`) AS total_orders
FROM superstore_staging
GROUP BY Region, `Customer Name`, Segment
),
ranked_customers AS 
(
-- Step 2: Rank customer within each region by total spend
SELECT 
	  Region,
	  `Customer Name`,
	  Segment,
	  total_spent,
	  total_orders,
RANK() OVER(PARTITION BY Region ORDER BY total_spent DESC) AS spending_rank
FROM customer_spending
)
-- Step 3: Show only top 5 per region
SELECT *
FROM ranked_customers
WHERE spending_rank <= 5
ORDER BY Region, spending_rank;