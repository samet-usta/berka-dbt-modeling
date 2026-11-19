with clients as (

    select * from {{ ref('int_clients_enriched') }}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['client_id']) }} as customer_key,
        client_id,
        gender,
        birth_date,
        age,
        district_name,
        region,
        district_average_salary,
        has_card,
        card_type,
        card_issued_date
    from clients

)

select * from final
