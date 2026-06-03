-- Integridade referencial do fato: toda criança e disciplina que aparece na
-- métrica tem que existir no estado atual (stg_*). Se uma entidade foi deletada
-- via CDC e mesmo assim sobrou no fato, esta query retorna linhas
-- (zero linhas = passou). Foi o teste que criei depois de achar a disciplina
-- 'to' (deletada) aparecendo no resultado.

select
    f.child_id,
    f.discipline_id,
    'crianca_inexistente' as problema
from {{ ref('fct_daily_scheduling_rate') }} f
left join {{ ref('stg_children') }} s on s.child_id = f.child_id
where s.child_id is null

union all

select
    f.child_id,
    f.discipline_id,
    'disciplina_inexistente' as problema
from {{ ref('fct_daily_scheduling_rate') }} f
left join {{ ref('stg_disciplines') }} d on d.discipline_id = f.discipline_id
where d.discipline_id is null
