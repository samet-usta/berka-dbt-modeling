with source as (

    select * from {{ source('berka', 'account') }}

),

renamed as (

    select
        cast(account_id as integer)  as account_id,
        cast(district_id as integer) as district_id,

        -- Çekçe kodu İngilizceye çevir; bilinmeyen kod olduğu gibi kalır
        case frequency
            when 'POPLATEK MESICNE'   then 'monthly'
            when 'POPLATEK TYDNE'     then 'weekly'
            when 'POPLATEK PO OBRATU' then 'after_transaction'
            else frequency
        end as frequency,

        -- YYMMDD: 930101 → 1993-01-01
        strptime(date, '%y%m%d')::date as created_date,

        _loaded_at

    from source

)

select * from renamed
