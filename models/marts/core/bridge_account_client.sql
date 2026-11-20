with dispositions as (

    select * from {{ ref('stg_berka__dispositions') }}

),

final as (

    -- Durable keys only: the bridge links all versions of an account and a client (decision 82)
    select
        disposition_id,
        account_id,
        client_id,
        disposition_type
    from dispositions

)

select * from final
