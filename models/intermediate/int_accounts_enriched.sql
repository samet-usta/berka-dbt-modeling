with accounts as (
    select * from {{ ref('stg_berka__accounts') }}
),

districts as (
    select * from {{ ref('stg_berka__districts') }}
),

dispositions as (
    select * from {{ ref('stg_berka__dispositions') }}
),

loans as (
    select * from {{ ref('stg_berka__loans') }}
),

-- each account has exactly 1 owner (checked in P3-A2-S2b)
owners as (
    select
        account_id,
        client_id as owner_client_id
    from dispositions
    where disposition_type = 'owner'
),

-- aggregate to account grain: no fan-out
disponents as (
    select
        account_id,
        count(*) as disponent_count
    from dispositions
    where disposition_type = 'disponent'
    group by account_id
),

joined as (
    select
        a.account_id,
        a.frequency,
        a.created_date,
        a.district_id,
        d.district_name,
        d.region,
        o.owner_client_id,
        coalesce(dc.disponent_count, 0) as disponent_count,
        l.loan_id is not null as has_loan,
        l.loan_id,
        l.granted_date as loan_granted_date,
        l.amount as loan_amount,
        l.duration as loan_duration,
        l.payments as loan_payments,
        l.loan_status
    from accounts as a
    left join districts as d
        on a.district_id = d.district_id
    left join owners as o
        on a.account_id = o.account_id
    left join disponents as dc
        on a.account_id = dc.account_id
    left join loans as l
        on a.account_id = l.account_id
)

select * from joined
