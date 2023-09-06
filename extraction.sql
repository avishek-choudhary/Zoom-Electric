-- Query 1
-- Extracting Sprint scooters sales data of first 3-weeks
WITH sprint_sales AS (
	SELECT ROW_NUMBER() OVER(ORDER BY sales_transaction_date) AS day,
		   DATE(sales_transaction_date) AS date,
	       COUNT(*) AS unit_sold
	FROM sales
	  JOIN products ON sales.product_id = products.product_id
	WHERE
	  products.model = 'Sprint'
	GROUP BY 2
	LIMIT 21
),
-- Calculating cumulative sales over a rolling 7-day period
cumm_sales AS (
	SELECT  *,
			SUM(unit_sold) 
			OVER(ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS cumm_7D
	FROM sprint_sales
)
--  Calculating the rate of growth
SELECT date, unit_sold, cumm_7D, cumm_7D_prev,
	   CONCAT(ROUND((100 * (cumm_7D - cumm_7D_prev) / cumm_7D_prev), 2), '%') AS growth
FROM (
	-- Calculating previous value of cumulative sales to calculate rate of growth
    SELECT *,
		   LAG(CASE WHEN day >= 7 THEN cumm_7D END) 
           OVER(ORDER BY day) AS cumm_7D_prev
	FROM cumm_sales) AS cumm_sales_prev;

-- Query 2
-- Extracting Sprint scooters sales data of first 3-weeks
WITH sprint_sales AS (
	SELECT ROW_NUMBER() OVER(ORDER BY sales_transaction_date) AS day,
		   DATE(sales_transaction_date) AS date,
		   COUNT(*) AS sprint
	FROM sales
	  JOIN products ON sales.product_id = products.product_id
	WHERE model = 'Sprint'
	GROUP BY 2
	LIMIT 21
),
-- Extracting Sprint Limited Edition variant sales data of first 3-weeks
sprintle_sales AS (
	SELECT ROW_NUMBER() OVER(ORDER BY sales_transaction_date) AS day,
		   DATE(sales_transaction_date) AS date,
		   COUNT(*) AS sprint_le
	FROM sales
	  JOIN products ON sales.product_id = products.product_id
	WHERE model = 'Sprint Limited Edition'
	GROUP BY 2
	LIMIT 21
),
-- Calculating cumulative sales Of both the variants over a rolling 7-day period
cumm_sales AS (
	SELECT  sprint_sales.day AS day,
			sprint, sprint_le,
			SUM(sprint) 
			OVER(ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS sprint_cl7,
			SUM(sprint_le) 
			OVER(ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS sprint_le_cl7
	FROM sprint_sales
	JOIN sprintle_sales ON sprint_sales.day = sprintle_sales.day
)
-- Calculating rate of growth of both the variants for comparision
SELECT day, sprint, sprint_le, sprint_cl7, sprint_le_cl7,
	   CONCAT(ROUND(100 * (sprint_cl7 - sprint_cl7_prev) / sprint_cl7_prev, 2), '%') 
		   AS sprint_growth,
       CONCAT(ROUND(100 * (sprint_le_cl7 - sprint_le_cl7_prev) / sprint_le_cl7_prev, 2), '%') 
		   AS sprint_le_growth
FROM ( 
	   -- Calculating previous value of cumulative sales to calculate rate of growth
	   SELECT *, 
			LAG(CASE WHEN day >= 7 THEN sprint_cl7 END) 
            OVER(ORDER BY day) AS sprint_cl7_prev, 
			LAG(CASE WHEN day >= 7 THEN sprint_le_cl7 END) 
            OVER(ORDER BY day) AS sprint_le_cl7_prev
	   FROM cumm_sales ) AS cumm_sales_prev;

-- Query 3
-- Extracting E-mail marketing data related to Sprint scooter 
WITH sprint_campaign AS (
	SELECT * 
	FROM emails
	WHERE sent_date
		-- assuming the campaign started 2 months before its production start date
		BETWEEN 
			(SELECT production_start_date
			 FROM products
			 WHERE model = 'Sprint') - INTERVAL 2 MONTH 
		AND
			(SELECT production_start_date
			 FROM products
			 WHERE model = 'Sprint')
)
-- Calculating the click through rate and email opening rate
SELECT CONCAT(ROUND(100 * clicked / (email_sent - bounced)),'%') AS click_rate,
	   CONCAT(ROUND(100 * opened / (email_sent - bounced)),'%') AS open_rate
FROM (
	  -- Summarizing the sprint_campaign data by counting the no. of emails- 
	  -- sent, clicked, opened & bounced for further calculation
	  SELECT COUNT(*) AS email_sent,
			 COUNT(CASE WHEN clicked = 't' THEN 1 END) AS clicked,
			 COUNT(CASE WHEN opened = 't' THEN 1 END) AS opened,
			 COUNT(CASE WHEN bounced = 't' THEN 1 END) AS bounced
	  FROM sprint_campaign) AS email_summary;
