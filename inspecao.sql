-- =====================================================================
-- Consultas de inspeção — scheduling_case.db
-- =====================================================================
-- Como usar no DB Browser for SQLite:
--   1. Open Database -> db/scheduling_case.db
--   2. Aba "Execute SQL"
--   3. Selecione UM bloco abaixo (entre os comentários) e rode (F5 ou
--      o botão de play). Rodar tudo de uma vez só mostra o resultado da
--      última query, então vá um bloco por vez.
--
-- A ordem segue o fluxo da pipeline: raw -> staging -> intermediate -> mart.
-- =====================================================================


-- =====================================================================
-- 0. VISÃO GERAL — quantas linhas em cada objeto
-- =====================================================================
select 'raw_prescription_workloads' as objeto, count(*) as linhas from raw_prescription_workloads
union all select 'raw_weekly_schedules',      count(*) from raw_weekly_schedules
union all select 'stg_prescription_workloads', count(*) from stg_prescription_workloads
union all select 'stg_weekly_schedules',       count(*) from stg_weekly_schedules
union all select 'int_valid_workloads',        count(*) from int_valid_workloads
union all select 'int_active_schedules',       count(*) from int_active_schedules
union all select 'int_calendar',               count(*) from int_calendar
union all select 'int_scheduled_sessions_daily', count(*) from int_scheduled_sessions_daily
union all select 'int_prescribed_daily_target',  count(*) from int_prescribed_daily_target
union all select 'fct_daily_scheduling_rate',     count(*) from fct_daily_scheduling_rate;


-- =====================================================================
-- 1. RAW — os eventos CDC crus (com I/U/D e timestamps)
--    Veja como a MESMA entidade aparece em vários eventos.
-- =====================================================================
-- Workloads: escolha um workload_id que tenha update e veja o histórico
select event_id, op, source_updated_at, workload_id, status, prescribed_hours_per_week
from raw_prescription_workloads
order by workload_id, source_updated_at
limit 50;

-- Quantos eventos de cada tipo (I/U/D) existem
-- select op, count(*) from raw_prescription_workloads group by op;
-- select op, count(*) from raw_weekly_schedules group by op;


-- =====================================================================
-- 2. STAGING — estado atual após a dedup de CDC
--    Aqui cada entidade já aparece UMA vez só, e os deletes sumiram.
-- =====================================================================
-- Conferência da dedup: total de linhas == total de IDs distintos?
select
    count(*)                      as linhas,
    count(distinct workload_id)   as ids_distintos
from stg_prescription_workloads;

-- Distribuição de status no estado atual (ajuda a entender os filtros seguintes)
-- select status, count(*) from stg_prescription_workloads group by status;
-- select status, count(*) from stg_weekly_schedules group by status;


-- =====================================================================
-- 3. INTERMEDIATE — filtros de negócio aplicados
--    Só validated (workloads) e só active (schedules).
-- =====================================================================
-- Quanto sobrou depois do filtro de status (compare com a staging acima)
select 'workloads validated' as conjunto, count(*) as linhas from int_valid_workloads
union all
select 'schedules active',    count(*) from int_active_schedules;

-- Calendário gerado (date spine). Veja o weekday e a flag de fim de semana.
-- select * from int_calendar order by date_day limit 30;


-- =====================================================================
-- 4. INTERMEDIATE — a agenda semanal virou ocorrências diárias
--    Uma linha por sessão concreta (schedule_id + data).
-- =====================================================================
select schedule_id, child_id, discipline_id, date_day, weekday, is_weekend, scheduled_hours
from int_scheduled_sessions_daily
order by child_id, discipline_id, date_day
limit 50;


-- =====================================================================
-- 5. INTERMEDIATE — a prescrição semanal virou meta diária (/5)
--    Repare: dia útil tem meta = horas_semana/5; fim de semana = 0.
-- =====================================================================
select child_id, discipline_id, date_day, weekday, is_weekend,
       prescribed_hours_per_week, prescribed_hours_daily_target
from int_prescribed_daily_target
order by child_id, discipline_id, date_day
limit 50;


-- =====================================================================
-- 6. MART FINAL — a métrica, no grain (criança, disciplina, dia)
-- =====================================================================
-- 6a. Linhas "matched": tem prescrição validada E tem agenda
select child_id, discipline_id, date_day, weekday,
       scheduled_hours_day, prescribed_hours_daily_target, daily_scheduling_rate,
       scheduled_hours_week, prescribed_hours_per_week, weekly_scheduling_rate
from fct_daily_scheduling_rate
where coverage_flag = 'matched'
order by child_id, discipline_id, date_day
limit 50;

-- 6b. Distribuição das três categorias de cobertura
-- select coverage_flag, count(*) from fct_daily_scheduling_rate group by coverage_flag;


-- =====================================================================
-- 7. CASOS DE BORDA — o que o FULL OUTER JOIN preserva
-- =====================================================================
-- 7a. Agendou mas não há prescrição validada (taxa semanal fica NULL)
select child_id, discipline_id, date_day, scheduled_hours_day,
       prescribed_hours_per_week, weekly_scheduling_rate, coverage_flag
from fct_daily_scheduling_rate
where coverage_flag = 'scheduled_without_prescription'
limit 30;

-- 7b. Tem prescrição validada mas nenhuma hora agendada (agendou 0)
-- select child_id, discipline_id, date_day, scheduled_hours_day,
--        prescribed_hours_per_week, weekly_scheduling_rate, coverage_flag
-- from fct_daily_scheduling_rate
-- where coverage_flag = 'prescribed_without_schedule'
-- limit 30;

-- 7c. Atividade em fim de semana (meta diária 0 -> taxa diária fica NULL)
-- select child_id, discipline_id, date_day, weekday, is_weekend,
--        scheduled_hours_day, prescribed_hours_daily_target, daily_scheduling_rate
-- from fct_daily_scheduling_rate
-- where is_weekend = 1 and scheduled_hours_day > 0
-- limit 30;


-- =====================================================================
-- 8. RASTREIO DE UMA CRIANÇA+DISCIPLINA (a "história" completa)
--    Troque os valores e veja a série diária dessa dupla.
-- =====================================================================
select date_day, weekday, is_weekend,
       scheduled_hours_day, prescribed_hours_daily_target, daily_scheduling_rate,
       scheduled_hours_week, prescribed_hours_per_week, weekly_scheduling_rate,
       coverage_flag
from fct_daily_scheduling_rate
where child_id = 'child_003'
  and discipline_id = 'psico'
order by date_day;
