-- Agendas que de fato contam como horas agendadas.
--
-- Só status = 'active'. Descarto:
--   - 'cancelled' (cancelada).
--   - 'paused' (pausada) -- enquanto está pausada não acontece sessão, então
--     não faz sentido contar essas horas.
--
-- Exijo scheduled_hours > 0 também, pra me proteger de horário malformado
-- (ex.: end_time menor ou igual ao start_time, que daria hora negativa ou zero).
--
-- Integridade referencial: mesmo tratamento do int_valid_workloads. Faço inner
-- join com criança e disciplina do estado atual, pra agenda de entidade deletada
-- via CDC não vazar pra métrica. (Não filtro is_active aqui pelo mesmo motivo
-- explicado lá -- é regra de negócio a confirmar, não bug.)
--
-- Tem um teste separado garantindo que nada fora de 'active' vaza pra frente.

select
    s.schedule_id,
    s.child_id,
    s.discipline_id,
    s.weekday,
    s.start_time,
    s.end_time,
    s.valid_from,
    s.valid_to,
    s.scheduled_hours
from {{ ref('stg_weekly_schedules') }} as s
join {{ ref('stg_children') }}    as ch on ch.child_id     = s.child_id
join {{ ref('stg_disciplines') }} as d  on d.discipline_id = s.discipline_id
where s.status = 'active'
  and s.scheduled_hours > 0
