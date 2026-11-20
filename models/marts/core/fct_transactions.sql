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

accounts as (

    select * from {{ ref('dim_account') }}

),

final as (

    select
        transactions.transaction_id,
        accounts.account_key,
        cast(strftime(transactions.transaction_date, '%Y%m%d') as integer) as date_key,
        transactions.transaction_date,
        transactions.transaction_type,
        transactions.operation,
        transactions.purpose,
        transactions.amount,
        case
            when transactions.transaction_type = 'credit' then transactions.amount
            else -transactions.amount
        end as signed_amount,
        transactions.balance,
        transactions.partner_bank,
        transactions.partner_account
    from transactions
    -- Range join: account version valid on the transaction date (decision 81)
    left join accounts
        on transactions.account_id = accounts.account_id
        and transactions.transaction_date >= accounts.valid_from
        and transactions.transaction_date < accounts.valid_to

)

select * from final
