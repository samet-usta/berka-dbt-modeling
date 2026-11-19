with dispositions as (

    select * from {{ ref('stg_berka__dispositions') }}

),

final as (

    select
        disposition_id,
        {{ dbt_utils.generate_surrogate_key(['account_id']) }} as account_key,
        {{ dbt_utils.generate_surrogate_key(['client_id']) }}  as customer_key,
        account_id,
        client_id,
        disposition_type
    from dispositions

)

select * from final
