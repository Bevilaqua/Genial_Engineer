-- Sanidade da métrica: taxa nunca pode ser negativa, e sempre que existe
-- prescrição as horas semanais têm que ser positivas. Devolve as linhas que
-- violam isso (zero linhas = passou).

select
    child_id,
    discipline_id,
    date_day,
    scheduled_hours_day,
    prescribed_hours_per_week,
    daily_scheduling_rate,
    weekly_scheduling_rate
from {{ ref('fct_daily_scheduling_rate') }}
where coalesce(daily_scheduling_rate, 0) < 0
   or coalesce(weekly_scheduling_rate, 0) < 0
   or scheduled_hours_day < 0
   or (prescribed_hours_per_week is not null and prescribed_hours_per_week <= 0)
