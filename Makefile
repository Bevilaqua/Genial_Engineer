.PHONY: help check setup debug seed run build test all clean

help:
	@echo "Comandos disponíveis:"
	@echo "  make check  - valida pré-requisitos locais (python, pip, make)"
	@echo "  make setup  - cria .venv e instala dependências"
	@echo "  make debug  - valida profile e conexão do dbt"
	@echo "  make seed   - carrega os CSVs de seeds no SQLite"
	@echo "  make run    - executa apenas os models"
	@echo "  make build  - executa seed + run + test no fluxo do dbt"
	@echo "  make test   - executa apenas os testes"
	@echo "  make all    - fluxo guiado recomendado (setup->debug->seed->build->test)"
	@echo "  make clean  - remove ambiente local (.venv, db, target, logs)"

check:
	@echo "Validando pré-requisitos..."
	@python3 --version
	@python3 -m pip --version
	@make --version | head -n 1

setup:
	python -m venv .venv
	. .venv/bin/activate && pip install --upgrade pip
	. .venv/bin/activate && pip install -r requirements.txt
	mkdir -p db target logs

debug:
	. .venv/bin/activate && DBT_PROFILES_DIR=. dbt debug

seed:
	. .venv/bin/activate && DBT_PROFILES_DIR=. dbt seed

run:
	. .venv/bin/activate && DBT_PROFILES_DIR=. dbt run

build:
	. .venv/bin/activate && DBT_PROFILES_DIR=. dbt build

test:
	. .venv/bin/activate && DBT_PROFILES_DIR=. dbt test

all:
	$(MAKE) setup
	$(MAKE) debug
	$(MAKE) seed
	$(MAKE) build
	$(MAKE) test

clean:
	rm -rf .venv db target logs
