# Case Técnico — Engenheiro de Dados

## Pré-requisitos

Antes de começar, garanta que você tenha:

- Python 3.10+ instalado;
- `make` disponível no terminal;
- ambiente local macOS/Linux (ou equivalente com suporte a `venv`).

Dependências Python usadas no projeto:

- `dbt-core`
- `dbt-sqlite`

## Contexto

Este repositório simula uma primeira camada raw de um data lake, alimentada por eventos CDC de um sistema transacional.
Os dados representam crianças, disciplinas, prescrições de carga horária por disciplina e agendas semanais recorrentes.
A Genial precisa construir uma métrica de taxa de agendamento diária por criança e disciplina.

## Objetivo

Construir uma pipeline analítica local usando dbt + SQLite.
A tabela final deve permitir responder:

> Para cada criança, disciplina e dia, qual é a taxa de agendamento em relação à carga horária prescrita validada?

Definição base esperada para a métrica:

> `scheduling_rate = horas semanais agendadas da disciplina / horas semanais prescritas da disciplina`

Ou seja, a taxa compara o que foi agendado na semana para uma disciplina com a prescrição clínica semanal da mesma disciplina.

As regras de implementação (validade temporal, status, deduplicação CDC, distribuição diária e grain final) continuam parte do exercício.
Queremos avaliar clareza de modelagem, arquitetura, testes, SQL e comunicação de trade-offs.

## Expectativas da avaliação

O uso de IA é permitido.
Pedimos transparência para informar onde você usou IA.

Para avaliação, esperamos:

- código funcional rodando fim a fim no ambiente local;
- comandos principais passando (`make debug`, `make seed`, `make build`, `make test`);
- capacidade de explicar, na conversa síncrona, o que foi implementado;
- clareza sobre os trade-offs das decisões tomadas;
- justificativa do modelo arquitetural escolhido para resolver o problema.
- investimento de tempo de até 3 horas. Se não der tempo de concluir tudo, documente no README o que você priorizou, as decisões tomadas, até onde implementou e o que faria com mais tempo.

## Como rodar

Fluxo recomendado (um comando):

```bash
make all
```

Fluxo passo a passo:

```bash
make setup
make debug
make seed
make build
make test
```

Para ver os comandos com descrição:

```bash
make help
```

Para validar pré-requisitos antes da instalação:

```bash
make check
```

## Documentação de apoio

- Guia prático para conduzir a solução: [docs/guia-do-candidato.md](docs/guia-do-candidato.md)
- Dicionário da camada raw (conceitos, colunas, padrões e relacionamentos): [docs/raw-data-dictionary.md](docs/raw-data-dictionary.md)

## O que já está pronto

Este repositório contém:

- setup local com dbt + SQLite;
- seeds simulando eventos CDC;
- camada inicial `models/raw/`;
- testes básicos de exemplo.

## O que NÃO está pronto

Este repositório não entrega:

- definiar as camadas de transformação além da raw;
- tabela final da métrica;
- definição fechada de `scheduling_rate`.

Essas decisões fazem parte do exercício.

## O que você deve fazer

Você deve propor a arquitetura de transformação a partir da camada raw.

O importante é documentar suas decisões.

A entrega final deve conter uma tabela ou view que permita analisar a taxa de agendamento diária por criança e disciplina.

## Regras e pontos de atenção

Considere que:

- os dados raw simulam CDC;
- podem existir múltiplos eventos para a mesma entidade;
- eventos com `op = D` representam deleção;
- workloads possuem status;
- schedules possuem status;
- workloads e schedules possuem validade temporal;
- schedules são semanais por dia da semana e horário;
- workloads são prescrições semanais por criança e disciplina.

Você deve decidir e documentar:

- como obter o estado atual das entidades;
- como tratar updates posteriores;
- como tratar deletes;
- como tratar workloads `draft` ou `cancelled`;
- como tratar schedules `cancelled` ou `paused`;
- como distribuir uma carga horária semanal em uma meta diária;
- se fins de semana entram ou não;
- como lidar com schedule sem workload validada;
- como lidar com workload validada sem schedule;
- qual é o grain final.

## Dica: geração de calendário em SQLite

Não existe uma tabela de calendário pronta.

Se precisar expandir datas, você pode usar uma CTE recursiva em SQLite.

Exemplo:

```sql
with recursive calendar(date_day) as (
  select date('2026-05-01')
  union all
  select date(date_day, '+1 day')
  from calendar
  where date_day < date('2026-05-31')
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
  end as weekday
from calendar
```

## Decisões e premissas

Vamos avaliar as decisões tomadas e a clareza na comunicação das mesmas na conversa sincrona.

1. Como você implementou o cálculo de `scheduling_rate` (horas semanais agendadas / horas semanais prescritas) e quais premissas adotou?
2. Qual é o grain da tabela final?
3. Como você transformou uma prescrição semanal em uma meta diária?
4. Fins de semana entram na métrica?
5. Como schedules cancelados ou pausados são tratados?
6. Como workloads em `draft` ou `cancelled` são tratados?
7. Como eventos CDC duplicados ou atualizações posteriores são tratados?
8. Como deletes são tratados?
9. Quais testes você adicionou e por quê?
10. O que você melhoraria se tivesse mais tempo?
11. Você usou IA? Se sim, onde usou e como validou?

## Critérios de avaliação

| Critério                           |
| ---------------------------------- |
| Clareza da definição da métrica    |
| Arquitetura em camadas             |
| Correção SQL e tratamento temporal |
| Tratamento de CDC/deduplicação     |
| Testes de dados/unitários          |
| README, trade-offs e comunicação   |

## Restrições

- Não usar serviços externos.
- Não depender de BigQuery, Dataform, Postgres ou Docker obrigatório.
- A solução deve rodar localmente com SQLite.
- O tempo esperado é de 2 a 3 horas.
- O tempo que você deve investir nesse challenge não deveria ser de mais de 3 horas.
- Caso passe disso e você não tenha tempo de fazer tudo, escreva no README as considerações do que você faria se tivesse mais tempo.
- O uso de IA é permitido, mas seria interessante nos informar onde você usou.

## Regenerando os seeds (opcional)

Os seeds já estão versionados no repositório.
Se quiser regenerar dados sintéticos:

```bash
python scripts/generate_seed_data.py
```

> Observação: o script acima é opcional e não é necessário para rodar o case.

## Troubleshooting rápido

- Se `make setup` falhar por versão do Python, use Python 3.10+ e tente novamente.
- Se `dbt debug` falhar, rode `make clean` e depois `make setup`.
- Se algo ficar inconsistente no ambiente local, rode:

```bash
make clean
make all
```

## Conformidade com práticas de dbt

Este starter segue práticas recomendadas de dbt, mantendo o escopo do desafio propositalmente aberto:

- `profile` do projeto alinhado com `profiles.yml` local e execução via `DBT_PROFILES_DIR=.`.
- Testes de dados em `schema.yml` + teste singular em `tests/`, com semântica de “retornar linhas inválidas”.
- Uso de testes genéricos nativos (`not_null`, `unique`, `accepted_values`) e `accepted_values` no formato `arguments` (compatível com versões atuais do dbt).
- Separação clara entre camada raw inicial e camadas analíticas futuras, sem antecipar regras de negócio da métrica.
