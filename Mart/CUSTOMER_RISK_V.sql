create or replace view RLI_TEST.MART.CUSTOMER_RISK_V(
	CUSTOMER_ID,
	CUSTOMER_NAME,
	STATE,
	INDUSTRY,
	TOTAL_POLICY_COUNT,
	ACTIVE_POLICY_COUNT,
	TOTAL_PREMIUM,
	TOTAL_PRORATED_PREMIUM,
	TOTAL_PAYMENTS_COLLECTED,
	TOTAL_ENDORSEMENTS,
	TOTAL_ADJUSTED_PREMIUM,
	TOTAL_CLOSED_CLAIMS,
	TOTAL_OPEN_CLAIMS,
	TOTAL_CLAIMS,
	TOTAL_PRORATED_NET_POSITION,
	TOTAL_NET_POSITION,
	LOSS_RATIO,
	OPEN_EXPOSURE_RATIO,
	COLLECTION_RATIO,
	AVG_CLAIMS_PER_POLICY,
	COLLECTION_GAP,
	FLAG_OPEN_EXPOSURE,
	FLAG_COLLECTION,
	FLAG_NEGATIVE_POSITION,
	FLAG_HIGH_FREQUENCY,
	RISK_SCORE,
	RISK_TIER
) as
WITH customer_rollup AS (
    SELECT
        customer_id,
        customer_name,
        state,
        industry,

        -- policy counts
        COUNT(DISTINCT policy_id)                   AS total_policy_count,
        COUNT(DISTINCT CASE 
            WHEN CURRENT_DATE() 
                BETWEEN effective_date AND expiration_date
            THEN policy_id END)                     AS active_policy_count,

        -- premium
        SUM(premium)                                AS total_premium,
        SUM(prorated_premium)                       AS total_prorated_premium,
        SUM(payment_total)                          AS total_payments_collected,
        SUM(endorsement_total)                      AS total_endorsements,
        SUM(prorated_premium) 
            + COALESCE(SUM(endorsement_total), 0)   AS total_adjusted_premium,

        -- claims
        SUM(closed_claim_total)                     AS total_closed_claims,
        SUM(op_claim_total)                         AS total_open_claims,
        coalesce(SUM(closed_claim_total),0) 
            + coalesce(SUM(op_claim_total),0)       AS total_claims,

        -- net position

        SUM(prorated_premium) 
        + COALESCE(SUM(endorsement_total), 0) 
        - COALESCE(SUM(closed_claim_total), 0) 
        - COALESCE(SUM(op_claim_total), 0)              AS total_prorated_net_position,

        SUM(premium) 
        + COALESCE(SUM(endorsement_total), 0) 
        - COALESCE(SUM(closed_claim_total), 0) 
        - COALESCE(SUM(op_claim_total), 0)              AS total_net_position
        -- SUM(net_position)                           AS total_net_position

    FROM RLI_TEST.MART.POLICY_TOTALS_V
    GROUP BY 
        customer_id,
        customer_name,
        state,
        industry
)

,risk_quantities AS (
    SELECT
        *,

        -- derived ratios
        DIV0(total_claims, 
            total_adjusted_premium)                 AS loss_ratio,
        DIV0(total_open_claims, 
            total_adjusted_premium)                 AS open_exposure_ratio,
        DIV0(total_payments_collected, 
            total_adjusted_premium)                 AS collection_ratio,
        DIV0(total_claims, 
            NULLIF(total_policy_count, 0))          AS avg_claims_per_policy,
        total_adjusted_premium 
            - total_payments_collected              AS collection_gap,

        -- individual risk flags
        -- CASE WHEN DIV0(total_claims, 
        --     total_adjusted_premium) > 1.0
        --     THEN 1 ELSE 0 END                       AS flag_loss_ratio,

        CASE WHEN DIV0(total_open_claims, 
            NULLIF(total_claims, 0)) > 0.5
            THEN 1 ELSE 0 END                       AS flag_open_exposure,
            --open/pending claims appear to carry more risk. Flag if more than half of claims totals are in an open status.

        CASE WHEN DIV0(total_payments_collected, 
            total_adjusted_premium) < 0.5
            THEN 1 ELSE 0 END                       AS flag_collection,
            --flag if the customer has not paid their premiums up to the current prorated amount

        CASE WHEN total_prorated_net_position < 0
            THEN 1 ELSE 0 END                       AS flag_negative_position,
            --flag if customer is not profitable

        CASE WHEN DIV0(total_claims,
            NULLIF(total_policy_count, 0)) > 2
            THEN 1 ELSE 0 END                       AS flag_high_frequency
            --flag if customer claim quantity is high. Similar to flag loss ratio.

    FROM customer_rollup
)

,risk_scored as (
select 
    *,
    flag_open_exposure+flag_collection+flag_negative_position+flag_high_frequency as risk_score
from risk_quantities
)

SELECT
    *,
    CASE
        WHEN risk_score > total_policy_count        THEN 'High'
        WHEN risk_score > (total_policy_count * .5)   THEN 'Medium'
        WHEN risk_score > 0                         THEN 'Low'
        ELSE                                        'No Risk'
    END                                             AS risk_tier
FROM risk_scored
ORDER BY
    CASE
        WHEN risk_score > total_policy_count        THEN 3
        WHEN risk_score > (total_policy_count * .5)   THEN 2
        WHEN risk_score > 0                         THEN 1
        ELSE                                        0
    END DESC,
    risk_score desc, loss_ratio DESC;