<#
.SYNOPSIS
    "make para Windows" — replica os alvos do Makefile usando PowerShell.

.DESCRIPTION
    O Makefile do projeto usa comandos Unix (make, source .venv/bin/activate)
    que nao rodam nativamente no Windows. Este script faz exatamente o mesmo
    fluxo com os equivalentes do PowerShell.

    Cada alvo do Makefile vira um parametro aqui.

.PARAMETER Task
    Qual etapa rodar:
      check   - valida pre-requisitos (python, pip)
      setup   - cria .venv, instala dependencias, cria pastas db/target/logs
      debug   - dbt debug (valida profile e conexao)
      seed    - dbt seed (carrega os CSVs no SQLite)
      run     - dbt run (executa apenas os models)
      build   - dbt build (seed + run + test no fluxo do dbt)
      test    - dbt test (executa apenas os testes)
      all     - fluxo completo: setup -> debug -> seed -> build -> test
      clean   - remove .venv, db, target, logs
      show    - mostra amostras da tabela final (sanity check)

.EXAMPLE
    .\make.ps1 all
    .\make.ps1 build
    .\make.ps1 test
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet('check', 'setup', 'debug', 'seed', 'run', 'build', 'test', 'all', 'clean', 'show', 'help')]
    [string]$Task = 'help'
)

$ErrorActionPreference = 'Stop'

# Sempre opera a partir da pasta onde o script esta.
Set-Location -Path $PSScriptRoot

# Caminhos do venv no Windows.
$VenvPython = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
$VenvDbt    = Join-Path $PSScriptRoot '.venv\Scripts\dbt.exe'

function Write-Step($msg) {
    Write-Host ""
    Write-Host ">>> $msg" -ForegroundColor Cyan
}

function Assert-Venv {
    if (-not (Test-Path $VenvDbt)) {
        Write-Host "Ambiente nao encontrado. Rode primeiro:  .\make.ps1 setup" -ForegroundColor Yellow
        exit 1
    }
    # dbt usa o profiles.yml da pasta atual.
    $env:DBT_PROFILES_DIR = "."
}

function Invoke-Check {
    Write-Step "Validando pre-requisitos..."
    python --version
    python -m pip --version
    $py = Get-CompatiblePython
    if ($py) {
        Write-Host "Interpretador compativel encontrado: $($py -join ' ')" -ForegroundColor Green
    } else {
        Write-Host "AVISO: nenhum Python 3.11/3.12 encontrado. dbt nao roda em 3.13+." -ForegroundColor Yellow
    }
    Write-Host "OK" -ForegroundColor Green
}

# dbt-core NAO suporta Python 3.13/3.14 de forma estavel (erro no mashumaro).
# Forcamos 3.12 (ou 3.11) na criacao do venv. Procuramos um interpretador
# compativel via py launcher; se nao houver, abortamos com instrucao clara.
function Get-CompatiblePython {
    foreach ($v in @('3.12', '3.11')) {
        try {
            $out = & py "-$v" --version 2>$null
            if ($LASTEXITCODE -eq 0 -and $out) { return @('py', "-$v") }
        } catch { }
    }
    # Fallback: talvez 'python' ja seja 3.11/3.12.
    try {
        $ver = & python -c "import sys; print('%d.%d' % sys.version_info[:2])" 2>$null
        if ($ver -in @('3.11', '3.12')) { return @('python') }
    } catch { }
    return $null
}

function Invoke-Setup {
    Write-Step "Criando .venv e instalando dependencias..."

    $py = Get-CompatiblePython
    if (-not $py) {
        Write-Host ""
        Write-Host "ERRO: nao encontrei Python 3.11 ou 3.12 instalado." -ForegroundColor Red
        Write-Host "O dbt-core nao roda de forma estavel em Python 3.13+." -ForegroundColor Yellow
        Write-Host "Instale o Python 3.12 (marque 'Add to PATH') e rode de novo:" -ForegroundColor Yellow
        Write-Host "  https://www.python.org/downloads/windows/" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "Usando interpretador: $($py -join ' ')" -ForegroundColor Green
    & $py[0] $py[1..($py.Length - 1)] -m venv .venv

    # Confirma a versao DENTRO do venv (tem que ser 3.11/3.12).
    $venvVer = & $VenvPython -c "import sys; print('%d.%d' % sys.version_info[:2])"
    Write-Host "Python do venv: $venvVer" -ForegroundColor Green
    if ($venvVer -notin @('3.11', '3.12')) {
        Write-Host "ERRO: o venv foi criado com Python $venvVer (incompativel)." -ForegroundColor Red
        Write-Host "Rode '.\make.ps1 clean' e garanta que 'py -3.12' funciona." -ForegroundColor Yellow
        exit 1
    }

    & $VenvPython -m pip install --upgrade pip
    & $VenvPython -m pip install -r requirements.txt
    New-Item -ItemType Directory -Force -Path db, target, logs | Out-Null
    Write-Host "Setup concluido." -ForegroundColor Green
}

function Invoke-Debug { Assert-Venv; Write-Step "dbt debug";  & $VenvDbt debug }
function Invoke-Seed  { Assert-Venv; Write-Step "dbt seed";   & $VenvDbt seed }
function Invoke-Run   { Assert-Venv; Write-Step "dbt run";    & $VenvDbt run }
function Invoke-Build { Assert-Venv; Write-Step "dbt build";  & $VenvDbt build }
function Invoke-Test  { Assert-Venv; Write-Step "dbt test";   & $VenvDbt test }

function Invoke-All {
    Invoke-Setup
    Invoke-Debug
    Invoke-Seed
    Invoke-Build
    Invoke-Test
    Write-Host ""
    Write-Host "Fluxo completo concluido com sucesso." -ForegroundColor Green
}

function Invoke-Clean {
    Write-Step "Removendo .venv, db, target, logs..."
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue .venv, db, target, logs
    Write-Host "Limpo." -ForegroundColor Green
}

function Invoke-Show {
    Write-Step "Amostra da tabela final fct_daily_scheduling_rate"
    $code = @"
import sqlite3
c = sqlite3.connect('db/scheduling_case.db')
print('--- contagem por coverage_flag ---')
for r in c.execute('select coverage_flag, count(*) from fct_daily_scheduling_rate group by coverage_flag'):
    print('  ', r)
print('--- 10 linhas matched ---')
cols = 'child_id discipline_id date_day weekday scheduled_hours_day prescribed_hours_daily_target daily_scheduling_rate weekly_scheduling_rate'.split()
print('  ', ' | '.join(cols))
q = '''select child_id, discipline_id, date_day, weekday, scheduled_hours_day,
        prescribed_hours_daily_target, daily_scheduling_rate, weekly_scheduling_rate
        from fct_daily_scheduling_rate where coverage_flag = 'matched' limit 10'''
for r in c.execute(q):
    print('  ', ' | '.join(str(x) for x in r))
"@
    & $VenvPython -c $code
}

function Invoke-Help {
    Write-Host "make.ps1 - 'make para Windows'"
    Write-Host ""
    Write-Host "Uso:  .\make.ps1 <tarefa>"
    Write-Host ""
    Write-Host "Tarefas:"
    Write-Host "  check   valida pre-requisitos (python 3.11/3.12, pip)"
    Write-Host "  setup   cria .venv (forcando Python 3.12) e instala dependencias"
    Write-Host "  debug   valida profile e conexao do dbt"
    Write-Host "  seed    carrega os CSVs de seeds no SQLite"
    Write-Host "  run     executa apenas os models"
    Write-Host "  build   executa seed + run + test"
    Write-Host "  test    executa apenas os testes"
    Write-Host "  all     fluxo completo (setup->debug->seed->build->test)"
    Write-Host "  clean   remove .venv, db, target, logs"
    Write-Host "  show    mostra amostras da tabela final"
    Write-Host ""
    Write-Host "Exemplos:"
    Write-Host "  .\make.ps1 all"
    Write-Host "  .\make.ps1 build"
    Write-Host "  .\make.ps1 test"
}

switch ($Task) {
    'check' { Invoke-Check }
    'setup' { Invoke-Setup }
    'debug' { Invoke-Debug }
    'seed'  { Invoke-Seed }
    'run'   { Invoke-Run }
    'build' { Invoke-Build }
    'test'  { Invoke-Test }
    'all'   { Invoke-All }
    'clean' { Invoke-Clean }
    'show'  { Invoke-Show }
    default { Invoke-Help }
}
