create or replace view RLI_TEST.STAGE.CUSTOMERS_V(
	CUSTOMER_ID,
	CUSTOMER_NAME,
	STATE,
	INDUSTRY,
	_INSRT_TS
) as
    select cust.* 
    from RLI_TEST.RAW.CUSTOMERS cust
    --no validation issues found. View is likely unnecessary. Keeping format for consistency