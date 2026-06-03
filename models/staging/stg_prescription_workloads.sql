-- Estado atual das prescrições (workloads). A identidade estável aqui é o
-- workload_id, então é por ele que eu deduplico: último evento vence, delete
-- no topo significa que a prescrição foi removida.
--
-- De propósito eu NÃO filtro status nem validade aqui. Esta camada só responde
-- "qual é a versão atual de cada linha". Os filtros de negócio (validated,
-- janela de validade, etc.) ficam na camada intermediate, pra esse estado atual
-- continuar reutilizável caso outra métrica precise dele depois.

with ranked as (
    select
        *,
        row_number() over (
            partition by workload_id
            order by source_updated_at desc, ingested_at desc, event_id desc
        ) as rn
    from {{ ref('raw_prescription_workloads') }}
),

current_state as (
    select *
    from ranked
    where rn = 1
)

select
    workload_id,
    child_id,
    discipline_id,
    valid_from,
    valid_to,
    prescribed_hours_per_week,
    status,
    source_updated_at,
    op
from current_state
where op != 'D'
