.PHONY: deploy destroy test lint help

NAME    ?= cloud-test-envioclick
ENV     ?= dev
REGION  ?= us-east-1
MEMORY  ?= 128
TIMEOUT ?= 30

help:
	@echo "Uso:"
	@echo "  make deploy NAME=mi-lambda [ENV=dev] [MEMORY=128] [TIMEOUT=30]"
	@echo "  make destroy NAME=mi-lambda [ENV=dev]"
	@echo "  make test"
	@echo "  make lint"

test:
	cd template && pip install -r requirements.txt -q
	python -m pytest case-1-lambda-template/template/tests/ -v

lint:
	pip install ruff -q
	ruff check case-1-lambda-template/template/src/

deploy:
	@echo "Desplegando $(NAME) en $(ENV)..."
	cd terraform && \
		terraform init -input=false -reconfigure && \
		terraform apply -auto-approve \
			-var="lambda_name=$(NAME)" \
			-var="environment=$(ENV)" \
			-var="aws_region=$(REGION)" \
			-var="memory_size=$(MEMORY)" \
			-var="timeout=$(TIMEOUT)"

destroy:
	@echo "Eliminando $(NAME) en $(ENV)..."
	cd terraform && terraform destroy -auto-approve \
		-var="lambda_name=$(NAME)" \
		-var="environment=$(ENV)"
