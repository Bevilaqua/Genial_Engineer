-- Garante que o filtro de status está íntegro: toda agenda que contribuiu com
-- horas tem que estar 'active' no estado atual. Se alguma cancelada ou pausada
-- vazou pras sessões diárias, esta query retorna linhas (zero linhas = passou).

select
    sess.schedule_id,
    s.status
from {{ ref('int_scheduled_sessions_daily') }} as sess
join {{ ref('stg_weekly_schedules') }} as s
    on s.schedule_id = sess.schedule_id
where s.status != 'active'
