
select distinct gender from retail_dw.dim_customer;
INSERT INTO lookup_gender VALUES ('M', 'Male'), ('F', 'Female'), ('O', 'Other');

select distinct payment_mode from retail_dw.fact_transaction;
INSERT INTO lookup_payment_mode (payment_mode_name)
SELECT DISTINCT payment_mode
FROM retail_dw.fact_transaction;

select distinct channel from retail_dw.fact_transaction;
INSERT INTO lookup_channel (channel_name)
select distinct channel from retail_dw.fact_transaction;

INSERT INTO lookup_order_status (status_name) VALUES 
    ('Pending'), ('Processing'), ('Completed'), ('Cancelled'), ('Returned');