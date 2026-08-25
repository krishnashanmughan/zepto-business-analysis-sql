-- ============================================================
-- Zepto Quick-Commerce Business Analysis (SQL)
-- Dataset: synthetic practice data (~15K rows/table)
-- Engine : MySQL
-- ============================================================

CREATE DATABASE IF NOT EXISTS zepto_db;
USE zepto_db;

-- ------------------------------------------------------------
-- TABLE DEFINITIONS
-- ------------------------------------------------------------
DROP TABLE IF EXISTS `customer`;
CREATE TABLE `customer`(
  `C_ID` varchar(50) NOT NULL,
  `Name` varchar(50) NOT NULL,
  `Gender` varchar(50),
  `Age` int,
  `City` varchar(50),
  `State` varchar(50),
  `Created_date` date,
  PRIMARY KEY(`C_ID`)
);

DROP TABLE IF EXISTS `products`;
CREATE TABLE `products`(
  `P_ID` varchar(50) NOT NULL,
  `PName` varchar(50),
  `Category` varchar(50),
  `Brand` varchar(50),
  `Price` decimal(10,2),
  PRIMARY KEY(`P_ID`)
);

DROP TABLE IF EXISTS `delivery`;
CREATE TABLE `delivery`(
  `DP_ID` varchar(50) NOT NULL,
  `DP_name` varchar(50),
  `delivery_partner` varchar(50),
  PRIMARY KEY(`DP_ID`)
);

DROP TABLE IF EXISTS `orders`;
CREATE TABLE `orders`(
  `OR_ID` varchar(20) NOT NULL,
  `C_ID` varchar(20) NOT NULL,
  `P_ID` varchar(20) NOT NULL,
  `Order_Date` date NOT NULL,
  `Order_Time` time NOT NULL,
  `Qty` int NOT NULL,
  `Coupon` varchar(20),
  `Coupon_Discount` int,
  `DP_ID` varchar(20) NOT NULL,
  PRIMARY KEY(`OR_ID`)
);

DROP TABLE IF EXISTS `ratings`;
CREATE TABLE `ratings`(
  `RT_ID` varchar(20) NOT NULL,
  `OR_ID` varchar(20) NOT NULL,
  `Prod_Rating` int,
  `Delivery_Rating` int,
  PRIMARY KEY(`RT_ID`)
);

DROP TABLE IF EXISTS `transactions`;
CREATE TABLE `transactions`(
  `TR_ID` varchar(20) NOT NULL,
  `OR_ID` varchar(20) NOT NULL,
  `Transaction_Mode` varchar(20) NOT NULL,
  `Transaction_Status` varchar(20) NOT NULL,
  PRIMARY KEY(`TR_ID`)
);

-- ============================================================
-- CUSTOMER ANALYSIS
-- ============================================================

-- 1. Top 10 customers by total spending
SELECT c.C_ID, c.Name,
       ROUND(SUM(o.Qty * p.Price), 2) AS total_spending
FROM customer c
JOIN orders o USING (C_ID)
JOIN products p USING (P_ID)
GROUP BY c.C_ID, c.Name
ORDER BY total_spending DESC
LIMIT 10;

-- 2. Customers who placed only one order (retention gap)
SELECT COUNT(*) AS one_time_customers
FROM (
  SELECT C_ID
  FROM orders
  GROUP BY C_ID
  HAVING COUNT(OR_ID) = 1
) t;

-- 3. Average days between a customer's consecutive orders
WITH gaps AS (
  SELECT C_ID, Order_Date,
         LEAD(Order_Date) OVER (PARTITION BY C_ID ORDER BY Order_Date) AS next_date
  FROM orders
)
SELECT ROUND(AVG(DATEDIFF(next_date, Order_Date)), 0) AS avg_days_between_orders
FROM gaps
WHERE next_date IS NOT NULL;

-- 4. Highest-frequency customers in the last 30 days
SELECT C_ID, COUNT(OR_ID) AS order_frequency
FROM orders
WHERE Order_Date >= (SELECT MAX(Order_Date) FROM orders) - INTERVAL 30 DAY
GROUP BY C_ID
ORDER BY order_frequency DESC
LIMIT 5;

-- 5. Repeat-purchase rate (% of customers with 2+ orders)
SELECT ROUND(
         COUNT(*) * 100.0 / (SELECT COUNT(DISTINCT C_ID) FROM customer), 2
       ) AS repeat_customer_pct
FROM (
  SELECT C_ID
  FROM orders
  GROUP BY C_ID
  HAVING COUNT(OR_ID) > 1
) t;

-- ============================================================
-- PRODUCT & REVENUE ANALYSIS
-- ============================================================

-- 6. Top 5 products by revenue
SELECT p.PName, p.Brand,
       ROUND(SUM(p.Price * o.Qty), 2) AS revenue
FROM products p
JOIN orders o USING (P_ID)
GROUP BY p.P_ID, p.PName, p.Brand
ORDER BY revenue DESC
LIMIT 5;

-- 7. Average order value per category
SELECT p.Category,
       ROUND(AVG(p.Price * o.Qty), 2) AS avg_order_value
FROM products p
JOIN orders o ON p.P_ID = o.P_ID
GROUP BY p.Category
ORDER BY avg_order_value DESC;

-- 8. Average discount per category
SELECT p.Category,
       ROUND(AVG(o.Coupon_Discount), 2) AS avg_discount
FROM products p
JOIN orders o ON p.P_ID = o.P_ID
GROUP BY p.Category
ORDER BY avg_discount DESC;

-- 9. Products with highest month-over-month sales growth
WITH monthly_sales AS (
  SELECT P_ID,
         DATE_FORMAT(Order_Date, '%Y-%m') AS ym,
         SUM(Qty) AS total_qty
  FROM orders
  GROUP BY P_ID, ym
),
growth AS (
  SELECT P_ID, ym, total_qty,
         LAG(total_qty) OVER (PARTITION BY P_ID ORDER BY ym) AS prev_qty
  FROM monthly_sales
)
SELECT P_ID, ym, total_qty, prev_qty,
       ROUND((total_qty - prev_qty) / prev_qty * 100, 2) AS growth_pct
FROM growth
WHERE prev_qty IS NOT NULL
ORDER BY growth_pct DESC
LIMIT 5;

-- ============================================================
-- TIME-BASED DEMAND
-- ============================================================

-- 10. Busiest weekday by order count
SELECT DAYNAME(Order_Date) AS weekday,
       COUNT(OR_ID) AS total_orders
FROM orders
GROUP BY DAYNAME(Order_Date)
ORDER BY total_orders DESC;

-- 11. Busiest hour of the day
SELECT EXTRACT(HOUR FROM Order_Time) AS order_hour,
       COUNT(*) AS order_count
FROM orders
GROUP BY order_hour
ORDER BY order_count DESC;

-- 12. Total revenue by city (top 5)
SELECT c.City,
       ROUND(SUM(p.Price * o.Qty), 2) AS total_revenue
FROM customer c
JOIN orders o ON c.C_ID = o.C_ID
JOIN products p ON p.P_ID = o.P_ID
GROUP BY c.City
ORDER BY total_revenue DESC
LIMIT 5;

-- 13. Orders per year
SELECT EXTRACT(YEAR FROM Order_Date) AS yr,
       COUNT(*) AS order_count
FROM orders
GROUP BY yr
ORDER BY order_count DESC;

-- 14. Orders per month
SELECT MONTHNAME(Order_Date) AS mth,
       COUNT(*) AS order_count
FROM orders
GROUP BY mth
ORDER BY order_count DESC;

-- ============================================================
-- TRANSACTIONS & PAYMENTS
-- ============================================================

-- 15. Overall payment failure rate
SELECT ROUND(
         SUM(Transaction_Status = 'Failed') * 100.0 / COUNT(*), 2
       ) AS failure_rate_pct
FROM transactions;

-- 16. Success RATE by payment method  [FIXED]
--     Correct rate = successes of a mode / total of THAT mode
--     (the earlier version divided by all transactions, which is not a rate)
SELECT Transaction_Mode,
       ROUND(SUM(Transaction_Status = 'Success') * 100.0 / COUNT(*), 2) AS success_rate_pct
FROM transactions
GROUP BY Transaction_Mode
ORDER BY success_rate_pct DESC;

-- 17. Average transaction value by payment method
SELECT t.Transaction_Mode,
       ROUND(AVG(p.Price * o.Qty), 2) AS avg_transaction_value
FROM transactions t
JOIN orders o ON t.OR_ID = o.OR_ID
JOIN products p ON p.P_ID = o.P_ID
GROUP BY t.Transaction_Mode
ORDER BY avg_transaction_value DESC;

-- ============================================================
-- DELIVERY PERFORMANCE
-- ============================================================

-- 18. Share of orders handled by each delivery partner  [FIXED]
--     (replaced the hardcoded 15000 with a live total-orders subquery)
SELECT d.delivery_partner,
       ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM orders), 2) AS order_share_pct
FROM delivery d
JOIN orders o ON d.DP_ID = o.DP_ID
GROUP BY d.delivery_partner
ORDER BY COUNT(*) DESC;

-- 19. Average orders handled per active day by partner
SELECT d.delivery_partner,
       ROUND(COUNT(o.OR_ID) / COUNT(DISTINCT o.Order_Date), 0) AS avg_orders_per_day
FROM delivery d
JOIN orders o ON d.DP_ID = o.DP_ID
GROUP BY d.delivery_partner
ORDER BY avg_orders_per_day DESC;

-- 20. Count of delivery-service ratings per partner
SELECT d.delivery_partner,
       COUNT(r.Delivery_Rating) AS rating_count
FROM delivery d
JOIN orders o ON d.DP_ID = o.DP_ID
JOIN ratings r ON o.OR_ID = r.OR_ID
GROUP BY d.delivery_partner
ORDER BY rating_count DESC;
