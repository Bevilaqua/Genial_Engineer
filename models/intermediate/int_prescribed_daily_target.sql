-- Transforma a prescrição semanal numa meta diária.
--
-- A decisão de distribuição: espalho as horas semanais igualmente pelos 5 dias
-- úteis (segunda a sexta). Ou seja, meta do dia = prescribed_hours_per_week / 5
-- em dia útil, e 0 no fim de semana.
--
-- Por que assim (e o trade-off): a origem não diz em que dia da semana a
-- prescrição "cai", então qualquer divisão é uma premissa minha. O split
-- uniforme de segunda a sexta é o mais simples de defender e tem uma propriedade
-- boa: a soma das metas diárias na semana bate exatamente com a prescrição
-- semanal. Outras opções (dividir só pelos dias que têm agenda, ou pelos 7 dias)
-- estão comentadas no SOLUTION.md.
--
-- Fim de semana: fica fora do denominador (meta = 0). Mas uma agenda 'active' que
-- caia no sábado/domingo ainda soma horas agendadas -- isso faz a taxa do dia
-- ficar nula ou acima de 1 no fim de semana, o que é intencional: prefiro mostrar
-- a atividade de fim de semana batendo numa meta zero do que escondê-la.
--
-- Grain: uma linha por (workload, criança, disciplina, dia) dentro da validade.

select
    w.workload_id,
    w.child_id,
    w.discipline_id,
    c.date_day,
    c.weekday,
    c.is_weekend,
    w.prescribed_hours_per_week,
    case
        when c.is_weekend then 0.0
        else w.prescribed_hours_per_week / 5.0
    end as prescribed_hours_daily_target
from {{ ref('int_valid_workloads') }} as w
join {{ ref('int_calendar') }} as c
    on c.date_day >= w.valid_from
   and c.date_day <= w.valid_to
