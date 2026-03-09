# Caso 5 – Optimización de costos ($6,000/mes)

## Situación actual

| Recurso | Configuración | Costo estimado |
|---------|--------------|----------------|
| 10 × EC2 t3.large | On-Demand | ~$1,680/mes |
| RDS PostgreSQL db.m5.large | Multi-AZ | ~$280/mes |
| S3 20 TB | Standard | ~$460/mes |
| CloudFront | transferencia | ~$200/mes |
| Resto (EBS, transferencia, etc.) | — | ~$3,380/mes |
| **Total** | | **~$6,000/mes** |

---

## Proceso de revisión

Lo primero antes de proponer cualquier cambio es entender de dónde viene realmente el gasto. Para eso usaría:

**AWS Cost Explorer**
Ver el desglose por servicio, por tipo de uso y por recurso individual. Con "Resource-level data" activado se puede ver cuánto cuesta cada instancia EC2 por separado.

**AWS Compute Optimizer**
Analiza las métricas reales de CPU y memoria de los últimos 14 días y dice si una instancia está sobredimensionada. Es la herramienta más útil para right-sizing porque usa datos reales, no estimaciones.

```bash
# ver CPU promedio de una instancia en los últimos 14 días
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --statistics Average Maximum \
  --period 86400 \
  --start-time $(date -d '14 days ago' --iso-8601=seconds) \
  --end-time $(date --iso-8601=seconds) \
  --dimensions Name=InstanceId,Value=i-XXXXXXXXX
```

**AWS Trusted Advisor**
Lista instancias con CPU < 10% promedio, volúmenes EBS sin adjuntar, IPs elásticas sin usar. Cosas fáciles de eliminar.

**S3 Storage Lens**
Para ver qué objetos no se han accedido en los últimos 90 días y migrarlos a una clase de almacenamiento más barata.

---

## Propuestas

### EC2 – el gasto más grande

**Opción 1: Savings Plans** (sin cambios técnicos, acción inmediata)

Si las instancias llevan meses corriendo sin parar, comprar un Compute Savings Plan de 1 año baja el costo ~40% sin tocar nada.

```
10 × t3.large On-Demand: ~$168/mes c/u = $1,680/mes
Con Savings Plan 1 año:  ~$101/mes c/u = $1,010/mes
Ahorro: ~$670/mes
```

**Opción 2: Right-sizing** (requiere validación, pero es seguro)

Si Compute Optimizer dice que 5 instancias promedian < 20% de CPU, bajar de t3.large a t3.medium no debería impactar nada.

```
t3.large  → $168/mes
t3.medium → $84/mes  (-50%)
5 instancias: ahorro ~$420/mes
```

**Opción 3: Graviton (arm64)**

Cambiar de t3.large a t4g.large cuesta ~20% menos con el mismo CPU/RAM. Para apps Python o Java no requiere cambios de código.

```
t3.large  (x86) = $168/mes
t4g.large (arm64) = $134/mes
10 instancias: ahorro ~$340/mes
```

**Opción 4: Auto Scaling** (si el tráfico tiene patrones)

Si hay horas de bajo tráfico, en lugar de tener 10 instancias fijas se puede configurar un mínimo de 3 y máximo de 10. Si el tráfico es uniforme 24/7 esto no aplica.

---

### RDS – segundo gasto

**Reserved Instance de 1 año**

```
On-Demand Multi-AZ db.m5.large: $280/mes
Reserved 1 año:                 $175/mes
Ahorro: ~$105/mes
```

Si la carga de la DB no es constante también vale evaluar Aurora Serverless v2, pero requiere una migración.

---

### S3 – 20 TB

El problema típico es que todo está en S3 Standard aunque la mayoría de los objetos no se acceden hace meses.

Solución: lifecycle policy que mueve los objetos automáticamente:

```json
{
  "Rules": [{
    "ID": "bajar-clase-storage",
    "Status": "Enabled",
    "Transitions": [
      { "Days": 30,  "StorageClass": "STANDARD_IA" },
      { "Days": 90,  "StorageClass": "GLACIER_IR" },
      { "Days": 365, "StorageClass": "DEEP_ARCHIVE" }
    ]
  }]
}
```

Si 12 de los 20 TB son datos históricos que casi nadie consulta:
```
12 TB en Standard:     $276/mes
12 TB en Glacier IR:   $48/mes
Ahorro: ~$228/mes
```

---

### CloudFront

Si el cache hit rate está bajo (< 70%), muchas requests pasan al origen sin necesidad. Revisaría los TTLs de los assets estáticos y los aumentaría.

```
Cache-Control: max-age=86400, immutable   (para archivos con hash en el nombre)
```

---

## Plan de acción

Ordenado por impacto vs esfuerzo:

| Prioridad | Acción | Ahorro/mes | Esfuerzo |
|-----------|--------|-----------|----------|
| Alta | Savings Plans EC2 (1 año) | ~$670 | Bajo – solo comprar en consola |
| Alta | Reserved Instance RDS | ~$105 | Bajo |
| Media | S3 Lifecycle Policies | ~$150–228 | Bajo – JSON de configuración |
| Media | Right-sizing EC2 (5 instancias) | ~$420 | Medio – requiere validar con el equipo |
| Baja | Migrar EC2 a Graviton | ~$340 | Medio – requiere pruebas |
| Baja | CloudFront TTL | ~$50 | Bajo |

**Ahorro total estimado: $1,600–1,800/mes (~27-30%)**
**Costo proyectado: ~$4,200-4,400/mes**

---

## Monitoreo de costos

Para que esto no se vuelva a salir de control, lo mínimo:

```bash
# alerta cuando el gasto mensual supere $5,000
aws budgets create-budget \
  --account-id <ID> \
  --budget '{
    "BudgetName": "alerta-mensual",
    "BudgetLimit": {"Amount": "5000", "Unit": "USD"},
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST"
  }' \
  --notifications-with-subscribers '[{
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 80
    },
    "Subscribers": [{"SubscriptionType": "EMAIL", "Address": "infra@empresa.com"}]
  }]'
```

Y activar tags en todos los recursos (`environment`, `team`, `proyecto`) para poder ver en Cost Explorer cuánto gasta cada equipo o ambiente.
