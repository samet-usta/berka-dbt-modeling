with source as (

    select * from {{ source('berka', 'district') }}

),

renamed as (

    select
        cast(A1 as integer)            as district_id,
        A2                             as district_name,
        A3                             as region,
        cast(A4 as integer)            as inhabitants,
        cast(A5 as integer)            as municipalities_lt_500,
        cast(A6 as integer)            as municipalities_500_1999,
        cast(A7 as integer)            as municipalities_2000_9999,
        cast(A8 as integer)            as municipalities_gt_10000,
        cast(A9 as integer)            as cities,
        cast(A10 as decimal(5,2))      as urban_ratio,
        cast(A11 as decimal(15,2))     as average_salary,

        -- A12 ve A15 içinde '?' var: try_cast → NULL
        try_cast(A12 as decimal(5,2))  as unemployment_rate_95,
        cast(A13 as decimal(5,2))      as unemployment_rate_96,
        cast(A14 as integer)           as entrepreneurs_per_1000,
        try_cast(A15 as integer)       as crimes_95,
        cast(A16 as integer)           as crimes_96,

        _loaded_at

    from source

)

select * from renamed
