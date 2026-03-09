# Caso 1 – Template factory para lambdas

## ¿De qué trata?

La idea es tener una forma rápida de crear lambdas nuevas sin que cada quien lo haga diferente. Si alguien del equipo necesita una lambda, en lugar de crearla a mano desde la consola con configuraciones distintas cada vez, ejecuta un comando y listo: sale con Python 3.13, arm64, el IAM role mínimo necesario y logs configurados.

Hay tres formas de usarlo según el contexto:

- **Makefile** – para uso local rápido (`make deploy NAME=mi-lambda`)
- **Terraform** – para entornos más formales donde el estado importa
- **GitHub Actions** – cuando el equipo quiere que todo pase por el pipeline

## Estructura

```
case-1-lambda-template/
├── template/
│   ├── src/lambda_function.py   # el código base que se despliega
│   ├── tests/test_lambda.py
│   ├── requirements.txt
│   └── pyproject.toml
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/lambda/          # módulo reutilizable
└── Makefile
```

## Recursos que se crean

- IAM Role con solo `AWSLambdaBasicExecutionRole` (nada más)
- CloudWatch Log Group con retención configurable
- Lambda Function: Python 3.13, arm64, memoria y timeout ajustables

## Por qué arm64

Graviton2 cuesta aprox. 20% menos que x86 para el mismo workload en Lambda. Para código Python puro no hay ningún cambio necesario.

## Cómo ejecutarlo

### Con Makefile
```bash
cd case-1-lambda-template

make deploy NAME=mi-lambda              # dev por default
make deploy NAME=mi-lambda ENV=prod MEMORY=256
make destroy NAME=mi-lambda
```

### Con Terraform
```bash
cd case-1-lambda-template/terraform
terraform init
terraform apply -var="lambda_name=mi-lambda" -var="environment=dev"
```

### Con GitHub Actions
Push a `main` dispara el pipeline automáticamente. También se puede ejecutar manualmente desde Actions con el nombre de la lambda como input.

Los secrets necesarios en el repo: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`.
