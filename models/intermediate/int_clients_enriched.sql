with clients as (
    select * from {{ ref('stg_berka__clients') }}
),

districts as (
    select * from {{ ref('stg_berka__districts') }}
),

dispositions as (
    select * from {{ ref('stg_berka__dispositions') }}
),

cards as (
    select * from {{ ref('stg_berka__cards') }}
),

birth_parts as (
    select
        client_id,
        birth_number,
        district_id,
        cast(substr(cast(birth_number as varchar), 1, 2) as integer) as birth_year_2d,
        cast(substr(cast(birth_number as varchar), 3, 2) as integer) as birth_month_raw,
        cast(substr(cast(birth_number as varchar), 5, 2) as integer) as birth_day
    from clients
),

clients_derived as (
    select
        client_id,
        birth_number,
        district_id,
        -- Berka rule: women have month + 50
        case when birth_month_raw > 50 then 'female' else 'male' end as gender,
        make_date(
            1900 + birth_year_2d,
            case when birth_month_raw > 50 then birth_month_raw - 50 else birth_month_raw end,
            birth_day
        ) as birth_date
    from birth_parts
),

joined as (
    select
        c.client_id,
        c.birth_number,
        c.gender,
        c.birth_date,
        -- age at reference_date (data ends 1998), not current_date
        cast(date_part('year', age(cast('{{ var("reference_date") }}' as date), c.birth_date)) as integer) as age,
        c.district_id,
        d.district_name,
        d.region,
        d.average_salary as district_average_salary,
        dp.disposition_id,
        dp.account_id,
        dp.disposition_type,
        ca.card_id is not null as has_card,
        ca.card_type,
        ca.issued_date as card_issued_date
    from clients_derived as c
    left join districts as d
        on c.district_id = d.district_id
    left join dispositions as dp
        on c.client_id = dp.client_id
    left join cards as ca
        on dp.disposition_id = ca.disposition_id
)

select * from joined
