with snapshot_accounts as (

    select * from {{ ref('snp_accounts') }}

),

accounts as (

    select * from {{ ref('int_accounts_enriched') }}

),

districts as (

    select * from {{ ref('stg_berka__districts') }}

),

versions as (

    select
        account_id,
        district_id,
        frequency,

        -- First version is valid from the start, so old facts find a version (decision 87)
        case
            when dbt_valid_from = min(dbt_valid_from) over (partition by account_id)
                then cast('1900-01-01' as timestamp)
            else dbt_valid_from
        end as valid_from,

        dbt_valid_to as valid_to
    from snapshot_accounts

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['versions.account_id', 'versions.valid_from']) }} as account_key,
        versions.account_id,
        versions.valid_from,
        versions.valid_to,
        versions.valid_to = cast('9999-12-31' as timestamp) as is_current,

        -- Type 2: frequency and district of this version
        versions.frequency,
        districts.district_name,
        districts.region,

        -- Type 1: always the current value
        accounts.created_date,
        accounts.owner_client_id,
        accounts.disponent_count,
        accounts.has_loan
    from versions
    left join accounts
        on versions.account_id = accounts.account_id
    left join districts
        on versions.district_id = districts.district_id

)

select * from final
