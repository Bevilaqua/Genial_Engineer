# Dicionário da Camada Raw

Este documento descreve as tabelas raw, seus conceitos, colunas, valores esperados e relacionamentos.

## Visão geral
A camada raw representa eventos CDC sem curadoria de negócio final.

- Mantém histórico de eventos.
- Não deduplica definitivamente entidades.
- Preserva inserts, updates e deletes.

## Convenções comuns
Todas as tabelas raw possuem colunas técnicas de CDC:

- `event_id`: identificador único do evento CDC.
- `op`: tipo do evento (`I`, `U`, `D`).
- `source_updated_at`: timestamp da atualização no sistema de origem.
- `ingested_at`: timestamp de ingestão no lake/raw.

### Valores padrão esperados (campos técnicos)
- `op`: `I`, `U`, `D`
- Ordenação temporal sugerida: `source_updated_at`, com desempate por `ingested_at`

---

## Tabela: `raw_children`
Entidade de crianças por evento CDC.

### Colunas
- `event_id` (texto): id único do evento.
- `op` (texto): `I`, `U`, `D`.
- `source_updated_at` (datetime): atualização na origem.
- `ingested_at` (datetime): ingestão no raw.
- `child_id` (texto): identificador da criança.
- `child_name` (texto): nome da criança.
- `tenant_id` (texto): organização/tenant.
- `is_active` (inteiro 0/1): flag normalizada no model raw.

### Valores padrão
- `is_active`: `1` para ativo, `0` para inativo.

---

## Tabela: `raw_disciplines`
Cadastro de disciplinas por evento CDC.

### Colunas
- `event_id` (texto)
- `op` (texto): `I`, `U`, `D`
- `source_updated_at` (datetime)
- `ingested_at` (datetime)
- `discipline_id` (texto): id da disciplina (ex.: `aba`, `fono`, `to`, `psico`, `psicoped`).
- `discipline_name` (texto)
- `is_active` (inteiro 0/1)

### Valores padrão
- `is_active`: `1`/`0`.

---

## Tabela: `raw_prescription_workloads`
Prescrições clínicas de carga horária semanal por criança e disciplina.

### Colunas
- `event_id` (texto)
- `op` (texto): `I`, `U`, `D`
- `source_updated_at` (datetime)
- `ingested_at` (datetime)
- `workload_id` (texto): identificador da workload.
- `child_id` (texto)
- `discipline_id` (texto)
- `valid_from` (date): início da validade.
- `valid_to` (date): fim da validade.
- `prescribed_hours_per_week` (numérico): horas prescritas por semana.
- `status` (texto): `draft`, `validated`, `cancelled`.

### Valores padrão
- `status`: um de `draft`, `validated`, `cancelled`.
- `prescribed_hours_per_week`: número positivo (regra de qualidade recomendada na camada analítica).

---

## Tabela: `raw_weekly_schedules`
Agendas semanais recorrentes por criança e disciplina.

### Colunas
- `event_id` (texto)
- `op` (texto): `I`, `U`, `D`
- `source_updated_at` (datetime)
- `ingested_at` (datetime)
- `schedule_id` (texto): identificador do agendamento recorrente.
- `child_id` (texto)
- `discipline_id` (texto)
- `weekday` (texto): `monday` ... `sunday`.
- `start_time` (texto HH:MM)
- `end_time` (texto HH:MM)
- `valid_from` (date)
- `valid_to` (date)
- `status` (texto): `active`, `cancelled`, `paused`.
- `scheduled_hours` (numérico): derivado técnico da diferença `end_time - start_time` em horas.

### Valores padrão
- `weekday`: `monday`, `tuesday`, `wednesday`, `thursday`, `friday`, `saturday`, `sunday`.
- `status`: `active`, `cancelled`, `paused`.
- `scheduled_hours`: decimal (ex.: 0.75 para 45 minutos).

---

## Relacionamentos lógicos
A camada raw não impõe FKs físicas, mas as relações de negócio esperadas são:

- `raw_prescription_workloads.child_id` -> `raw_children.child_id`
- `raw_prescription_workloads.discipline_id` -> `raw_disciplines.discipline_id`
- `raw_weekly_schedules.child_id` -> `raw_children.child_id`
- `raw_weekly_schedules.discipline_id` -> `raw_disciplines.discipline_id`

Relacionamento principal da métrica:

- workload e schedule se relacionam por `child_id + discipline_id`, considerando status e validade temporal.

## Observações importantes para modelagem
- Pode haver múltiplos eventos por `child_id`, `discipline_id`, `workload_id` e `schedule_id`.
- `op = D` representa delete lógico via evento CDC.
- Eventos tardios podem alterar estado histórico e atual.
- Decisões de deduplicação e “estado corrente” devem ser documentadas.
