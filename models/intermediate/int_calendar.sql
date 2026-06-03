-- Calendário (date spine) cobrindo toda a janela de análise.
--
-- O SQLite não tem tabela de calendário pronta, então eu expando as datas com
-- uma CTE recursiva (o padrão que o próprio README sugere). Em vez de cravar
-- datas fixas, eu calculo os limites a partir dos próprios dados: pego o menor
-- valid_from e o maior valid_to entre workloads e schedules. Assim o calendário
-- sempre acompanha os dados, sem eu precisar mexer aqui se os seeds mudarem.

with bounds as (
    select
        min(d_from) as start_day,
        max(d_to)   as end_day
    from (
        select min(valid_from) as d_from, max(valid_to) as d_to
        from {{ ref('stg_prescription_workloads') }}
        union all
        select min(valid_from) as d_from, max(valid_to) as d_to
        from {{ ref('stg_weekly_schedules') }}
    )
),

calendar(date_day) as (
    select start_day from bounds
    union all
    select date(date_day, '+1 day')
    from calendar
    where date_day < (select end_day from bounds)
)

select
    date_day,
    case strftime('%w', date_day)
        when '0' then 'sunday'
        when '1' then 'monday'
        when '2' then 'tuesday'
        when '3' then 'wednesday'
        when '4' then 'thursday'
        when '5' then 'friday'
        when '6' then 'saturday'
    end as weekday,
    cast(strftime('%w', date_day) as integer) in (0, 6) as is_weekend
from calendar
