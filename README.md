# Adashi_SQL_Assessment

## Overview  
This repo contains my answers to the Adashi_staging SQL proficiency assessment. 

---

## Breakdown by Question

### Question 1 – Customers with both Savings and Investment Plans  
- Filtered deposits with confirmed amounts greater than 0.  
- Counted how many savings and investment plans each customer has.  
- Selected only customers with at least one of each type.  
- Joined with user data and sorted by total deposits in Naira.

### Question 2 – Categorizing Customers by Transaction Frequency  
- Pulled transaction dates for each user.  
- Calculated how many months they’ve been active.  
- Computed average transactions per month.  
- Grouped them into High, Medium, or Low frequency based on the result.

### Question 3 – Finding Inactive Plans  
- Found each user’s most recent deposit date.  
- Linked that to their active savings or investment plans.  
- Measured inactivity by days since the last transaction.  
- Filtered for anything inactive for over a year or with no transaction history.

### Question 4 – Estimating Customer Lifetime Value (CLV)  
- Calculated how long each user has been active (in months).  
- Counted their transactions and average confirmed deposit amount.  
- Results are sorted from highest to lowest estimated CLV.

---

## Notes  
- I cleaned the data where necessary during each query (e.g., filtered out nulls or invalid records), but I didn’t do general data cleaning like removing duplicates or permanently deleting nulls.  





