with source as (

    select * from {{ source('berka', 'disp') }}

),

renamed as (

    select
        cast(disp_id as integer)    as disposition_id,
        cast(client_id as integer)  as client_id,
        cast(account_id as integer) as account_id,

        -- OWNER / DISPONENT → owner / disponent
        lower(type) as disposition_type,

        _loaded_at

    from source

)

select * from renamed
