-- Aqui eu pego o estado atual de cada criança a partir dos eventos CDC.
-- Como pode chegar vários eventos pra mesma criança (insert, depois updates),
-- eu fico só com o mais recente: ordeno por source_updated_at desc e, em caso
-- de empate, desempato por ingested_at e por fim pelo event_id (pra ser
-- determinístico). Se o evento mais novo for um delete (op = 'D'), a criança
-- não existe mais no estado atual e eu descarto.

with ranked as (
    select
        *,
        row_number() over (
            partition by child_id
            order by source_updated_at desc, ingested_at desc, event_id desc
        ) as rn
    from {{ ref('raw_children') }}
),

current_state as (
    select *
    from ranked
    where rn = 1
)

select
    child_id,
    child_name,
    tenant_id,
    is_active,
    source_updated_at,
    op
from current_state
where op != 'D'
