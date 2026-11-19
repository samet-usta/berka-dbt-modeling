with date_spine as (

    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('" ~ var('dim_date_start') ~ "' as date)",
        end_date="(cast('" ~ var('dim_date_end') ~ "' as date) + 1)"
    ) }}

),

days as (

    select cast(date_day as date) as date_day
    from date_spine

),

final as (

    select
        cast(strftime(date_day, '%Y%m%d') as integer) as date_key,
        date_day,
        year(date_day)                                as year,
        quarter(date_day)                             as quarter,
        month(date_day)                               as month,
        monthname(date_day)                           as month_name,
        strftime(date_day, '%Y-%m')                   as year_month,
        dayofmonth(date_day)                          as day_of_month,
        isodow(date_day)                              as day_of_week,
        dayname(date_day)                             as day_name,
        isodow(date_day) in (6, 7)                    as is_weekend
    from days

)

select * from final
