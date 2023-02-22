/* 

CODE BASICS RESUME PROJECT CHALLENGE #4

ATLIQ HARDWARE'S MANAGEMENT WANTS TO GET SOME INSIGHTS IN THE SALES OF ITS PRODUCTS. 
AS A DATA ANALYST MY TASK IS TO RESPOND TO 10 AD-HOC QUERIES ASSIGNED TO ME. 


*/

SELECT distinct customer
from dim_customer
;
-- 1. List of markets in which customer "Atliq Exlcusive" operates business in the APAC region

SELECT distinct market
FROM dim_customer 
where region = "APAC" and customer="Atliq Exclusive"
;


-- 2. What is the percentage of unique product increase in 2021 vs 2020?

with tot_products as
		(SELECT count( distinct product_code) as total_products, fiscal_year as year
		FROM fact_sales_monthly 
		GROUP BY fiscal_year)
        
SELECT a.total_products as unique_products_2020,b.total_products as unique_products_2021, 
		(b.total_products - a.total_products) as new_products_introduced,
		ROUND((b.total_products - a.total_products) /a.total_products *100, 2) as pct_change
FROM tot_products as a
LEFT JOIN tot_products as b
ON a.year+1 = b.year
LIMIT 1
;

-- 3. A report on all unique products for each segment, sorted in descending order.

SELECT segment, count(distinct product_code) as product_count
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC
;

-- 4. segment wise unique product percentage change

with tot_products as
		(SELECT count( distinct fs.product_code) as total_products, fiscal_year , segment
		FROM fact_sales_monthly as fs
        LEFT JOIN dim_product 
        ON fs.product_code = dim_product.product_code
		GROUP BY fiscal_year, segment)
SELECT a.total_products as unique_products_2020,
		b.total_products as unique_products_2021, 
        b.total_products - a.total_products as difference,
        a.segment,
	ROUND((b.total_products-a.total_products) /a.total_products *100 , 2) as pct_change
	
FROM tot_products as a
LEFT JOIN tot_products as b
ON (a.fiscal_year+1 = b.fiscal_year and a.segment = b.segment)
WHERE b.total_products is not null
ORDER BY a.fiscal_year,pct_change DESC
;

-- 5. Products with highest and lowest manufacturing cost

SELECT 
	*
FROM 
	-- getting max value
	(select dp.product_code, fm.manufacturing_cost as manufacturing_cost_max_min, dp.product, segment
	FROM fact_manufacturing_cost as fm
    INNER JOIN dim_product as dp
    ON fm.product_code = dp.product_code
	where fm.manufacturing_cost = (SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost)) as table1

UNION ALL
	-- getting min value
	(select dp.product_code, fm.manufacturing_cost as manufacturing_cost_max_min, dp.product, segment
	FROM fact_manufacturing_cost as fm
	INNER JOIN dim_product as dp
	ON fm.product_code = dp.product_code
	where manufacturing_cost = (SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost)  )
;


-- 6. A report which contains top 5 customers who received an average high pre_invoice_discount_pct 
-- for the fiscal_year 2021 and in the Indian market

SELECT  dc.customer,
		dc.customer_code,
		ROUND(fp.pre_invoice_discount_pct * 100, 2)  as Avg_disc_pct 
    
FROM fact_pre_invoice_deductions as fp
INNER JOIN dim_customer as dc
ON fp.customer_code = dc.customer_code
WHERE fiscal_year = 2021 and market = "India"
GROUP BY dc.customer 
ORDER BY Avg_disc_pct DESC
LIMIT 5
;



-- 7. A complete report of Gross sales amount for the customer "Atliq Exclusive" for each month
-- This analysis helps to get an idea of low and high-performing months and take strategic decisions

SELECT 
		YEAR(date) as Year,
		MONTH(date) as month,
		sum(sold_quantity * gross_price) AS gross_sales_amount

FROM fact_sales_monthly as fs
INNER JOIN fact_gross_price as fp
ON fs.product_code = fp.product_code and fs.fiscal_year = fp.fiscal_year
INNER JOIN dim_customer as dc
ON fs.customer_code = dc.customer_code
WHERE customer = "Atliq Exclusive"
group by month, YEAR(date)
ORDER BY Year, month
;

-- 8. 2020 Quarter with maximum quantities sold

SELECT 
	CASE
		WHEN MONTH(date) BETWEEN 9 AND 11 THEN 'FIRST QUARTER'
        WHEN MONTH(date) BETWEEN 12 AND 2 THEN 'SECOND QUARTER'
        WHEN MONTH(date) BETWEEN 3 AND 5 THEN 'THIRD QUARTER'
        WHEN MONTH(date) BETWEEN 6 AND 8 THEN 'FOURTH QUARTER'
	END AS QUARTER ,
	date,
    CONCAT(CAST(ROUND(SUM(sold_quantity)/1000000, 2) AS CHAR), " M")   
    as total_quantities_sold
FROM fact_sales_monthly 
WHERE fiscal_year = 2020
GROUP BY QUARTER
ORDER BY total_quantities_sold DESC
;

-- 9. Channel with more gross sales in 2021 and percentage contributions

WITH channels as (SELECT 
						channel,
						(SUM(sold_quantity * gross_price) / 1000000) as gross_sales_mln
				FROM fact_sales_monthly as fm
				JOIN fact_gross_price as fp
				ON fm.product_code = fp.product_code
				JOIN dim_customer as dc
				ON fm.customer_code = dc.customer_code
				WHERE fm.fiscal_year = 2021
				GROUP BY channel
				ORDER BY gross_sales_mln DESC )

SELECT *,
		ROUND(gross_sales_mln * 100 / (SELECT SUM(gross_sales_mln) FROM channels) ,2) as pct_contributions
FROM channels
;


-- 10. Top 3 products  in each division that has high total_sold_quantity for fiscal year 2021

WITH ranked_product as (
			-- creating a table with total_sold_quantities and rank_order columns
			WITH top_product AS (SELECT  fm.product_code,
											product,
											division,
											SUM(sold_quantity) as total_sold_quantity
								FROM fact_sales_monthly as fm
								JOIN dim_product as dp 
								ON fm.product_code = dp.product_code
								WHERE fiscal_year =2021
								GROUP BY fm.product_code, division
								ORDER BY total_sold_quantity DESC)

			SELECT *,
					-- creating a rank column
					RANK () OVER ( PARTITION BY division
					ORDER BY total_sold_quantity DESC) as rank_order
			FROM top_product )

-- finally filtering the above created table to have 1,2 and 3 ranks
SELECT *
FROM ranked_product 
WHERE rank_order in (1,2,3)
;


-- Extra Insights
-- Number of products that were discontinued in year 2021 from 2020.

SELECT DISTINCT product_code, product,segment, fiscal_year  
FROM fact_sales_monthly as fm
JOIN dim_product as dp 
USING (product_code)
WHERE product_code NOT IN (SELECT DISTINCT product_code 
							FROM fact_sales_monthly 
                            WHERE fiscal_year=2021) 
and fiscal_year = 2020
;

            