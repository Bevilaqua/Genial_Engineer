select
  event_id,
  op,
  datetime(source_updated_at) as source_updated_at,
  datetime(ingested_at) as ingested_at,
  schedule_id,
  child_id,
  discipline_id,
  lower(weekday) as weekday,
  start_time,
  end_time,
  date(valid_from) as valid_from,
  date(valid_to) as valid_to,
  lower(status) as status,
  (
    cast(strftime('%s', '2000-01-01 ' || end_time) as integer)
    - cast(strftime('%s', '2000-01-01 ' || start_time) as integer)
  ) / 3600.0 as scheduled_hours
from {{ ref('cdc_weekly_schedules') }}
