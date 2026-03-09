# Reporte de optimización de costos

Escenario: $6,000/mes en AWS.

El análisis completo con el proceso de revisión, los cálculos por servicio y el plan de acción priorizado está en [docs/case-5.md](../docs/case-5.md).

## Resumen ejecutivo

| Acción | Ahorro estimado/mes | Esfuerzo |
|--------|---------------------|----------|
| Savings Plans EC2 (1 año) | ~$670 | Bajo |
| Reserved Instance RDS | ~$105 | Bajo |
| S3 Lifecycle Policies | ~$150–228 | Bajo |
| Right-sizing 5 instancias EC2 | ~$420 | Medio |
| Migración a Graviton arm64 | ~$340 | Medio |
| Ajuste de TTL en CloudFront | ~$50 | Bajo |

**Ahorro total proyectado: ~$1,600–1,800/mes**
**Costo nuevo estimado: ~$4,200–4,400/mes**

Las acciones de alto impacto y bajo esfuerzo (Savings Plans + RDS RI + S3 Lifecycle) se pueden ejecutar en la primera semana sin tocar ninguna infraestructura en producción.
