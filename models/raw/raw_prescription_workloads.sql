select
  event_id,
  op,
  datetime(source_updated_at) as source_updated_at,
  datetime(ingested_at) as ingested_at,
  workload_id,
  child_id,
  discipline_id,
  date(valid_from) as valid_from,
  date(valid_to) as valid_to,
  cast(prescribed_hours_per_week as real) as prescribed_hours_per_week,
  lower(status) as status
from {{ ref('cdc_prescription_workloads') }}
