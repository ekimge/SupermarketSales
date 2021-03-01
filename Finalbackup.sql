/* OUR DATA:
"We will be looking at some sales data from a supermarket based in Mexico. It is a simple dataset and we should be able to extract some value.

Our dataset had 5 columns:
1. Folio - holds transaction ID's, we can repurpose this column or get rid of it.
2. Hora - Holds information on the exact time a transaction occurred, we should convert it to datetime.
3. Total - The sale total. 
4. Pago - Total payment by the customer. We don't need this and will drop this column.
5. Cajero - The cashier ID or name. 

So, the dataset we load has four columns, we rename the column names with their English translations: Sale_ID, Sale_Date, Sale_Total, Cashier_Name.
*/

LOAD DATA INFILE "C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\Sales.csv" INTO TABLE sales
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(sale_id,sale_date,sale_total,cashier_name);

SELECT * FROM sales;

#We want to reformat some of our columns. First we look at our Sale_Date column and reformat it to have the following format: YYYY:MM:DD HH:MM:SS
#The Query below uses CONCAT to reformat the date into our desired format.

SELECT CONCAT(
	SUBSTRING(sale_date,7,4),
    '/', 
    SUBSTRING(sale_date, 4,2),
    '/', 
    LEFT(sale_date, 2),
    ' ',  
    RIGHT(sale_date,5),
    ':00'
    ) AS Dates FROM sales ;

/*We can either get rid of the Sale_Id column or keep it. The values in the Sale_Date column are unique so can stand in for a ID column. 
We keep it for now but drop several characters using string manipulation. */

SELECT RIGHT(sale_id, (LENGTH(sale_id) - 4))  AS id FROM sales;

#We use the above SELECT statements to create a new table. We keep the remaining columns the same:

CREATE TABLE new_sales_table SELECT 
		RIGHT(sale_id, (LENGTH(sale_id) - 4))  AS id,
		CONCAT(
			SUBSTRING(sale_date,7,4),
			'/', 
			SUBSTRING(sale_date, 4,2),
			'/', 
			LEFT(sale_date, 2),
			' ',  
			RIGHT(sale_date,5),
			':00'
			) AS dates,
		sale_total, 
		cashier_name 
    FROM sales; 
    
SELECT * FROM new_sales_table;

#Our table looks good, we should check the data type of each column.

SELECT DATA_TYPE 
FROM INFORMATION_SCHEMA.COLUMNS
WHERE 
     TABLE_NAME = 'new_sales_table'; 

/* Our columns have the following data types: 
1.varchar
2.datetime
3.decimal
4.varchar. */

#Now we can start looking into our data. First, let's observe what sales looked like across days.

SELECT COUNT(*), date_format(dates, "%a") AS day FROM new_sales_table
GROUP BY 2
ORDER BY 1 DESC;

/*Sundays had the highest number of sales by far. This makes sense as people tend to shop for the week ahead. Saturday came second but wasn't too far above 
the remaining days. 

Let us compare weekdays with weekends:  */

SELECT COUNT(*) AS total_sales,

	COUNT(*) - 
	(SELECT
		COUNT(CASE
			WHEN date_format(dates, "%a") = 'Sat' THEN 'Weekend'
			WHEN date_format(dates, "%a") = 'Sun' THEN 'Weekend'		
		END) AS Weekend
    FROM new_sales_table) weekdays, 
    
    (SELECT
		COUNT(CASE
			WHEN date_format(dates, "%a") = 'Sat' THEN 'Weekend'
			WHEN date_format(dates, "%a") = 'Sun' THEN 'Weekend'		
		END) AS Weekend
    FROM new_sales_table) weekends,
    
	(COUNT(*) - 
	(SELECT
		COUNT(CASE
			WHEN date_format(dates, "%a") = 'Sat' THEN 'Weekend'
			WHEN date_format(dates, "%a") = 'Sun' THEN 'Weekend'		
		END) AS Weekend
    FROM new_sales_table))/COUNT(*) AS weekday_sale_ratio,
    
    (SELECT
		COUNT(CASE
			WHEN date_format(dates, "%a") = 'Sat' THEN 'Weekend'
			WHEN date_format(dates, "%a") = 'Sun' THEN 'Weekend'		
		END) AS Weekend
    FROM new_sales_table)/COUNT(*) AS weekend_sale_ratio
    
FROM new_sales_table;

/*Using the CASE statements above we can compare weekdays and weekends. We also look at the ratio of sales in these categories:
 Total:84881	Weekdays:55393	Weekends:29488	Weekday_Sale_Ratio:0.6526	Weekend_Sale_Ratio: 0.3474
 
 Just over a third of sales occur two days, Saturday and Sunday.
 
 Now we have some idea of what our sales looked like over a week, we can look at how they changed across the day:
*/
 
#The earliest and latest sales in our data:
SELECT MIN(date_format(dates, '%H:%i:%s')) earliest, MAX(date_format(dates, '%H:%i:%s')) latest FROM new_sales_table;

#The earliest occurred at 07:16AM and the latest at 21:39PM. We can assume that the store runs between 07:00-22:00.

#Now I want to split the day into 3 periods - morning, afternoon and evening. We want to understand how sales evolve over the average day.

SELECT 
	COUNT(CASE WHEN date_format(dates, '%H:%i:%s') >= '06:00:00' AND date_format(dates, '%H:%i:%s') <= '12:00:00' THEN 1 END) AS '07:00-12:00',
	COUNT(CASE WHEN date_format(dates, '%H:%i:%s') >= '12:00:00' AND date_format(dates, '%H:%i:%s') <= '18:00:00' THEN 1 END) AS '12:00-18:00',
	COUNT(CASE WHEN date_format(dates, '%H:%i:%s') >= '18:00:00' AND date_format(dates, '%H:%i:%s') <= '22:00:00' THEN 1 END) AS '18:00-22:00'
FROM new_sales_table;

/* Morning:18264	Afternoon:42130		Evening:24643
We see that most sales occurred during the afternoon, followed by the evening and finally the morning. We can look at hourly sales to get a better #
of how sales are distributed over the day  */

SELECT SEC_TO_TIME(TIME_TO_SEC(dates)- TIME_TO_SEC(dates)%(60*60)) AS intervals, COUNT(*) AS sales_in_period FROM new_sales_table
GROUP BY intervals ORDER BY 1;

/*The hourly intervals show that while our previous findings were correct and the afternoon is the busiest period overall but  the number of sales#
is at its highest between 20:00 - 21:00, shortly before the store closes. 

As an example, we can look further into the first week of sales:
*/

SELECT MIN(date_format(dates, '%y-%m-%d')) first_day FROM new_sales_table; 
#First day in the dataset is 18-05-01.

SELECT 
	SEC_TO_TIME(TIME_TO_SEC(dates)- TIME_TO_SEC(dates)%(60*60)) AS intervals, 
	COUNT(*) AS sales_in_interval, 
    date_format(dates, '%y-%m-%d') AS dates
FROM new_sales_table
GROUP BY 1, 3
HAVING dates BETWEEN '18-05-01' AND '18-05-07'
ORDER BY 3, 1;

/* The changes in sales across each day in the first week seems consistent with our findings above. It tends to peak in the afternoon period.
Now, we can take a look at how many cashiers we had working in each interval in the first week.*/

SELECT 
	cashiers.*, 
    DENSE_RANK() OVER (PARTITION BY intervals ORDER BY cashier_name) + DENSE_RANK() OVER (PARTITION BY intervals ORDER BY cashier_name DESC) - 1 
    AS cashier_count
FROM
	(SELECT 		
		cashier_name, 
		sale_total, 
		date_format(dates, '%H:%i') AS time, 
		SEC_TO_TIME(TIME_TO_SEC(dates)- TIME_TO_SEC(dates)%(60*60)) AS intervals
FROM new_sales_table WHERE dates BETWEEN '18-05-01 07:00:00' AND '18-05-01 22:00:00'
ORDER BY 3) cashiers 
ORDER BY 3;
/*Using a window function we get a count of the number of cashiers working across each hourly interval in the first day. It seems that the number of 
cashiers working concurrently peaks at 5 between 15:00 and 16:00. */

#The above code can be useful in generating sales reports over a range of days so we can create a procedure to use in the future:

DELIMITER $$
CREATE DEFINER=`root`@`localhost` PROCEDURE `Date Union`(First_Day DATETIME, Last_Day DATETIME)
BEGIN
	SET First_Day = First_Day;
	SET Last_Day = Last_Day;
    
    WHILE First_Day <= Last_Day DO 
    
	 (SELECT sale_count.intervals, 
			 sale_count.sales_in_period, 
			 cashiers.cashier_count,
			 date_format(First_Day, '%d %b') AS dates

		FROM
			(SELECT 
				SEC_TO_TIME(TIME_TO_SEC(dates) - TIME_TO_SEC(dates)%(60*60)) AS intervals, 
				COUNT(*) AS sales_in_period 	
			FROM new_sales_table 
			WHERE dates BETWEEN First_Day AND DATE_ADD(date_format(First_Day, '%y-%m-%d'), INTERVAL 1 DAY)
			GROUP BY intervals) sale_count
		JOIN
			(SELECT 
				cashiers.*, 
				DENSE_RANK() OVER (PARTITION BY intervals ORDER BY cashier_name) + DENSE_RANK() OVER (PARTITION BY intervals ORDER BY cashier_name DESC) - 1 
				AS cashier_count
			FROM
			(SELECT 
				dates,
				cashier_name, 
				sale_total, 
				date_format(dates, '%H:%i') AS time, 
				SEC_TO_TIME(TIME_TO_SEC(dates)- TIME_TO_SEC(dates)%(60*60)) AS intervals
			FROM new_sales_table WHERE dates BETWEEN First_Day AND DATE_ADD(date_format(First_Day, '%y-%m-%d'), INTERVAL 1 DAY) ORDER BY 3) cashiers 
			ORDER BY 3) cashiers 
	ON  sale_count.intervals = cashiers.intervals
	GROUP BY cashiers.intervals ORDER BY 1);

	SET First_Day = DATE_ADD(date_format(First_Day, '%y-%m-%d'), INTERVAL 1 DAY);
    
END WHILE; 
 

END
$$ DELIMITER ;


/*We test it for the first day in our dataset and get the following output:
Interval	Sales  Cashiers Date
07:00:00	3		1		01 May
08:00:00	15		2		01 May
09:00:00	25		2		01 May
10:00:00	58		3		01 May
11:00:00	41		4		01 May
12:00:00	52		3		01 May
13:00:00	71		4		01 May
14:00:00	74		4		01 May
15:00:00	66		5		01 May
16:00:00	55		3		01 May
17:00:00	42		3		01 May
18:00:00	50		3		01 May
19:00:00	74		3		01 May
20:00:00	70		4		01 May
21:00:00	17		3		01 May 

So far we have: 

1. Imported and restructured our data.

2. Conducted some introductory analysis to observe sales trends over: 
	a. Days,
	b. Periods within days
	c. Hourly intervals

3. Explored the first day in our dataset to observe:
	a. How sales changed across the day.
    b. How many cashiers we had working across the day.
    
4. Created a Procedure which produces a daily report observing the following metrics: 
	a. Hourly Interval
    b. Count of Sales
    c. Number of Cashiers
    d. Date
    
We now want to conduct an analysis of the transactions and find a way to quantify the performance of our cashiers.
*/

#Lets look at the 10 largest transactions:
SELECT cashier_name, dates, sale_total FROM new_sales_table
ORDER BY 3 DESC LIMIT 10;

#Lets look at what proportion of our transaction we deem large (>1000 in value):
SELECT COUNT(sale_total) FROM new_sales_table 
WHERE sale_total > 1000; 

#1781 sales > 1000 

#As a percentage of the total:
SELECT 
	(SELECT COUNT(sale_total) FROM new_sales_table WHERE sale_total > 1000) / (SELECT COUNT(sale_total) FROM new_sales_table)*100 AS Percentage;

/*	2% of sales were large, had they been a larger proportion we would have had to count them separately when doing analysis but since they 
make up such a small percentage this won't be necessary.

We now want to determine a method to quantify the performance of our cashiers.

To do this we will further drill down into the intervals. Instead of hourly periods we will look at 10 minute periods. We will compare each cashier 
in periods where they are not working alone to the other cashiers working with them and compare this to the expected sales they each would make
had they made an equal proportion of sales in the given period. */

/*We previously wrote code to split our data into hourly intervals. We can alter this code to look at 10 minute intervals across the entire dataset using:

SEC_TO_TIME(TIME_TO_SEC(dates) - TIME_TO_SEC(dates)%(10*60)) AS intervals    - To look at 10 minute periods.

And  WHERE dates BETWEEN '18-05-01 07:00:00' AND '18-08-31 22:00:00'	- To look at the entire dataset rather than at individual days. 

We don't need to get every single 10 minute block, this would be unnecessary and would bloat the table. Instead we take the 10 minute intervals where we 
actually had sales occur.

We want to save this query as a table. We will call it 'hourlies'.
 */

CREATE TABLE hourlies AS
(SELECT 
	CAST(CONCAT(LEFT(dates,10),' ', intervals)  AS DATETIME) AS date,
	intervals, 
	name,
    total_sales
FROM 
    (SELECT 
		sale_count.intervals, 
        cashiers.cashier_name AS name,
        SUM(cashiers.sale_total) AS total_sales,
        cashiers.cashier_count,
		dates
	FROM
		(SELECT 
			SEC_TO_TIME(TIME_TO_SEC(dates) - TIME_TO_SEC(dates)%(10*60)) AS intervals, 
			COUNT(*) AS sales_in_period 	
		FROM new_sales_table 
		WHERE dates BETWEEN '18-05-01 07:00:00' AND '18-08-31 22:00:00'
		GROUP BY intervals) sale_count
	JOIN
		(SELECT 
			cashiers.*, 
			DENSE_RANK() OVER (PARTITION BY intervals ORDER BY cashier_name) + DENSE_RANK() OVER (PARTITION BY intervals ORDER BY cashier_name DESC) - 1 
			AS cashier_count
		FROM
		(SELECT 
			dates,
			cashier_name, 
			sale_total, 
			date_format(dates, '%H:%i') AS time, 
			SEC_TO_TIME(TIME_TO_SEC(dates)- TIME_TO_SEC(dates)%(10*60)) AS intervals
		FROM new_sales_table WHERE dates BETWEEN '18-05-01 07:00:00' AND '18-08-31 22:00:00' ORDER BY 3) cashiers 
        ) cashiers 
ON  sale_count.intervals = cashiers.intervals
GROUP BY cashiers.dates, cashiers.intervals, cashiers.cashier_name ORDER BY 1) metric

ORDER BY date);

SELECT * FROM hourlies LIMIT 50;

/* We can use this table to create a table where we observe how each cashier performed over time. We want the cashier names as column headers so we can 
create a metric to rate cashier performance. We do this by first, pivoting the rows and then adding columns for the total sales and cashier counts in 
each period. */

/*We will create a table which contains the features we will use in our pivot table. To do this, we need to create a temporary table which will hold the
transaction values such as the sale total and the running total over each period. We will then create a second temporary table which holds a count of the 
cashiers working in each interval. We will then join the two and have our feature table which we will pivot.
*/

CREATE TEMPORARY TABLE hourlies_temp AS
SELECT 
	date, 
    name,
    sum(total_sales) AS sale_total,
    SUM(SUM(total_sales)) OVER (PARTITION BY date) AS running_total
FROM hourlies
GROUP BY 2,1 
ORDER BY 1;

CREATE TEMPORARY TABLE cashier_temp AS 
(SELECT 
	date,
    COUNT(name) AS cashier_count 
FROM hourlies_temp 
GROUP BY 1);

CREATE TABLE features AS
(SELECT 
	h.date, 
    h.name,
    h.sale_total, 
    h.running_total, 
    c.cashier_count
FROM hourlies_temp h
JOIN cashier_temp c ON (h.date = c.date));

/*We will pivot our new features table so each cashier has their own column, the rows will contain the sale total. We will keep the running total and
cashier counts as the final columns.

When creating the pivot table we run into an issue with two similar names - Eduardo and Eduardo V, Miriam and Miriam_Landin. */

SELECT name, (CASE WHEN name LIKE 'EDUARDO %' THEN 'ED V' ELSE name END) AS name
FROM features ;

SELECT name, (CASE WHEN name LIKE 'MIRIAM %' THEN 'LANDIN' ELSE name END) AS name
FROM features;

/*To use Ed V instead of Eduardo V in our pivot table, we will create a temporary copy of our features table where we use the CASE query above to populate
the name column. We will to do the same thing for Miriam and Miriam Landin too. 
For this case we will change Miriam Landin to Landin.
*/

CREATE TEMPORARY TABLE features_temp AS
(SELECT 
	h.date, 
    (CASE WHEN name LIKE 'EDUARDO %' THEN 'ED V' ELSE name END) AS name,
    h.sale_total, 
    h.running_total, 
    c.cashier_count
FROM hourlies_temp h
JOIN cashier_temp c ON (h.date = c.date));


CREATE TEMPORARY TABLE features_temp_1 AS
(SELECT 
	h.date, 
    (CASE WHEN name LIKE 'MIRIAM %' THEN 'LANDIN' ELSE name END) AS name,
    h.sale_total, 
    h.running_total, 
    c.cashier_count
FROM features_temp h
JOIN cashier_temp c ON (h.date = c.date));

SELECT COUNT(DISTINCT cashier_name) FROM new_sales_table; 
#We have 21 distinct names in our sales table.
SELECT COUNT(DISTINCT name) FROM features_temp_1; 
#We have 21 distinct names in our temporary table.
SELECT DISTINCT name FROM features_temp_1;
#We have the changed names in our table.

#We can now create our pivot table using feature_temp_2.

CREATE TABLE cashier_pivot AS
(SELECT 
		date,
        (CASE WHEN name LIKE 'ALE DIAZ%' THEN sale_total ELSE NULL END) AS ALE_DIAZ,
        (CASE WHEN name LIKE 'ALE HUERTA%' THEN sale_total ELSE NULL END) AS ALE_HUERTA,
        (CASE WHEN name LIKE 'CLAUDIA%' THEN  sale_total ELSE NULL END) AS CLAUDIA,
		(CASE WHEN name LIKE 'EDUARDO%' THEN sale_total ELSE NULL END) AS EDUARDO,
        (CASE WHEN name LIKE 'ED V%' THEN sale_total ELSE NULL END) AS EDUARDO_V,
        (CASE WHEN name LIKE 'ELI C.%' THEN sale_total ELSE NULL END) AS ELI_C,
        (CASE WHEN name LIKE 'FERNANDO C%' THEN sale_total ELSE NULL END) AS FERNANDO_C,
        (CASE WHEN name LIKE 'GABY LUCIO%' THEN sale_total ELSE NULL END) AS GABI_LUCIO,
        (CASE WHEN name LIKE 'JANET%' THEN sale_total ELSE NULL END) AS JANET,
        (CASE WHEN name LIKE 'JAQUELINE%' THEN sale_total ELSE NULL END) AS JAQUELINE,
        (CASE WHEN name LIKE 'JESUS PEREZ%' THEN sale_total ELSE NULL END) AS JESUS_PEREZ,
        (CASE WHEN name LIKE 'JUAN MARTIN%' THEN sale_total ELSE NULL END) AS JUAN_MARTIN,
        (CASE WHEN name LIKE 'LINA%' THEN sale_total ELSE NULL END) AS LINA,
        (CASE WHEN name LIKE 'MAGO%' THEN sale_total ELSE NULL END) AS MAGO,
		(CASE WHEN name LIKE 'MARICRUZ%' THEN sale_total ELSE NULL END) AS MARICRUZ,
		(CASE WHEN name LIKE 'MAYTE%' THEN sale_total ELSE NULL END) AS MAYTE,
        (CASE WHEN name LIKE 'MIRIAM%' THEN sale_total ELSE NULL END) AS MIRIAM,
        (CASE WHEN name LIKE 'LANDIN%' THEN sale_total ELSE NULL END) AS MIRIAM_LANDIN,
        (CASE WHEN name LIKE 'MONSE L.%' THEN sale_total ELSE NULL END) AS MONSE_L,
		(CASE WHEN name LIKE 'ROSI MEJIA%' THEN sale_total ELSE NULL END) AS ROSI_MEJIA,
		(CASE WHEN name LIKE 'SARAHY%' THEN sale_total ELSE NULL END) AS SARAHY,
        running_total AS period_total,
		cashier_count AS cashiers
FROM features_temp_1);

SELECT * FROM cashier_pivot;
/*Having created our pivot table, we will now use the code to create a metric which will compare cashiers against one another.

We will look at intervals where there was more than 1 cashier working at a time. We will then calculate the average expected sales per cashier in each 
interval and subtract it from the amount each cashier actually sold in a given period.*/

SELECT 
	sale_total/running_total AS ratio,
	((sale_total/running_total) - (1/cashier_count))
FROM features_temp_1
WHERE cashier_count > 1;

/*We can use ((sale_total/running_total) - (1/cashier_count)) as our calculation to create our metric. We now recreate the pivot table above without the 
date, period and using the calculation above as our values. */

CREATE TABLE cashier_ratings AS
(SELECT date,
        (CASE WHEN name LIKE 'ALE DIAZ%' THEN ((sale_total/running_total) - (1/cashier_count)) ELSE NULL END) AS ALE_DIAZ,
        (CASE WHEN name LIKE 'ALE HUERTA%' THEN ((sale_total/running_total) - (1/cashier_count)) ELSE NULL END) AS ALE_HUERTA,
        (CASE WHEN name LIKE 'CLAUDIA%' THEN  ((sale_total/running_total) - (1/cashier_count)) ELSE NULL END) AS CLAUDIA,
		(CASE WHEN name LIKE 'EDUARDO%' THEN ((sale_total/running_total) - (1/cashier_count)) ELSE NULL END) AS EDUARDO,
        (CASE WHEN name LIKE 'ED V%' THEN ((sale_total/running_total) - (1/cashier_count)) ELSE NULL END) AS EDUARDO_V,
        (CASE WHEN name LIKE 'ELI C.%' THEN ((sale_total/running_total) - (1/cashier_count)) ELSE NULL END) AS ELI_C,
        (CASE WHEN name LIKE 'FERNANDO C%' THEN ((sale_total/running_total) - (1/cashier_count)) ELSE NULL END) AS FERNANDO_C,
        (CASE WHEN name LIKE 'GABY LUCIO%' THEN ((sale_total/running_total) - (1/cashier_count)) ELSE NULL END) AS GABI_LUCIO,
        (CASE WHEN name LIKE 'JANET%' THEN ((sale_total/running_total) - (1/cashier_count)) ELSE NULL END) AS JANET,
        (CASE WHEN name LIKE 'JAQUELINE%' THEN ((sale_total/running_total) - (1/cashier_count)) ELSE NULL END) AS JAQUELINE,
        (CASE WHEN name LIKE 'JESUS PEREZ%' THEN ((sale_total/running_total) - (1/cashier_count)) ELSE NULL END) AS JESUS_PEREZ,
        (CASE WHEN name LIKE 'JUAN MARTIN%' THEN ((sale_total/running_total) - (1/cashier_count)) ELSE NULL END) AS JUAN_MARTIN,
        (CASE WHEN name LIKE 'LINA%' THEN ((sale_total/running_total) - (1/cashier_count)) ELSE NULL END) AS LINA,
        (CASE WHEN name LIKE 'MAGO%' THEN ((sale_total/running_total) - (1/cashier_count)) ELSE NULL END) AS MAGO,
		(CASE WHEN name LIKE 'MARICRUZ%' THEN ((sale_total/running_total) - (1/cashier_count)) ELSE NULL END) AS MARICRUZ,
		(CASE WHEN name LIKE 'MAYTE%' THEN ((sale_total/running_total) - (1/cashier_count)) ELSE NULL END) AS MAYTE,
        (CASE WHEN name LIKE 'MIRIAM%' THEN ((sale_total/running_total) - (1/cashier_count)) ELSE NULL END) AS MIRIAM,
        (CASE WHEN name LIKE 'LANDIN%' THEN ((sale_total/running_total) - (1/cashier_count)) ELSE NULL END) AS MIRIAM_LANDIN,
        (CASE WHEN name LIKE 'MONSE L.%' THEN ((sale_total/running_total) - (1/cashier_count)) ELSE NULL END) AS MONSE_L,
		(CASE WHEN name LIKE 'ROSI MEJIA%' THEN ((sale_total/running_total) - (1/cashier_count)) ELSE NULL END) AS ROSI_MEJIA,
		(CASE WHEN name LIKE 'SARAHY%' THEN ((sale_total/running_total) - (1/cashier_count)) ELSE NULL END) AS SARAHY
FROM features_temp_1
WHERE cashier_count > 1);

SELECT * FROM cashier_ratings;

/*Since we have found a way to measure the performance of our workers, we will move on. We want to look at if we need to be using more cashiers at 
certain times.

We will use the entries in our features table as a sample of the original dataset to observe the number of cashiers.

Let us find the maximum number of cashiers we had working at a given time.:
*/

SELECT COUNT(*) FROM features;

#We have a total of 22764 data points in our features table.

SELECT  MAX(cashier_count) FROM features 
WHERE cashier_count = 6;

#We had a maximum of 6 cashiers working at any given time.

SELECT COUNT(*) FROM (SELECT date, MAX(cashier_count) FROM features 
WHERE cashier_count = 6 GROUP BY date) c;

/*This happened on 37 separate occasions in the features table, very rarely. Let's look at how often we had different numbers of cashiers working
together in this table:
*/

SELECT cashier_count, COUNT(cashier_count) FROM features
GROUP BY cashier_count;

/* 
1	2358
2	7546
3	8772
4	3216
5	650
6	222
*/

#We can see that the vast majority of the 22764 entries occurred when there were fewer than 4 cashiers working at a time.

SELECT
	(SELECT COUNT(cashier_count) FROM features 
	WHERE cashier_count >= 4) AS Over_4_cashiers,
    
    (SELECT COUNT(cashier_count) FROM features
    WHERE cashier_count < 4) AS Under_4_cashiers;
    
#We only had 4008 entries where we had more than 4 cashiers.
  
  SELECT
    ((SELECT COUNT(cashier_count) FROM features 
	WHERE cashier_count >= 4)/
    (SELECT COUNT(cashier_count) FROM features
    WHERE cashier_count < 4)) AS proportion_over_4;
    
/*As a proportion of our sample, 0.2189 or around 21% of our entries occurred when there were < 4 cashiers working together. 
the number of times 6 cashiers worked is around 1% of the total sample so we can conclude that we don't need more cashiers. The number we have working 
right now seems sufficient to maintain business. */

/*So far, we have:

1. Imported and restructured our data.
2. Conducted some introductory analysis to observe sales trends over different timeframes.
3. Explored the first day in our dataset.
4. Created a Procedure which produces a daily report observing several metrics. 
5. Looked at the scale of transactions and if large transactions would significantly alter our dataset.
6. Created a table containing a set of features from which we could analyse cashier performance.
7. Created a metric to compare cashiers with one another.
8. Looked at if we needed to hire more cashiers to deal with busy periods.

We will now use the queries we made here to extract data and make visualisations using Tableau.

*/

#Queries to extract the data we want:

#Sales by size:

SELECT sale_total, COUNT(sale_total) FROM new_sales_table
WHERE sale_total > 0
GROUP BY sale_total
ORDER BY 2;


#Sales per cashier over time:

SELECT dates, sale_total, cashier_name FROM new_sales_table
WHERE sale_total > 0
GROUP BY sale_total;

SELECT LEFT(date,10), intervals, total_sales, name FROM hourlies
WHERE total_sales > 0
GROUP BY total_sales;

#Cashier Ratings:

SELECT * FROM cashier_ratings;

#Transaction figures:
SELECT * FROM features;

#Sale count by cashier:

SELECT cashier_name, count(*) FROM new_sales_table
GROUP BY cashier_name ORDER BY 2 DESC;


