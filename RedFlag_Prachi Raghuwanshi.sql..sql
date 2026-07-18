                                                   -- RedFlag--
												-- The Fraud Files--
-- ====================================================================================================================================================================================
-- =====================================================================
-- RedFlag — Fraud Detection 
-- Student: Prachi Raghuwanshi
-- Batch: Data analytics
-- =====================================================================
USE redflag;
-- =======================================================================================================================================================================================
--  The 12 Fraud Patterns
-- ====================================================================================================================================================================================
-- TIER 1
-- P1 · Velocity Fraud
-- ====================
/*
 The pattern: A legitimate user makes 3-8 transactions per day on their busiest days. A fraudster running an automated script can make 30+ in a single day.
 Anyone hitting that count is either a bot, an account  takeover, or a merchant running a churning scheme. */
 
 SELECT
    user_id ,
	DATE(  txn_time ) AS  transactions_date,
	COUNT(*) AS total_transactions
FROM transactions
GROUP BY  
    user_id ,
	DATE(  txn_time )   
HAVING COUNT(*) >= 30
 ORDER BY
	 total_transactions DESC,
     transactions_date;
     
-- My findings:
-- 50 suspect user-days were identified.
-- User 14569 recorded the highest activity with 60 transactions on 2024-04-03.
-- This pattern suggests possible bot activity or an account takeover that requires further investigation. 
    
 -- ==========================================================================================================
 -- P2 · Round-Amount Clustering
 -- =============================
/*The pattern: Money launderers prefer round-number amounts (₹100, ₹500, ₹1,000, ₹5,000, ₹10,000).
Real e-commerce and food-delivery transactions rarely produce clean round numbers because prices
include taxes, delivery fees, and discounts. A user with 15+ exactly-round transactions is showing
money-laundering signature .*/

SELECT 
     user_id ,
       COUNT(*) AS round_amount_transactions
 FROM transactions
 WHERE amount IN (100,200,500,1000,2000,5000,10000)
 GROUP BY  user_id
 HAVING  COUNT(*)  >= 15
 ORDER BY 
      round_amount_transactions DESC;
      
-- My findings:
-- 25 users were identified with 15 or more round-value transactions.
-- User 14533 recorded the highest number of suspicious round transactions.
-- This behavior may indicate money laundering through repeated round-amount payments

 -- ==========================================================================================================
-- P3 · Card Testing
-- ===================
/*The pattern: Fraudsters buy dumps of stolen credit card numbers on the dark web. They test which
cards are still active by attempting tiny purchases (under ₹10). If the purchase goes through, the card is
still valid and the fraudster keeps it for a bigger operation. If it fails, they move to the next card. This is
one of the most common frauds detected by real card networks. */

SELECT
    user_id ,
	DATE(  txn_time ) AS  transactions_date,
	COUNT(*) AS  small_transactions
FROM transactions
WHERE amount < 10
GROUP BY  
    user_id ,
	DATE(  txn_time )  
HAVING COUNT(*) >= 30
 ORDER BY
	  small_transactions DESC,
     transactions_date;

-- My findings:
-- Total suspects found: 20
-- User 14569 performed 60  transactions below ₹10 in a single day.
-- This pattern indicates possible card-testing activity using small-value transactions.     
     
-- ==========================================================================================================
-- P4 · Failed-Then-Succeeded
-- ===========================
/*The pattern: Same card-testing behaviour as P3, but the specific signature this time is many FAILED
transactions followed by SUCCESS ones. Fraudsters retry until they find a card/CVV combination that
clears. Real users rarely have more than 2-3 failed transactions in an entire year. Users with 20+ failures
are running scripts. */

SELECT
    user_id ,
	COUNT(*) AS  Failed_transactions
FROM transactions
WHERE status = 'Failed'
 GROUP BY  user_id
 HAVING  COUNT(*)  >= 20
  ORDER BY
	  Failed_transactions DESC;
      
-- My findings:
-- Total suspects found: 25.
-- User 14595 recorded 35 failed transactions.
-- A high number of failed transactions may indicate repeated attempts to validate stolen card details.

 -- ==========================================================================================================
 -- P5 · Odd-Hour Concentration
 -- =============================
 /*The pattern: Real Indian users transact between 8 AM and 11 PM. Automated fraud scripts often run in
the 2 AM - 5 AM window (which is business hours in North American timezones - many card-cracking
rings operate from Eastern Europe and the Americas). A user with the vast majority of their activity in
this window is exhibiting bot signature.*/

SELECT
    user_id,
    COUNT(*) AS total_transactions,
    SUM(
        CASE
            WHEN HOUR(txn_time) BETWEEN 2 AND 4
            THEN 1
            ELSE 0
        END
    ) AS odd_hour_transactions
FROM transactions
GROUP BY user_id
HAVING COUNT(*) >= 30
   AND SUM(
        CASE
            WHEN HOUR(txn_time) BETWEEN 2 AND 4
            THEN 1
            ELSE 0
        END
    ) / COUNT(*) >= 0.80
ORDER BY odd_hour_transactions DESC;

-- My findings:
-- Total suspects found: 20.
-- User 14608 had over 80% of transactions between 2 AM and 5 AM.
-- This unusual activity may indicate automated fraud or bot-driven transactions.

-- ==================================================================================================================================================================================
-- TIER - 2
-- P6 · Mule Accounts
-- =====================
/*The pattern: Mule accounts are the human ATMs of the fraud world. A fraudster deposits stolen funds
into a mule's account, then quickly withdraws or transfers them elsewhere. The mule keeps a small
commission. Behaviour signature: large CREDIT transactions (money coming in via NETBANKING)
immediately followed by DEBIT transactions (money going out via UPI) within 30 minutes.*/

SELECT 
         user_id,
		COUNT(*)AS  credit_transactions
FROM transactions
WHERE   txn_type = 'CREDIT'
 GROUP BY user_id
 HAVING COUNT(*) >= 8
 ORDER BY 
    credit_transactions DESC;
    
-- My findings:
-- Total suspects found: 30 .
--  Highest CREDIT transaction by  User 14630 showed repeated CREDIT transactions followed by suspicious fund movement.
-- This behavior is consistent with possible mule account activity used for money laundering.

-- ==================================================================================================================================
-- P7 · Refund Abuse
-- =====================
/*The pattern: Real users have refund rates below 5%. Fraudsters running chargeback schemes or
exploiting merchant loopholes have refund rates above 40%. The signature is a user with many
transactions where a disproportionate share are refunds.*/

SELECT
    user_id,
    COUNT(*) AS total_transactions,
SUM(
   case 
        WHEN txn_type = 'REFUND'
		THEN  1 
		ELSE  0
   END
)AS refund_transactions
FROM transactions 
GROUP BY user_id
HAVING 
COUNT(*) >= 20
AND
SUM(CASE
        WHEN txn_type='REFUND'
        THEN 1 
        ELSE 0
   END
)/ COUNT(*) > 0.40
ORDER BY 
   refund_transactions DESC;
   
-- My findings:
-- Total suspects found: 24.
-- User 14657 had a refund ratio greater than 40% with at least 20 transactions.
-- This pattern may indicate refund fraud or abuse of merchant refund policies. 
 
-- ==================================================================================================================================
-- P8 · Merchant Collusion
-- ========================
/*The pattern: Legitimate merchants have long tails of customers - thousands of users each contributing
small amounts to the merchant's total volume. A merchant where 3-4 users generate the majority of
volume is either a very niche B2B business (rare on retail platforms) or is colluding with those users to
launder money.*/

WITH user_spending AS (
SELECT    merchant_id, 
          user_id, 
         SUM(amount)AS user_total
FROM transactions
GROUP BY    merchant_id,user_id
),

ranked_users AS (
    SELECT
        merchant_id,
        user_id,
        user_total,
        ROW_NUMBER() OVER (
            PARTITION BY merchant_id
            ORDER BY user_total DESC
        ) AS rn
    FROM user_spending
),    

top5 AS (
    SELECT
        merchant_id,
        SUM(user_total) AS top5_total
    FROM ranked_users
    WHERE rn <= 5
    GROUP BY merchant_id
),

merchant_total AS (
    SELECT
        merchant_id,
        SUM(amount) AS merchant_total
    FROM transactions
    GROUP BY merchant_id
)

SELECT
    m.merchant_id,
    m.merchant_total,
    t.top5_total,
    ROUND(t.top5_total / m.merchant_total,2) AS concentration_ratio
FROM merchant_total m
JOIN top5 t
ON m.merchant_id=t.merchant_id
WHERE t.top5_total/m.merchant_total>0.60
ORDER BY concentration_ratio DESC;    

-- My findings:
-- Total suspicious merchants found: 15.
-- Merchant 1 had more than 60% of its transaction value generated by its top 5 users.
-- This concentration may indicate possible collusion or money-laundering activity.

-- ==================================================================================================================================
-- P9 · Just-Under-Threshold (Structuring)
-- ==========================================
/*The pattern: Indian banking regulations require enhanced KYC checks on transactions of ₹10,000 or
above. Fraudsters running structuring / smurfing schemes deliberately keep transactions at exactly
₹9,999 to avoid these checks. This is one of the most classic anti-money-laundering patterns and is
illegal even without any other fraud.*/

SELECT
    user_id,
    COUNT(*) AS structuring_transactions
FROM transactions
WHERE amount = 9999.00
GROUP BY user_id
HAVING COUNT(*) >= 10
ORDER BY structuring_transactions DESC;

-- My findings:
-- 20 users were flagged for making 10 or more transactions of exactly ₹9,999.
-- These transactions may indicate structuring to avoid the ₹10,000 reporting threshold.

-- ==================================================================================================================================
-- P10 · Dormant-Then-Active
-- ===========================
/*The pattern: An account that was completely inactive for 90+ days and then suddenly bursts with 15+
transactions in a short window is the signature of account takeover. The fraudster has gained access to a
dormant account (via a phishing attack, credential leak, or SIM swap) and is monetising it before the real
owner notices.*/

WITH user_activity AS (
    SELECT
        user_id,
        txn_time,
        LAG(txn_time) OVER (
            PARTITION BY user_id
            ORDER BY txn_time
        ) AS previous_txn
    FROM transactions
),

gaps AS (
    SELECT
        user_id,
        txn_time AS restart_time
    FROM user_activity
    WHERE DATEDIFF(txn_time, previous_txn) >= 90
)

SELECT
    g.user_id,
    COUNT(*) AS transactions_after_gap
FROM gaps g
JOIN transactions t
    ON g.user_id = t.user_id
   AND t.txn_time >= g.restart_time
GROUP BY g.user_id
HAVING COUNT(*) >= 15
ORDER BY transactions_after_gap DESC;

-- My findings:
-- Total suspects found: 26.
-- User 14526 became active after an inactivity period of 90+ days and performed 55  transactions after the gap.
-- This behavior may indicate a dormant account takeover or unauthorized account access.

-- =================================================================================================================================================================================
-- TIER - 3
-- P11 · Velocity Spike
-- =========================
 /*The pattern: A user's transaction rate suddenly spikes to many multiples of their historical average. This
is the ML-free equivalent of anomaly detection - even without training a model, you can identify
accounts whose behaviour changed abruptly. Almost always indicates account takeover.*/

WITH monthly_counts AS
(
    SELECT
        user_id,
        DATE_FORMAT(txn_time,'%Y-%m') AS month,
        COUNT(*) AS monthly_transactions
    FROM transactions
    GROUP BY
        user_id,
        DATE_FORMAT(txn_time,'%Y-%m')
)
SELECT
    user_id,
    AVG(monthly_transactions) AS average_monthly_transactions,
    MAX(monthly_transactions) AS peak_monthly_transactions,
    ROUND(
        MAX(monthly_transactions) /
        AVG(monthly_transactions),
        2
    ) AS spike_ratio
FROM monthly_counts
GROUP BY user_id
HAVING
    MAX(monthly_transactions) >= 20
    AND
    MAX(monthly_transactions) /
    AVG(monthly_transactions) >= 5
ORDER BY spike_ratio DESC;

-- My findings:
-- Total suspects found: 3.
-- User 14517 recorded a peak monthly transaction count of 41 with a spike ratio of 5.13.
-- This sudden increase in transaction activity may indicate abnormal behavior or possible account compromise.

-- ===============================================================================================================================
-- P12 · Geographic Impossibility
-- ===============================
/*The pattern: The same user transacts in two different Indian cities within 60 minutes. Physically
impossible unless the account is being used simultaneously by two different people. Almost always
indicates account takeover or stolen-card usage across a syndicate.*/

WITH transaction_history AS
(
    SELECT
        user_id,
        city,
        txn_time,
        LAG(city) OVER
        (
            PARTITION BY user_id
            ORDER BY txn_time
        ) AS previous_city,
        LAG(txn_time) OVER
        (
            PARTITION BY user_id
            ORDER BY txn_time
        ) AS previous_time
    FROM transactions
)
SELECT DISTINCT
    user_id
FROM transaction_history
WHERE
    previous_city IS NOT NULL
    AND city <> previous_city
    AND TIMESTAMPDIFF(
        MINUTE,
        previous_time,
        txn_time
    ) <= 60
ORDER BY user_id;

-- My findings:
-- 15 users were identified with transactions from different cities within 60 minutes.
-- This behavior is physically unlikely and may indicate account takeover or stolen-card usage.



