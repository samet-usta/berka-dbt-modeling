with source as (

    select * from {{ source('berka', 'loan') }}

),

renamed as (

    select
        cast(loan_id as integer)        as loan_id,
        cast(account_id as integer)     as account_id,
        strptime(date, '%y%m%d')::date  as granted_date,
        cast(amount as decimal(15,2))   as amount,

        -- duration: ay sayısı
        cast(duration as integer)       as duration,
        cast(payments as decimal(15,2)) as payments,

        case status
            when 'A' then 'finished_ok'
            when 'B' then 'finished_unpaid'
            when 'C' then 'running_ok'
            when 'D' then 'running_in_debt'
            else status
        end as loan_status,

        _loaded_at

    from source

)

select * from renamed
