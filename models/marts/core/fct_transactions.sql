{{
    config(
        materialized='incremental',
        unique_key='transaction_id',
        incremental_strategy='delete+insert'
    )
}}

with transactions as (

    select * from {{ ref('stg_berka__transactions') }}

    {% if is_incremental() %}
    -- Sadece son yüklenen günden itibaren gelen satırlar
    where transaction_date >= (select max(transaction_date) from {{ this }})
    {% endif %}

),

final as (

    select
        transaction_id,
        {{ dbt_utils.generate_surrogate_key(['account_id']) }} as account_key,
        cast(strftime(transaction_date, '%Y%m%d') as integer)  as date_key,
        transaction_date,
        transaction_type,
        operation,
        purpose,
        amount,
        case
            when transaction_type = 'credit' then amount
            else -amount
        end                                                    as signed_amount,
        balance,
        partner_bank,
        partner_account
    from transactions

)

select * from final
