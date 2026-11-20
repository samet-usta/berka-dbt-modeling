-- The next version starts exactly when the previous version ends (no gap, no overlap)

with versions as (

    select 'snp_clients' as model_name, client_id as natural_key,
        dbt_valid_from as valid_from, dbt_valid_to as valid_to
    from {{ ref('snp_clients') }}

    union all

    select 'snp_accounts', account_id, dbt_valid_from, dbt_valid_to
    from {{ ref('snp_accounts') }}

    union all

    select 'dim_customer', client_id, valid_from, valid_to
    from {{ ref('dim_customer') }}

    union all

    select 'dim_account', account_id, valid_from, valid_to
    from {{ ref('dim_account') }}

),

ordered as (

    select
        *,
        lead(valid_from) over (partition by model_name, natural_key order by valid_from) as next_valid_from
    from versions

)

select * from ordered
where next_valid_from is not null
  and next_valid_from <> valid_to
