Find the names and emails of all contacts who successfully launched a campaign in the "music" category, and the name of the company involved.

SELECT 
    s.first_name,
    s.last_name,
    s.email,
    s.company_name,
    cat.category AS category_name,
    s.pledged,
    s.outcome
FROM 
    `etl-use-case-486109.silver.campaign_contact_master` AS s
JOIN 
    `etl-use-case-486109.landing.category` AS cat
ON 
    s.category_id = cat.category
WHERE 
    s.outcome = 'successful' 
    AND LOWER(cat.category) = 'music'
List all subcategories and their corresponding categories, showing the total number of campaigns in each subcategory. Order by the number of campaigns (descending).
SELECT 
    cat.category AS category_name,
    sub.subcategory AS subcategory_name,
    COUNT(s.cf_id) AS total_campaigns
FROM 
    `etl-use-case-486109.silver.campaign_contact_master` AS s
JOIN 
    `etl-use-case-486109.landing.subcategory` AS sub
ON 
    s.subcategory_id = sub.subcategory
JOIN 
    `etl-use-case-486109.landing.category` AS cat
ON 
    s.category_id = cat.category
GROUP BY 
    1, 2
ORDER BY 
    total_campaigns DESC
Show the company names and descriptions of campaigns that raised more than the average pledged amount for their respective categories.
WITH CategoryAverages AS (
    SELECT 
        company_name,
        description,
        category_id,
        pledged,
        -- Calculate the average pledged for the category this row belongs to
        AVG(pledged) OVER(PARTITION BY category_id) AS category_avg_pledged
    FROM 
        `etl-use-case-486109.silver.campaign_contact_master`
)
SELECT 
    company_name,
    description,
    pledged,
    ROUND(category_avg_pledged, 2) AS category_avg
FROM 
    CategoryAverages
WHERE 
    pledged > category_avg_pledged
Retrieve contact information for contacts who havent launched any campaigns, and indicate how many contacts this represents.
WITH InactiveIDs AS (
    SELECT contact_id FROM `etl-use-case-486109.landing.contacts`
    EXCEPT DISTINCT
    SELECT contact_id FROM `etl-use-case-486109.silver.campaign_contact_master`
)
SELECT 
    c.first_name,
    c.last_name,
    c.email,
    -- Add the total representation count
    (SELECT COUNT(*) FROM InactiveIDs) AS total_inactive_contacts
FROM 
    `etl-use-case-486109.landing.contacts` AS c
JOIN 
    InactiveIDs AS i ON c.contact_id = i.contact_id


What are the top 5 countries with the highest average pledged amount per campaign?
SELECT 
    country, 
    ROUND(AVG(pledged), 2) AS avg_pledged_amount,
    COUNT(cf_id) AS total_campaigns
FROM 
    `etl-use-case-486109.silver.campaign_contact_master`
GROUP BY 
    country
ORDER BY 
    avg_pledged_amount DESC
LIMIT 5
Find the category with the lowest average pledged amount relative to its goal (pledged/goal).
SELECT 
    category_id, 
    -- Calculate the average of individual campaign ratios
    ROUND(AVG(SAFE_DIVIDE(pledged, goal)), 4) AS avg_funding_ratio,
    COUNT(*) AS project_count
FROM 
    `etl-use-case-486109.silver.campaign_contact_master`
GROUP BY 
    category_id
ORDER BY 
    avg_funding_ratio ASC
LIMIT 1
List all campaigns launched in the first half of 2020 that were ultimately successful.
SELECT 
    cf_id,
    company_name,
    description,
    goal,
    pledged,
    outcome,
    launched_date,
    end_date,
    country,
    currency
FROM 
    `etl-use-case-486109.silver.campaign_contact_master`
WHERE 
    outcome = 'successful'
    AND launched_date BETWEEN '2020-01-01' AND '2020-06-30'
ORDER BY 
    launched_date ASC
For each subcategory, calculate the success rate (successful campaigns / total campaigns) and display only those subcategories with a success rate below 25%.
WITH sub_calculations AS (
    SELECT 
        s.subcategory,
        COUNT(c.cf_id) AS total_campaigns,
        COUNTIF(c.outcome = 'successful') AS successful_campaigns
    FROM 
        `etl-use-case-486109.silver.campaign_contact_master` AS c
    -- Joining with landing because that's where your subcategory names are stored
    INNER JOIN 
        `etl-use-case-486109.landing.subcategory` AS s ON c.subcategory_id = s.subcategory_id
    GROUP BY 
        1
)
SELECT 
    subcategory,
    total_campaigns,
    successful_campaigns,
    ROUND(SAFE_DIVIDE(successful_campaigns, total_campaigns), 4) AS success_rate
FROM 
    sub_calculations
WHERE 
    SAFE_DIVIDE(successful_campaigns, total_campaigns) < 0.25
ORDER BY 
    success_rate ASC
Identify campaigns where the pledged amount exceeded the goal by more than 20%. Include the percentage difference.
SELECT 
    cf_id,
    company_name,
    goal,
    pledged,
    -- Calculate the percentage difference: (Pledged - Goal) / Goal
    ROUND(((pledged - goal) / goal) * 100, 2) AS percentage_over_goal
FROM 
    `etl-use-case-486109.silver.campaign_contact_master`
WHERE 
    -- Filter for campaigns where pledged is > 120% of the goal
    pledged > (goal * 1.2)
ORDER BY 
    percentage_over_goal DESC
Find the average number of backers for campaigns in each currency, only considering campaigns that reached their goal.
SELECT 
    currency,
    ROUND(AVG(backers_count), 0) AS average_backers,
    COUNT(cf_id) AS total_successful_campaigns
FROM 
    `etl-use-case-486109.silver.campaign_contact_master`
WHERE 
    outcome = 'successful'
GROUP BY 
    currency
ORDER BY 
    average_backers DESC
Identify the top 3 contacts who have the highest total pledged amount across all their campaigns, along with their success rate (successful campaigns / total campaigns). The output should include contact name and both total pledged and success rate.
WITH contact_aggregates AS (
    SELECT 
        contact_id,
        SUM(pledged) AS total_amount_pledged,
        COUNT(cf_id) AS total_campaigns,
        COUNTIF(outcome = 'successful') AS successful_campaigns
    FROM 
        `etl-use-case-486109.silver.campaign_contact_master`
    GROUP BY 
        contact_id
)
SELECT 
    CONCAT(c.first_name, ' ', c.last_name) AS contact_full_name,
    a.total_amount_pledged,
    ROUND(SAFE_DIVIDE(a.successful_campaigns, a.total_campaigns), 4) AS success_rate
FROM 
    contact_aggregates AS a
JOIN 
    `etl-use-case-486109.landing.contacts` AS c ON a.contact_id = c.contact_id
ORDER BY 
    a.total_amount_pledged DESC
LIMIT 3
Find all categories where the average pledged amount for failed campaigns is greater than the average pledged amount for successful campaigns within that same category.
WITH category_averages AS (
    SELECT 
        category_id,
        AVG(IF(outcome = 'successful', pledged, NULL)) AS avg_pledge_successful,
        AVG(IF(outcome = 'failed', pledged, NULL)) AS avg_pledge_failed
    FROM 
        `etl-use-case-486109.silver.campaign_contact_master`
    GROUP BY 
        category_id
)
SELECT 
    cat.category,
    ROUND(avg_pledge_successful, 2) AS avg_pledge_successful,
    ROUND(avg_pledge_failed, 2) AS avg_pledge_failed,
    ROUND(avg_pledge_failed - avg_pledge_successful, 2) AS difference
FROM 
    category_averages AS m
JOIN 
    `etl-use-case-486109.landing.category` AS cat ON m.category_id = cat.category
WHERE 
    m.avg_pledge_failed > m.avg_pledge_successful
For each country, determine the percentage of campaigns that were successful, failed, or canceled.
WITH country_counts AS (
    SELECT 
        country,
        COUNT(cf_id) AS total_campaigns,
        COUNTIF(outcome = 'successful') AS successful_count,
        COUNTIF(outcome = 'failed') AS failed_count,
        COUNTIF(outcome = 'canceled') AS canceled_count,
        COUNTIF(outcome = 'live') AS live_count
    FROM 
        `etl-use-case-486109.silver.campaign_contact_master`
    GROUP BY 
        country
)
SELECT 
    country,
    total_campaigns,
    ROUND(SAFE_DIVIDE(successful_count, total_campaigns) * 100, 2) AS percent_successful,
    ROUND(SAFE_DIVIDE(failed_count, total_campaigns) * 100, 2) AS percent_failed,
    ROUND(SAFE_DIVIDE(canceled_count, total_campaigns) * 100, 2) AS percent_canceled,
    ROUND(SAFE_DIVIDE(live_count, total_campaigns) * 100, 2) AS percent_live
FROM 
    country_counts
ORDER BY 
    percent_successful DESC
Find the company that had the highest number of campaigns within a single category. Show the company name and the category.
SELECT 
    c.company_name,
    cat.category,
    COUNT(c.cf_id) AS campaign_count
FROM 
    `etl-use-case-486109.silver.campaign_contact_master` AS c
JOIN 
    `etl-use-case-486109.landing.category` AS cat ON c.category_id = cat.category
GROUP BY 
    c.company_name, 
    cat.category
ORDER BY 
    campaign_count DESC
List all contacts who launched campaigns in more than one category. For each contact, show their name and a comma-separated list of the categories in which they have campaigns. 
WITH contact_categories AS (
    SELECT 
        c.contact_id,
        CONCAT(con.first_name, ' ', con.last_name) AS contact_name,
        cat.category
    FROM 
        `etl-use-case-486109.silver.campaign_contact_master` AS c
    JOIN 
        `etl-use-case-486109.landing.contacts` AS con ON c.contact_id = con.contact_id
    JOIN 
        `etl-use-case-486109.landing.category` AS cat ON c.category_id = cat.category_id
    GROUP BY 
        1, 2, 3 -- Get unique pairs of Contact + Category
)
SELECT 
    contact_name,
    STRING_AGG(category, ', ' ORDER BY category ASC) AS category_list,
    COUNT(category) AS category_count
FROM 
    contact_categories
GROUP BY 
    contact_name
HAVING 
    category_count > 1
ORDER BY 
    category_count DESC


--silver table creation
CREATE OR REPLACE TABLE `etl-use-case-486109.silver.analytics_silver` AS
SELECT
  cf_id,
  contact_id,
  -- Cleaning strings with placeholders
  COALESCE(company_name, 'No Company Provided') AS company_name,
  COALESCE(description, 'No Description Provided') AS description,
  outcome,
   COALESCE(country, 'No country Provided') as country,
   COALESCE(currency, 'No currency Provided') as currency,
  COALESCE(category, 'cat_missing') AS category_id,
  COALESCE(subcategory, 'subcat_missing') AS subcategory_id,
  
  -- Imputing missing numbers using averages from the Python-generated table
  COALESCE(goal, (SELECT AVG(goal) FROM `etl-use-case-486109.landing.final_analytics`)) AS goal,
  COALESCE(pledged, (SELECT AVG(pledged) FROM `etl-use-case-486109.landing.final_analytics`)) AS pledged,
  COALESCE(backers_count, CAST((SELECT AVG(backers_count) FROM `etl-use-case-486109.landing.final_analytics`) AS INT64)) AS backers_count,

  -- Preserving original dates
  launch_date as launched_date,
  end_date
FROM `etl-use-case-486109.landing.final_analytics`;


--campaign master
CREATE OR REPLACE TABLE `etl-use-case-486109.silver.campaign_contact_master` AS
SELECT 
    -- IDs
    s.cf_id,
    s.contact_id,

    -- Contact Information
    c.first_name,
    c.last_name,
    c.email,

    -- Campaign Details
    s.company_name,
    s.description,
    s.outcome,
    s.country,
    s.currency,
    s.category_id,
    s.subcategory_id,

    -- Financial Metrics
    s.goal,
    s.pledged,
    s.backers_count,
    

    -- Date Formatting
    CAST(s.launched_date AS DATE) AS launched_date,
    CAST(s.end_date AS DATE) AS end_date

FROM 
    `etl-use-case-486109.silver.analytics_silver` AS s
LEFT JOIN 
    `etl-use-case-486109.landing.contacts` AS c
ON 
    s.contact_id = c.contact_id;


---landing tables
-- Create the dataset first (manually or via SQL)


CREATE OR REPLACE TABLE `landing.category` (
    category_id STRING,
    category STRING
);

CREATE OR REPLACE TABLE `landing.subcategory` (
    subcategory_id STRING,
    subcategory STRING
);

CREATE OR REPLACE TABLE `landing.contacts` (
    contact_id INT64,
    first_name STRING,
    last_name STRING,
    email STRING
);

CREATE OR REPLACE TABLE `landing.campaign` (
    cf_id INT64,
    contact_id INT64,
    company_name STRING,
    description STRING,
    goal FLOAT64,
    pledged FLOAT64,
    outcome STRING,
    backers_count INT64,
    country STRING,
    currency STRING,
    launched_date DATE,
    end_date DATE,
    category_id STRING,
    subcategory_id STRING
);

--Q4 verifier
SELECT 
    (SELECT COUNT(DISTINCT contact_id) FROM `etl-use-case-486109.landing.contacts`) as total_contacts,
    (SELECT COUNT(DISTINCT contact_id) FROM `etl-use-case-486109.silver.campaign_contact_master`) as contacts_with_campaigns,
    (SELECT COUNT(DISTINCT c.contact_id) 
     FROM `etl-use-case-486109.landing.contacts` c
     INNER JOIN `etl-use-case-486109.silver.campaign_contact_master` s ON c.contact_id = s.contact_id) as overlapping_contacts;

     --this query means that both the tables are perfectly synced

--Q8 verifier
SELECT 
    s.subcategory,
    COUNT(c.cf_id) AS total_campaigns,
    ROUND(AVG(CASE WHEN c.outcome = 'successful' THEN 1 ELSE 0 END), 4) AS actual_rate
FROM 
    `etl-use-case-486109.silver.campaign_contact_master` AS c
JOIN 
    `etl-use-case-486109.landing.subcategory` AS s ON c.subcategory_id = s.subcategory
GROUP BY 1
ORDER BY actual_rate ASC;
-- this query runs and first row gives 0.3077 it means that the Q8 data is empty bcs data has successful campaigns  

--Q15 verifier
SELECT 
    contact_id, 
    COUNT(DISTINCT category_id) as unique_cats
FROM 
    `etl-use-case-486109.silver.campaign_contact_master`
GROUP BY 1
ORDER BY 2 DESC;
--this proves that no contact has merged out yet as the highest is still 1

