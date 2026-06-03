# Guia do Candidato

Este guia complementa o README principal e ajuda você a estruturar a solução com clareza.

## Objetivo prático
A partir da camada `raw`, construir uma saída analítica que permita medir a taxa de agendamento por criança e disciplina.

Definição base da taxa:

`scheduling_rate = horas semanais agendadas da disciplina / horas semanais prescritas da disciplina`

## O que você precisa entregar
- Uma arquitetura de transformação coerente (camadas, modelos e grain).
- Uma tabela/view final com a métrica.
- Testes de dados relevantes.
- Documentação das premissas e trade-offs.

## Sugestão de abordagem (passo a passo)
1. Entenda a camada raw como CDC: múltiplos eventos por entidade, `op` com `I/U/D`, updates e deletes.
2. Defina estado atual por entidade (ou visão temporal) de forma explícita.
3. Trate status e validade temporal de workloads e schedules.
4. Converta agenda semanal em horas semanais agendadas por disciplina.
5. Relacione com horas prescritas por disciplina e calcule a taxa.
6. Defina como obter a visão diária (quando aplicável ao seu grain final).
7. Cubra os principais riscos com testes.

## Pontos de decisão que serão avaliados
- Como você deduplica eventos CDC.
- Como trata `op = D`.
- Como trata status (`draft`, `validated`, `cancelled`, `active`, `paused`).
- Como trata janelas de validade (`valid_from`, `valid_to`).
- Como evita dupla contagem de horários.
- Como define e comunica o grain final.

## Checklist de qualidade antes de finalizar
- `make debug` passa.
- `make seed` passa.
- `make build` passa.
- `make test` passa.
- README final explica decisões, limitações e melhorias futuras.
