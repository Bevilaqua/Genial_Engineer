select
  event_id,
  op,
  datetime(source_updated_at) as source_updated_at,
  datetime(ingested_at) as ingested_at,
  discipline_id,
  discipline_name,
  case
    when lower(cast(is_active as text)) in ('true', '1') then 1
    else 0
  end as is_active
from {{ ref('cdc_disciplines') }}
