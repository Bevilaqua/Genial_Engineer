-- A tabela final tem que ser única no grain que eu declarei:
-- (child_id, discipline_id, date_day). Se aparecer duplicata, esta query
-- devolve as linhas problemáticas. Na convenção do dbt, teste passa quando
-- não retorna nenhuma linha.

select
    child_id,
    discipline_id,
    date_day,
    count(*) as records_count
from {{ ref('fct_daily_scheduling_rate') }}
group by child_id, discipline_id, date_day
having count(*) > 1
