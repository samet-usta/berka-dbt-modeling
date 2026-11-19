with source as (

    select * from {{ source('berka', 'orders') }}

),

renamed as (

    select
        cast(order_id as integer)     as order_id,
        cast(account_id as integer)   as account_id,

        -- Başka bankadaki hesap: bizim ID değil, VARCHAR kalır
        bank_to,
        account_to,

        cast(amount as decimal(15,2)) as amount,

        -- Boş kod → NULL, sonra çeviri
        case nullif(trim(k_symbol), '')
            when 'POJISTNE' then 'insurance'
            when 'SIPO'     then 'household'
            when 'LEASING'  then 'leasing'
            when 'UVER'     then 'loan_payment'
            else nullif(trim(k_symbol), '')
        end as purpose,

        _loaded_at

    from source

)

select * from renamed
