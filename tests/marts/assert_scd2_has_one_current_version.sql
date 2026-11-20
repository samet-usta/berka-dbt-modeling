-- Every key has exactly one current version (0 included) in snapshots and SCD2 dims

with current_counts as (

    select 'snp_clients' as model_name, client_id as natural_key,
        count(*) filter (where dbt_valid_to = '9999-12-31') as current_count
    from {{ ref('snp_clients') }}
    group by client_id

    union all

    select 'snp_accounts', account_id,
        count(*) filter (where dbt_valid_to = '9999-12-31')
    from {{ ref('snp_accounts') }}
    group by account_id

    union all

    select 'dim_customer', client_id,
        count(*) filter (where is_current)
    from {{ ref('dim_customer') }}
    group by client_id

    union all

    select 'dim_account', account_id,
        count(*) filter (where is_current)
    from {{ ref('dim_account') }}
    group by account_id

)

select * from current_counts
where current_count <> 1
