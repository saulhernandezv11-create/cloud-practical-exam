# Caso 3 – CI/CD para Laravel + Vue

Para el servidor de la app elegí Elastic Beanstalk. En Azure esto equivale más o menos a App Service: subes el código, EB maneja las instancias, el balanceador y el auto-scaling. El rollback es nativo: apunta a una versión anterior y listo. ECS sería más flexible pero para una app monolítica en PHP es más complejidad de la necesaria.

El pipeline tiene 4 jobs: tests con MySQL y Redis como services, build de Composer + npm en paralelo, deploy a EB y health check post-deploy. El cache de `composer.lock` y `package-lock.json` hace que los deploys subsecuentes sean bastante más rápidos cuando no cambiaron las dependencias.

Para base de datos uso RDS y para Redis ElastiCache. Los assets compilados de Vue van a S3 y se sirven desde CloudFront para no cargarlos desde el servidor PHP.
