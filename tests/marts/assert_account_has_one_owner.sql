-- Every current account has exactly one owner in the bridge (0 included)

with accounts as (

    select account_id from {{ ref('dim_account') }}
    where is_current

),

owners as (

    select account_id from {{ ref('bridge_account_client') }}
    where disposition_type = 'owner'

)

select
    accounts.account_id,
    count(owners.account_id) as owner_count
from accounts
left join owners
    on accounts.account_id = owners.account_id
group by accounts.account_id
having count(owners.account_id) <> 1
