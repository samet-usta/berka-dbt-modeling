{{
    config(
        materialized='incremental',
        unique_key='loan_id',
        incremental_strategy='delete+insert'
    )
}}

with loans as (

    select * from {{ ref('stg_berka__loans') }}

    {% if is_incremental() %}
    -- Sadece son yüklenen günden itibaren gelen satırlar
    where granted_date >= (select max(granted_date) from {{ this }})
    {% endif %}

),

final as (

    select
        loan_id,
        {{ dbt_utils.generate_surrogate_key(['account_id']) }} as account_key,
        cast(strftime(granted_date, '%Y%m%d') as integer)      as date_key,
        granted_date,
        amount,
        duration,
        payments,
        loan_status
    from loans

)

select * from final
