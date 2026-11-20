with snapshot_clients as (

    select * from {{ ref('snp_clients') }}

),

clients as (

    select * from {{ ref('int_clients_enriched') }}

),

districts as (

    select * from {{ ref('stg_berka__districts') }}

),

versions as (

    select
        client_id,
        district_id,

        -- First version is valid from the start, so old facts find a version (decision 87)
        case
            when dbt_valid_from = min(dbt_valid_from) over (partition by client_id)
                then cast('1900-01-01' as timestamp)
            else dbt_valid_from
        end as valid_from,

        dbt_valid_to as valid_to
    from snapshot_clients

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['versions.client_id', 'versions.valid_from']) }} as customer_key,
        versions.client_id,
        versions.valid_from,
        versions.valid_to,
        versions.valid_to = cast('9999-12-31' as timestamp) as is_current,

        -- Type 1: always the current value
        clients.gender,
        clients.birth_date,
        clients.age,

        -- Type 2: district of this version
        districts.district_name,
        districts.region,
        districts.average_salary as district_average_salary,

        -- Type 1 (decision 46)
        clients.has_card,
        clients.card_type,
        clients.card_issued_date
    from versions
    left join clients
        on versions.client_id = clients.client_id
    left join districts
        on versions.district_id = districts.district_id

)

select * from final
