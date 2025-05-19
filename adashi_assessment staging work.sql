-- Preview data
SELECT * FROM users_customuser;
SELECT * FROM plans_plan;
SELECT * FROM savings_savingsaccount;
SELECT * FROM withdrawals_withdrawal;

-- Checking missing owner_id in plans
SELECT COUNT(*) FROM plans_plan WHERE owner_id IS NULL;

-- Checking missing values in savings
SELECT COUNT(*) FROM savings_savingsaccount WHERE owner_id IS NULL;
SELECT COUNT(*) FROM savings_savingsaccount WHERE plan_id IS NULL;

-- Checking deposits with zero or negative values in dataset
SELECT COUNT(*) FROM savings_savingsaccount WHERE confirmed_amount <= 0;

-- Checking withdrawals with zero or negative values in dataset
SELECT COUNT(*) FROM withdrawals_withdrawal WHERE amount_withdrawn <= 0;



-- Question 1. -- Question 1: Calculate total deposits for customers who have both savings and investment plans.

WITH clean_savings AS (
  SELECT owner_id, confirmed_amount
  FROM savings_savingsaccount
  WHERE confirmed_amount > 0            -- Filter confirmed deposits greater than zero.
),
savings_total AS (
  SELECT owner_id, SUM(confirmed_amount) AS total_deposits
  FROM clean_savings
  GROUP BY owner_id
),
plan_summary AS (
  SELECT owner_id,                  -- Sum deposits grouped by owner_id.
         SUM(CASE WHEN is_regular_savings = 1 THEN 1 ELSE 0 END) AS savings_count, 
         SUM(CASE WHEN is_a_fund = 1 THEN 1 ELSE 0 END) AS investment_count
  FROM plans_plan
  GROUP BY owner_id
),
eligible_customers AS (
  SELECT p.owner_id, p.savings_count, p.investment_count, s.total_deposits
  FROM plan_summary p
  JOIN savings_total s ON p.owner_id = s.owner_id         -- Aggregate plans by owner_id to count how many savings and investment plans each customer has.
  WHERE p.savings_count >= 1 AND p.investment_count >= 1
)
SELECT e.owner_id, u.name, e.savings_count, e.investment_count, ROUND(e.total_deposits / 100, 2) AS total_deposits_naira
FROM eligible_customers e
INNER JOIN users_customuser u ON e.owner_id = u.id
ORDER BY total_deposits_naira DESC;
	SELECT 
    u.name AS user_name,
    s.id AS plan_id,
    COUNT(w.id) AS total_withdrawals
FROM savings_savingsaccount s         -- Join aggregated deposits and plans, filtering for customers with at least one savings and one investment plan.
JOIN users_customuser u ON s.owner_id = u.id
JOIN savings_savingswithdrawal w ON s.id = w.plan_id
WHERE s.status = 'active'
GROUP BY u.name, s.id
HAVING COUNT(w.id) >= 1
ORDER BY total_withdrawals DESC; -- Retrieve customer names and order by total deposits in descending order.



-- Question 2: Categorize customers by average monthly transaction frequency.

WITH cleaned_data AS (
    SELECT
        owner_id,
        DATE(created_on) AS txn_date
    FROM
        savings_savingsaccount
    WHERE
        owner_id IS NOT NULL
        AND TRIM(CAST(owner_id AS CHAR)) <> ''
        AND created_on IS NOT NULL      -- Extracting transaction dates from savings accounts with valid owner_id and created_on.
),
txn_summary AS (
    SELECT
        owner_id,
        COUNT(*) AS total_txns,
        MIN(txn_date) AS first_txn,
        MAX(txn_date) AS last_txn,
        ((YEAR(MAX(txn_date)) - YEAR(MIN(txn_date))) * 12 +
         (MONTH(MAX(txn_date)) - MONTH(MIN(txn_date))) + 1) AS active_months
    FROM
        cleaned_data
    GROUP BY
        owner_id
),            -- Calculate the active months between first and last transaction per customer.
categorized AS (
    SELECT
        owner_id,
        total_txns,
        active_months,
        ROUND(total_txns / NULLIF(active_months, 0), 2) AS avg_txn_per_month,
        CASE
            WHEN total_txns / NULLIF(active_months, 0) >= 10 THEN 'High Frequency'
            WHEN total_txns / NULLIF(active_months, 0) BETWEEN 3 AND 9 THEN 'Medium Frequency'
            ELSE 'Low Frequency'
        END AS frequency_category
    FROM txn_summary
)
SELECT   
    frequency_category,
    COUNT(owner_id) AS customer_count,
    ROUND(AVG(avg_txn_per_month), 2) AS avg_transactions_per_month    -- Average transactions per month.
FROM categorized
GROUP BY frequency_category
ORDER BY
    CASE frequency_category   -- Classifying customers into 'High', 'Medium', or 'Low' frequency based on avg transactions.
        WHEN 'High Frequency' THEN 1
        WHEN 'Medium Frequency' THEN 2
        WHEN 'Low Frequency' THEN 3
    END;               --  Results of customers in each frequency category and their average monthly transactions.


    

-- Question 3.  Identify plans inactive for more than one year.

WITH recent_transactions AS (
    SELECT 
        owner_id,
        MAX(STR_TO_DATE(transaction_date, '%Y-%m-%d')) AS last_transaction_date
    FROM savings_savingsaccount
    WHERE confirmed_amount > 0
      AND transaction_date IS NOT NULL
      AND transaction_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
    GROUP BY owner_id              
),						-- Identifying the last confirmed transaction date per customer.

active_plans AS (
    SELECT 
        id AS plan_id,
        owner_id,
        CASE 
            WHEN is_regular_savings = 1 THEN 'Savings'
            WHEN is_a_fund = 1 THEN 'Investment'
            ELSE 'Other'
        END AS type
    FROM plans_plan
    WHERE is_regular_savings = 1 OR is_a_fund = 1
),                           -- Identifying the active plans (either savings or investment).

inactivity_check AS (
    SELECT 
        ap.plan_id,
        ap.owner_id,
        ap.type,
        rt.last_transaction_date,
        DATEDIFF(CURDATE(), rt.last_transaction_date) AS inactivity_days
    FROM active_plans ap
    LEFT JOIN recent_transactions rt ON ap.owner_id = rt.owner_id
) 						-- Joining the last transaction date to plans and calculate days of inactivity.

SELECT 
    plan_id,
    owner_id,
    type,
    last_transaction_date,
    inactivity_days
FROM inactivity_check
WHERE inactivity_days > 365
   OR last_transaction_date IS NULL
ORDER BY inactivity_days DESC;			-- Selecting the plans with inactivity over 365 days or with no recorded transactions.

-- Question 4: Estimate Customer Lifetime Value (CLV).

SELECT       --  Calculating customer tenure in months since joining.
    u.id AS customer_id,
    CONCAT(u.first_name, ' ', u.last_name) AS name,
    FLOOR(DATEDIFF(CURRENT_DATE, u.date_joined) / 30) AS tenure_months,
    COUNT(DISTINCT s.id) AS total_transactions,
    
    ROUND(
        (COUNT(DISTINCT s.id) / NULLIF(FLOOR(DATEDIFF(CURRENT_DATE, u.date_joined) / 30), 0))   -- Counting distinct transactions and average confirmed amount per customer.
        * 12 
        * (0.001 * AVG(s.confirmed_amount) / 100), 2
    ) AS estimated_clv

FROM 
    users_customuser u
LEFT JOIN 
    savings_savingsaccount s 
    ON u.id = s.owner_id
    AND s.confirmed_amount IS NOT NULL
    AND s.confirmed_amount != 0
    AND s.transaction_date IS NOT NULL  -- Checking transactions frequency and average amount to estimate CLV.

WHERE
    u.id IS NOT NULL
    AND u.date_joined IS NOT NULL
    AND u.first_name IS NOT NULL AND u.first_name != ''
    AND u.last_name IS NOT NULL AND u.last_name != ''   			-- Joining customer names and order by estimated CLV descending. 

GROUP BY 
    u.id, u.first_name, u.last_name, u.date_joined

ORDER BY 
    estimated_clv DESC;


