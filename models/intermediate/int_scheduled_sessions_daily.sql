-- Aqui eu transformo a agenda recorrente em ocorrências concretas no calendário.
--
-- Uma agenda semanal acontece num certo dia da semana, toda semana, entre o
-- valid_from e o valid_to. Então ela "materializa" como uma sessão por cada dia
-- daquele weekday que cai dentro da janela de validade.
--
-- O join com o calendário é por weekday, limitado pela validade (inclusivo nas
-- duas pontas). É exatamente isso que evita dupla contagem: cada sessão real vira
-- uma única linha (schedule_id, date_day).
--
-- O grain aqui é uma linha por ocorrência de sessão. No modelo seguinte eu somo
-- por (criança, disciplina, dia), pra quando a criança tiver mais de uma agenda
-- da mesma disciplina no mesmo dia as horas somarem certinho.

select
    s.schedule_id,
    s.child_id,
    s.discipline_id,
    c.date_day,
    c.weekday,
    c.is_weekend,
    s.scheduled_hours
from {{ ref('int_active_schedules') }} as s
join {{ ref('int_calendar') }} as c
    on c.weekday = s.weekday
   and c.date_day >= s.valid_from
   and c.date_day <= s.valid_to
