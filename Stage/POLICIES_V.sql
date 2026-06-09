create or replace view RLI_TEST.STAGE.POLICIES_V(
	POLICY_ID,
	CUSTOMER_ID,
	POLICY_TYPE,
	EFFECTIVE_DATE,
	EXPIRATION_DATE,
	PREMIUM,
	_INSRT_TS
) as 
select pol.* from RLI_TEST.RAW.POLICIES pol
inner join  RLI_TEST.RAW.CUSTOMERS cust on cust.customer_id = pol.customer_id
where 
    premium > 0 and
    effective_date < expiration_date
-- filters premium issue, customer foreign key issue, and invalid date ranges
QUALIFY COUNT(*) OVER (PARTITION BY pol.policy_id) = 1;
-- No duplicates are currently present, but adding to keep inline with POLICIES_TAGGED_V
;