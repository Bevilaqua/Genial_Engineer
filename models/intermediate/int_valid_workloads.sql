-- Prescrições que realmente valem pra métrica.
--
-- Só considero status = 'validated'. As outras eu descarto:
--   - 'draft' ainda não foi aprovada clinicamente, então não conta.
--   - 'cancelled' foi revogada.
--
-- Também exijo prescribed_hours_per_week > 0. Isso é uma guarda de qualidade
-- (o dicionário da raw já recomenda) e evita prescrição zerada virar denominador
-- estranho lá na frente.
--
-- Integridade referencial: faço inner join com o estado atual de criança e
-- disciplina (stg_*). Assim, se a criança ou a disciplina foi DELETADA via CDC
-- (op = 'D', some do estado atual), a prescrição dela também sai da métrica --
-- senão eu estaria contando prescrição de uma entidade que não existe mais. Esse
-- foi um gap que encontrei: a disciplina 'to' tinha sido deletada mas continuava
-- aparecendo no fato.
--
-- NOTA sobre is_active: aqui eu só removo o que foi DELETADO. NÃO filtro por
-- is_active = 1, porque "disciplina desativada" (ex.: psicoped) é uma regra de
-- negócio diferente -- uma prescrição histórica dela pode ainda ser válida. Se o
-- negócio confirmar que desativado também não conta, basta adicionar
-- "and d.is_active = 1 and ch.is_active = 1" abaixo.
--
-- A janela de validade (valid_from/valid_to) eu aplico depois, dia a dia, contra
-- o calendário. Aqui só deixo passar as linhas que têm chance de contribuir.

select
    w.workload_id,
    w.child_id,
    w.discipline_id,
    w.valid_from,
    w.valid_to,
    w.prescribed_hours_per_week
from {{ ref('stg_prescription_workloads') }} as w
join {{ ref('stg_children') }}    as ch on ch.child_id      = w.child_id
join {{ ref('stg_disciplines') }} as d  on d.discipline_id  = w.discipline_id
where w.status = 'validated'
  and w.prescribed_hours_per_week > 0
