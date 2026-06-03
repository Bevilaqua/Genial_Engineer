-- Mesma ideia do stg_children, mas pra disciplinas: fico com o último evento
-- de cada discipline_id e jogo fora as que terminam em delete. A regra de
-- desempate é a mesma pra manter tudo consistente entre as entidades.

with ranked as (
    select
        *,
        row_number() over (
            partition by discipline_id
            order by source_updated_at desc, ingested_at desc, event_id desc
        ) as rn
    from {{ ref('raw_disciplines') }}
),

current_state as (
    select *
    from ranked
    where rn = 1
)

select
    discipline_id,
    discipline_name,
    is_active,
    source_updated_at,
    op
from current_state
where op != 'D'
