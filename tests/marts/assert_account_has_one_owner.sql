-- Every account must have exactly one owner (0 or 2+ owners = fail).
with owner_counts as (
    select
        a.account_key,
        a.account_id,
        count(b.disposition_id) as owner_count
    from {{ ref('dim_account') }} as a
    left join {{ ref('bridge_account_client') }} as b
        on a.account_key = b.account_key
        and b.disposition_type = 'owner'
    group by a.account_key, a.account_id
)

select *
from owner_counts
where owner_count <> 1
