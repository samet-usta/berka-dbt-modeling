{% docs loaded_at %}
Load timestamp (UTC) written by the load script. Used for source freshness checks.
{% enddocs %}

{% docs updated_at %}
Last change time of the row in the source system. Initial load sets 1998-12-31; CDC batches set change_ts. Used by the snapshot timestamp strategy.
{% enddocs %}

{% docs dbt_scd_id %}
Unique ID of the version. Created by dbt.
{% enddocs %}

{% docs dbt_updated_at %}
Value of updated_at when dbt captured this version. Created by dbt.
{% enddocs %}

{% docs dbt_valid_from %}
Start time of the version (inclusive). Created by dbt.
{% enddocs %}

{% docs dbt_valid_to %}
End time of the version (exclusive). Current version has 9999-12-31. Created by dbt.
{% enddocs %}

{% docs dbt_is_deleted %}
True if the row was deleted in the source (hard_deletes: new_record). Created by dbt.
{% enddocs %}
