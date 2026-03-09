# Caso 3 – CI/CD para Laravel + Vue

## Servicios recomendados

Para una app Laravel + Vue el stack que recomendaría en AWS es:

| Servicio | Para qué |
|----------|----------|
| **Elastic Beanstalk** | Servidor de la app. Maneja las instancias EC2, el balanceador y el auto-scaling. El rollback es nativo: un comando y regresa a la versión anterior. |
| **RDS** | Base de datos. No tiene sentido gestionar un servidor de Postgres a mano cuando RDS te da backups automáticos, failover y actualizaciones sin downtime. |
| **ElastiCache (Redis)** | Para las colas de Laravel, caché de sesiones y caché de respuestas. |
| **S3 + CloudFront** | Los assets compilados de Vue se suben a S3 y se sirven desde CloudFront. Así no se cargan desde el servidor PHP. |

**¿Por qué Elastic Beanstalk y no ECS?**

Para una app monolítica en PHP, EB es más simple de operar y el rollback funciona sin tener que gestionar task definitions ni registros de imágenes Docker. ECS tiene más sentido cuando hay múltiples servicios o se quiere mayor control sobre el runtime.

## Optimizaciones del pipeline

El punto más lento siempre es instalar dependencias. Estas dos cosas lo resuelven:

1. **Cache de Composer y npm** – si `composer.lock` o `package-lock.json` no cambiaron, se reutiliza lo que ya estaba instalado. Baja el tiempo de ~5 minutos a ~30 segundos en deploys normales.

2. **Jobs paralelos** – los tests PHP y el build de Vue corren al mismo tiempo en lugar de esperar uno al otro.

```
sin optimizar:  tests(3min) → composer(3min) → npm(2min) → build(1min) = 9 min
optimizado:     tests + build en paralelo → deploy = ~4-5 min
```

## Pasos del pipeline

```
1. test    → PHPUnit con MySQL/Redis levantados como services en el runner
2. build   → composer install (--no-dev) + npm ci + npm run build + artisan optimize
3. package → zip con vendor/ + public/build/ + código (sin tests, sin node_modules)
4. deploy  → sube a S3 → crea versión en EB → actualiza el environment
5. verify  → health check con 3 reintentos → rollback automático si falla
```

## Rollback

```bash
# listar versiones disponibles en EB
aws elasticbeanstalk describe-application-versions \
  --application-name mi-app

# rollback
aws elasticbeanstalk update-environment \
  --environment-name mi-app-prod \
  --version-label "prod-abc123-anterior"
```

Para base de datos:
```bash
php artisan migrate:rollback --step=1
```

## Estructura

```
case-3-laravel-vue-cicd/
├── .github/workflows/app-deploy.yml
├── terraform/
│   └── main.tf    # EB app, environment, RDS, ElastiCache, S3
└── deployment/
    └── 01_php.config   # configuración de PHP para EB
```
