-- Fact row count must equal staging row count (no lost or duplicate rows after incremental load).
with row_counts as (
    select
        'fct_transactions' as model_name,
        (select count(*) from {{ ref('stg_berka__transactions') }}) as source_count,
        (select count(*) from {{ ref('fct_transactions') }}) as target_count

    union all

    select
        'fct_loans' as model_name,
        (select count(*) from {{ ref('stg_berka__loans') }}) as source_count,
        (select count(*) from {{ ref('fct_loans') }}) as target_count
)

select *
from row_counts
where source_count <> target_count
