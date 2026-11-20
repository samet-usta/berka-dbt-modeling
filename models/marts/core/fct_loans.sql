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

accounts as (

    select * from {{ ref('dim_account') }}

),

final as (

    select
        loans.loan_id,
        accounts.account_key,
        cast(strftime(loans.granted_date, '%Y%m%d') as integer) as date_key,
        loans.granted_date,
        loans.amount,
        loans.duration,
        loans.payments,
        loans.loan_status
    from loans
    -- Range join: account version valid on the grant date (decision 81)
    left join accounts
        on loans.account_id = accounts.account_id
        and loans.granted_date >= accounts.valid_from
        and loans.granted_date < accounts.valid_to

)

select * from final
