# Caso 1 – Template para lambdas

La idea es estandarizar cómo se crean las lambdas para no tener configuraciones distintas en cada una. El template usa Python 3.13 con arm64 (Graviton2), que según la [documentación de Lambda](https://docs.aws.amazon.com/lambda/latest/dg/foundation-arch.html) cuesta 20% menos que x86 para el mismo workload sin cambios en el código Python.

La infraestructura se maneja con Terraform usando un módulo reutilizable en `terraform/modules/lambda/`. Cada nueva lambda solo pasa las variables necesarias al módulo en lugar de repetir la misma configuración.

Lo que crea el módulo:
- IAM Role con `AWSLambdaBasicExecutionRole`
- CloudWatch Log Group con retención configurable
- Lambda Function: Python 3.13, arm64, memoria y timeout configurables
