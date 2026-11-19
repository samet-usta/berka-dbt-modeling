with source as (

    select * from {{ source('berka', 'card') }}

),

renamed as (

    select
        cast(card_id as integer) as card_id,
        cast(disp_id as integer) as disposition_id,

        -- junior / classic / gold
        lower(type) as card_type,

        -- '931107 00:00:00' → ilk 6 karakter → 1993-11-07
        strptime(left(issued, 6), '%y%m%d')::date as issued_date,

        _loaded_at

    from source

)

select * from renamed