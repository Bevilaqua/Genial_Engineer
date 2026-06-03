select
  event_id,
  count(*) as records_count
from {{ ref('raw_children') }}
group by event_id
having count(*) > 1
