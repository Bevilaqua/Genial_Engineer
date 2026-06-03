-- TABELA FINAL: taxa de agendamento diária por criança e disciplina.
--
-- Grain: uma linha por (child_id, discipline_id, date_day).
--
-- É a tabela que responde a pergunta do case:
--   "Para cada criança, disciplina e dia, qual a taxa de agendamento em relação
--    à carga horária prescrita validada?"
--
-- Eu exponho a métrica em duas resoluções na mesma linha:
--   * Diária  -> scheduled_hours_day vs prescribed_hours_daily_target
--                (daily_scheduling_rate), que casa com o grain diário pedido.
--   * Semanal -> scheduled_hours_week vs prescribed_hours_per_week
--                (weekly_scheduling_rate), que é a definição base do README
--                (horas agendadas na semana / horas prescritas na semana). Carrego
--                ela em cada dia pra dar pra ler o dia contra a meta da semana.
--
-- Os casos de borda saem do FULL OUTER JOIN entre prescrição e agenda:
--   * agenda sem prescrição validada -> lado prescrito vem NULL
--     (coverage_flag = 'scheduled_without_prescription').
--   * prescrição validada sem nenhuma agenda -> lado agendado vem 0
--     (coverage_flag = 'prescribed_without_schedule').
--   * os dois presentes -> 'matched'.

with scheduled_daily as (
    -- junta numa linha só as várias agendas da mesma criança+disciplina no dia
    select
        child_id,
        discipline_id,
        date_day,
        weekday,
        is_weekend,
        sum(scheduled_hours) as scheduled_hours_day
    from {{ ref('int_scheduled_sessions_daily') }}
    group by child_id, discipline_id, date_day, weekday, is_weekend
),

prescribed_daily as (
    -- mesma ideia do lado da prescrição: soma se houver mais de uma workload
    select
        child_id,
        discipline_id,
        date_day,
        weekday,
        is_weekend,
        sum(prescribed_hours_per_week)    as prescribed_hours_per_week,
        sum(prescribed_hours_daily_target) as prescribed_hours_daily_target
    from {{ ref('int_prescribed_daily_target') }}
    group by child_id, discipline_id, date_day, weekday, is_weekend
),

joined as (
    -- FULL OUTER JOIN pra não perder os dias que só têm um dos lados.
    -- Os coalesce nas chaves são porque, quando um lado não casa, as colunas dele
    -- vêm NULL; assim child_id/discipline_id/date_day nunca ficam nulos.
    -- Já o scheduled_hours_day eu trago como 0 quando não há agenda ("agendou
    -- zero"), mas deixo o lado prescrito como NULL de propósito, porque "não tem
    -- prescrição" é diferente de "prescrição zero" -- é isso que me deixa
    -- classificar a coverage_flag depois.
    select
        coalesce(p.child_id,      s.child_id)      as child_id,
        coalesce(p.discipline_id, s.discipline_id) as discipline_id,
        coalesce(p.date_day,      s.date_day)      as date_day,
        coalesce(p.weekday,       s.weekday)       as weekday,
        coalesce(p.is_weekend,    s.is_weekend)    as is_weekend,
        coalesce(s.scheduled_hours_day, 0.0)       as scheduled_hours_day,
        p.prescribed_hours_per_week,
        p.prescribed_hours_daily_target
    from prescribed_daily as p
    full outer join scheduled_daily as s
        on  p.child_id      = s.child_id
        and p.discipline_id = s.discipline_id
        and p.date_day      = s.date_day
),

-- horas agendadas por semana (por criança+disciplina), pra sustentar a definição
-- semanal do README. O strftime('%W') agrupa por semana do ano (começa na
-- segunda); junto com o ano (%Y) pra duas "semana 1" de anos diferentes não se
-- misturarem.
weekly_scheduled as (
    select
        child_id,
        discipline_id,
        strftime('%Y', date_day) as iso_year,
        strftime('%W', date_day) as iso_week,
        sum(scheduled_hours_day) as scheduled_hours_week
    from joined
    group by child_id, discipline_id, iso_year, iso_week
)

select
    j.child_id,
    j.discipline_id,
    j.date_day,
    j.weekday,
    j.is_weekend,

    -- números diários
    j.scheduled_hours_day,
    j.prescribed_hours_daily_target,
    -- o case evita divisão por zero: fim de semana tem meta 0 e dia sem
    -- prescrição tem meta nula, então nesses casos a taxa fica NULL em vez de
    -- quebrar a query.
    case
        when j.prescribed_hours_daily_target is null
          or j.prescribed_hours_daily_target = 0 then null
        else round(j.scheduled_hours_day / j.prescribed_hours_daily_target, 4)
    end as daily_scheduling_rate,

    -- números semanais (definição base do README)
    j.prescribed_hours_per_week,
    w.scheduled_hours_week,
    case
        when j.prescribed_hours_per_week is null
          or j.prescribed_hours_per_week = 0 then null
        else round(w.scheduled_hours_week / j.prescribed_hours_per_week, 4)
    end as weekly_scheduling_rate,

    -- classificação dos dois casos de borda, pra ficarem visíveis e filtráveis
    case
        when j.prescribed_hours_per_week is not null
         and j.scheduled_hours_day > 0           then 'matched'
        when j.prescribed_hours_per_week is null  then 'scheduled_without_prescription'
        when j.scheduled_hours_day = 0
          or j.scheduled_hours_day is null        then 'prescribed_without_schedule'
        else 'matched'
    end as coverage_flag

from joined as j
left join weekly_scheduled as w
    on  w.child_id      = j.child_id
    and w.discipline_id = j.discipline_id
    and w.iso_year      = strftime('%Y', j.date_day)
    and w.iso_week      = strftime('%W', j.date_day)
