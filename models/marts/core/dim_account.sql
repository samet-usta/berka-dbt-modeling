with accounts as (

    select * from {{ ref('int_accounts_enriched') }}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['account_id']) }} as account_key,
        account_id,
        frequency,
        created_date,
        district_name,
        region,
        owner_client_id,
        disponent_count,
        has_loan
    from accounts

)

select * from final
