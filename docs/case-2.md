# Caso 2 – Pipeline multi-ambiente con aliases

## ¿De qué trata?

El objetivo es poder subir cambios a una lambda con tres ambientes separados (dev, staging, prod) donde cada uno tiene sus propias variables de entorno (`redis_host`, `db_host`, etc.) y un mecanismo de rollback que no implique volver a desplegar código.

El truco para el rollback está en cómo funciona Lambda con versiones y aliases:

```
mi-lambda
  ├── $LATEST         → siempre el código más nuevo
  ├── Version 3       → snapshot del deploy de hoy
  ├── Version 2       → snapshot de ayer
  │
  ├── alias: dev     → apunta a $LATEST
  ├── alias: staging → apunta a Version 3
  └── alias: prod    → apunta a Version 2

Rollback = mover el alias prod a Version 1 (tarda ~3 segundos, sin redeploy)
```

Cada alias tiene su propio ARN estable. Lo que llama a prod siempre usa el mismo ARN aunque la versión detrás cambie.

## Variables de entorno por ambiente

Se manejan en archivos JSON dentro de `src/`:

```
src/
  dev.env.json
  staging.env.json
  prod.env.json
```

El pipeline lee el archivo correspondiente al ambiente y lo aplica con `update-function-configuration`.

## Flujo del pipeline

```
push a develop  → deploy automático → alias dev
push a staging  → deploy automático → publica versión → alias staging
tag v*.*.*       → requiere aprobación → publica versión → alias prod
                                              ↓
                                    smoke test post-deploy
                                    si falla → rollback automático
```

## Rollback manual

```bash
# ver versiones disponibles
aws lambda list-versions-by-function --function-name mi-lambda

# rollback prod a versión anterior
aws lambda update-alias \
  --function-name mi-lambda \
  --name prod \
  --function-version 2
```

O también se puede disparar desde el workflow con `action=rollback` y especificando el número de versión.

## Estructura

```
case-2-github-actions-lambda/
├── .github/workflows/deploy.yml
├── terraform/
│   ├── main.tf       # lambda + los 3 aliases
│   └── variables.tf
└── src/
    ├── dev.env.json
    ├── staging.env.json
    └── prod.env.json
```

## Cómo ejecutarlo

```bash
# infraestructura base (lambda + aliases)
cd case-2-github-actions-lambda/terraform
terraform init && terraform apply

# secrets en GitHub: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
# después el pipeline se encarga del resto
```
