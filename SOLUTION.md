# Solução — Taxa de Agendamento Diária

> Este documento complementa o `README.md` original. Aqui eu registro como pensei
> a arquitetura, as decisões de modelagem e os trade-offs que assumi. A pipeline
> inteira roda fim a fim em SQLite via dbt (`make all` / `make build` / `make test`).

## Resumo

Montei a pipeline em camadas (`raw → staging → intermediate → marts`). No fim ela
entrega a tabela **`fct_daily_scheduling_rate`**, no grain
**`(child_id, discipline_id, date_day)`**, que responde:

> Para cada criança, disciplina e dia, qual a taxa de agendamento em relação à
> carga horária prescrita validada?

Um `dbt build` roda 4 seeds, 14 models e 53 testes — todos passando.

## Arquitetura em camadas

```
raw/            (já vinha pronto) normalização de tipos dos eventos CDC
  raw_children, raw_disciplines, raw_prescription_workloads, raw_weekly_schedules

staging/        ESTADO ATUAL via deduplicação de CDC (1 linha por entidade)
  stg_children, stg_disciplines, stg_prescription_workloads, stg_weekly_schedules

intermediate/   regras de negócio + validade temporal + distribuição diária
  int_valid_workloads             (só status 'validated')
  int_active_schedules            (só status 'active')
  int_calendar                    (date spine recursivo)
  int_scheduled_sessions_daily    (expande a agenda semanal -> dias concretos)
  int_prescribed_daily_target     (distribui a prescrição semanal -> meta diária)

marts/          métrica final
  fct_daily_scheduling_rate       grain (criança, disciplina, dia)
```

A divisão de responsabilidades que eu segui: a **staging** só responde "qual a
versão atual de cada linha" — sem nenhuma regra de negócio, pra ficar reutilizável.
A **intermediate** é onde entram status, validade e a distribuição diária. E a
**marts** só junta as pontas e calcula a métrica.

## Decisões e premissas (respostas às perguntas do case)

### 1. Como calculei a `scheduling_rate` e o que assumi
Resolvi expor a métrica em **duas resoluções** na mesma tabela, porque o case dá
uma definição semanal mas pede um grain diário:
- **Semanal** (a definição base do README): `weekly_scheduling_rate =
  scheduled_hours_week / prescribed_hours_per_week`. Carrego esse valor em cada
  linha diária pra dar pra ler o dia contra a meta da semana.
- **Diária**: `daily_scheduling_rate = scheduled_hours_day /
  prescribed_hours_daily_target`, que casa com o grain diário pedido.

Premissas: só conto prescrições `validated` e agendas `active`; as horas precisam
ser positivas; e a ligação entre workload e schedule é por `child_id + discipline_id`.

### 2. Qual o grain da tabela final
`(child_id, discipline_id, date_day)` — uma linha por criança, disciplina e dia.
Isso é garantido por um teste (`assert_fct_daily_grain_is_unique`).

### 3. Como transformei a prescrição semanal em meta diária
Distribuí de forma **uniforme pelos 5 dias úteis**: `prescribed_hours_per_week / 5`
em dia útil, e `0` no fim de semana. Como a origem não diz em que dia a prescrição
"cai", qualquer divisão é uma premissa minha — escolhi a mais simples de defender,
que ainda tem a vantagem de fazer a soma das metas diárias na semana bater
exatamente com a prescrição semanal.

### 4. Fim de semana entra na métrica?
No denominador prescrito, não — a meta diária de sábado e domingo é 0. Mas se uma
agenda `active` cair no fim de semana, as horas dela ainda contam como agendadas.
Isso faz a taxa do dia ficar nula ou acima de 1 no fim de semana, e foi de
propósito: prefiro deixar essa atividade visível (com a flag `is_weekend`) a
escondê-la.

### 5. Como trato schedules `cancelled`/`paused`
Tiro os dois em `int_active_schedules` (fica só `active`). A pausada eu considero
que não gera sessão enquanto está pausada. Tem um teste
(`assert_only_active_schedules_contribute`) garantindo que nada fora de `active`
vaza pra métrica.

### 6. Como trato workloads `draft`/`cancelled`
Tiro em `int_valid_workloads` (fica só `validated`). A `draft` ainda não foi
aprovada clinicamente, e a `cancelled` foi revogada — nenhuma das duas representa
uma prescrição que vale.

### 7. CDC duplicado e updates posteriores
Na staging eu uso `row_number()` particionando pela chave de negócio de cada
entidade (`child_id`/`discipline_id`/`workload_id`/`schedule_id`) e ordenando por
`source_updated_at desc, ingested_at desc, event_id desc`. Fico com `rn = 1`, ou
seja, só a versão mais recente — é assim que os updates tardios são absorvidos.

### 8. Como trato deletes
Depois de escolher o evento mais recente de cada entidade, eu descarto a linha se
esse último evento for `op = 'D'`. Assim um delete que chega atrasado remove a
entidade do estado atual. Como a ordenação é temporal, um delete seguido de um
re-insert (cenário improvável aqui) também seria respeitado na ordem certa.

Além disso, garanto **integridade referencial**: na camada intermediate eu faço
`inner join` das workloads/schedules com o estado atual de criança e disciplina.
Então, se uma disciplina ou criança foi deletada (some do estado atual), as
prescrições e agendas dela também saem da métrica — senão eu estaria contando uma
entidade que não existe mais. (Isso surgiu de um gap que eu mesmo encontrei: a
disciplina `to` tinha sido deletada via CDC mas continuava aparecendo no fato.
Ver "Achado: integridade referencial" abaixo.) Um teste
(`assert_fct_has_no_orphan_entities`) garante que não sobra entidade órfã no fato.

### 9. Quais testes adicionei e por quê
- Unicidade da chave de negócio na staging — pra provar que a dedup realmente
  colapsou tudo pra uma linha por entidade.
- `accepted_values` de status nas camadas staging.
- Grain único no fato final (`assert_fct_daily_grain_is_unique`).
- Métrica sã: taxa nunca negativa e prescrição sempre positiva
  (`assert_scheduling_rate_is_valid`).
- Integridade do filtro de status: nenhuma agenda fora de `active` contribui horas
  (`assert_only_active_schedules_contribute`).
- Integridade referencial: nenhuma criança/disciplina deletada sobra no fato
  (`assert_fct_has_no_orphan_entities`).
- `accepted_values` na `coverage_flag`.

### 10. O que eu faria com mais tempo
- Deixar a janela do calendário e o divisor da distribuição (5 vs. dias com agenda
  vs. 7) configuráveis via `var()` do dbt, em vez de cravados no SQL.
- Modelar a alternativa "prescrição distribuída só nos dias que têm agenda" como
  um segundo denominador, pra comparar as duas abordagens lado a lado.
- Adicionar testes de `relationships` nativos do dbt-utils (hoje a integridade
  referencial é garantida por inner join + um teste singular) e algo de
  volume/freshness.
- Documentar a métrica com `dbt docs` e exposures.
- Fixar versões no `requirements.txt` (`dbt-core==1.11.*`) e a versão do Python
  (`.python-version` ou container) pra travar a reprodutibilidade do ambiente.

### 11. Usei IA?
Usei, sim. Apoiei-me em IA (Claude) pra acelerar a escrita dos models SQL, a
estrutura das camadas, os testes e esta documentação. Pra validar, eu não confiei
só no que saiu: rodei o `dbt build` inteiro (70/70 passando), abri o SQLite e
conferi o resultado na mão — grain único, a distribuição das `coverage_flag`,
amostras de linhas `matched`, e que não havia taxa negativa — além de bater a
dedup de CDC contra a contagem de IDs distintos.

## Trade-offs de ambiente (setup local)

Dois pontos de ambiente que afetam a reprodutibilidade e vale deixar registrado.

### Versão do Python (o dbt-core não roda em 3.13+)
O `dbt-core` ainda não roda de forma estável em Python 3.13/3.14. No 3.13, o dbt
nem inicializa: estoura um traceback dentro do `mashumaro`
(`mashumaro/core/meta/code/builder.py`, em `add_unpack_method`), que é uma
dependência interna de serialização do dbt. É a defasagem do ecossistema do dbt em
relação às versões mais novas do Python — o suporte oficial vai até 3.11/3.12.

**Decisão:** fixei o ambiente em **Python 3.12**. O `requirements.txt` declara só
`dbt-core` e `dbt-sqlite` (sem versão travada), então quem for rodar precisa
garantir o interpretador certo — senão a instalação até passa, mas o `dbt debug`
quebra logo na importação.

**Trade-off:** não travei as versões das libs no `requirements.txt` pra manter o
starter simples e igual ao que veio no repositório. Em produção eu pinaria
`dbt-core==1.11.*` e a versão do Python (via `.python-version`, `tool.uv` ou um
container) pra não depender da máquina de quem roda. Documentar a versão do Python
é o mínimo que dava pra fazer aqui.

### "Make" no Windows
O `Makefile` do repositório usa comandos Unix (`make`, `source .venv/bin/activate`)
que não rodam direto no Windows/PowerShell. Pra conseguir rodar no Windows sem WSL,
incluí um **`make.ps1`** — um "make para Windows" que replica cada alvo (`setup`,
`debug`, `seed`, `run`, `build`, `test`, `all`, `clean`, `show`). O `setup` dele
força o Python 3.12 (procura `py -3.12`/`py -3.11`) e aborta com mensagem clara se
só achar 3.13+, justamente pra evitar o erro acima. No macOS/Linux o `Makefile`
original continua funcionando normalmente.

## Achado: integridade referencial (gap que eu mesmo encontrei e corrigi)
Explorando os dados pra montar perguntas de negócio, percebi que a disciplina `to`
tinha sido **deletada** via CDC (`op = 'D'`) e mesmo assim continuava no fato — eu
filtrava workloads e schedules, mas não cruzava com a dimensão de criança/disciplina.
Havia também crianças deletadas ainda presentes.

Corrigi na camada intermediate com `inner join` contra `stg_children`/
`stg_disciplines`, e adicionei o teste `assert_fct_has_no_orphan_entities`. O fato
saiu de ~11.9k pra ~9.1k linhas (saíram as da disciplina e das crianças deletadas).

Deixei de propósito **fora** o filtro por `is_active = 1` (disciplina/criança
apenas desativada, não deletada): isso é uma regra de negócio a confirmar com a
área, não um bug. O hook está documentado no código pra ligar em uma linha se
confirmarem. Ver detalhe em `PERGUNTAS_NEGOCIO.md`.

## Tratamento das bordas (o FULL OUTER JOIN)
O fato usa `FULL OUTER JOIN` entre a prescrição-diária e a agenda-diária, e
classifica cada linha com a `coverage_flag`:
- `matched` — tem prescrição validada e tem agenda.
- `scheduled_without_prescription` — agendou, mas não há workload validada (lado
  prescrito vem nulo).
- `prescribed_without_schedule` — tem prescrição validada, mas nenhuma hora
  agendada.

## Como rodar

> Precisa de **Python 3.11 ou 3.12** (o dbt-core não roda em 3.13+). Ver
> "Trade-offs de ambiente" acima.

**macOS / Linux** (Makefile original):
```bash
make all      # setup -> debug -> seed -> build -> test
# ou
make build && make test
```

**Windows / PowerShell** (via `make.ps1`):
```powershell
.\make.ps1 all      # setup (força Python 3.12) -> debug -> seed -> build -> test
# ou etapas individuais:
.\make.ps1 build
.\make.ps1 test
.\make.ps1 show     # amostras da tabela final
```
