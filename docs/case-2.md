# Caso 2 – Pipeline multi-ambiente con aliases

El pipeline maneja tres ambientes (dev, staging, prod) para la misma lambda. Cada ambiente tiene sus propias variables de entorno definidas en `src/{ambiente}.env.json`.

Para el rollback uso versiones y aliases de Lambda. En Azure esto equivale a los deployment slots, solo que aquí el mecanismo es diferente: cada deploy publica una versión inmutable numerada, y el alias apunta a la versión que se quiera. Para hacer rollback solo se mueve el alias a una versión anterior, sin redesplegar código.

```
alias prod → Version 5   (deploy de hoy)
alias prod → Version 4   (rollback, tarda segundos)
```

El flujo es: push a `develop` → actualiza alias dev, push a `staging` → publica versión y actualiza alias staging, tag `v*` → requiere aprobación manual → actualiza alias prod.

Referencia: [Lambda function aliases – AWS docs](https://docs.aws.amazon.com/lambda/latest/dg/configuration-aliases.html)
