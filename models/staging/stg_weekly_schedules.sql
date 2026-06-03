-- Estado atual das agendas semanais. Deduplico pelo schedule_id, mesma lógica
-- das outras staging: fico com o evento mais recente e descarto se o último
-- for delete. Filtro de status também não entra aqui, fica no intermediate.

with ranked as (
    select
        *,
        row_number() over (
            partition by schedule_id
            order by source_updated_at desc, ingested_at desc, event_id desc
        ) as rn
    from {{ ref('raw_weekly_schedules') }}
),

current_state as (
    select *
    from ranked
    where rn = 1
)

select
    schedule_id,
    child_id,
    discipline_id,
    weekday,
    start_time,
    end_time,
    valid_from,
    valid_to,
    status,
    scheduled_hours,
    source_updated_at,
    op
from current_state
where op != 'D'
