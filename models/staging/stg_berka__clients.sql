with source as (

    select * from {{ source('berka', 'client') }}

),

renamed as (

    select
        cast(client_id as integer)   as client_id,

        -- Cinsiyet ve doğum tarihi bu kolondan intermediate'te türetilir
        birth_number,

        cast(district_id as integer) as district_id,

        -- Snapshot (SCD2) timestamp strategy bu kolonu okur
        updated_at,
        _loaded_at

    from source

)

select * from renamed
