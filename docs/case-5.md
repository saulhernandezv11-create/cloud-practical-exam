# Caso 5 – Optimización de costos ($6,000/mes)

Antes de proponer cualquier cambio lo primero es entender de dónde viene el gasto. Usaría **AWS Cost Explorer** para ver el desglose por servicio y recurso individual, y **AWS Compute Optimizer** para saber si las instancias EC2 están sobredimensionadas. Compute Optimizer analiza las métricas reales de CPU y memoria de los últimos 14 días y dice qué hacer, no estimaciones a ciegas.

---

**EC2 – el gasto más grande**

Si las instancias llevan meses corriendo continuamente, comprar un **Compute Savings Plan de 1 año** es lo más fácil: no se toca nada de infraestructura y el descuento es hasta 66% según la [documentación oficial de Savings Plans](https://docs.aws.amazon.com/savingsplans/latest/userguide/what-is-savings-plans.html). Se compra directo desde el Billing Console de AWS.

Si Compute Optimizer indica que hay instancias con uso promedio bajo, ahí se evalúa bajar de t3.large a t3.medium.

**RDS**

Comprar una **Reserved Instance de 1 año** para la db.m5.large. Similar a los Savings Plans pero para RDS. Sin cambios en la infraestructura, solo un compromiso de pago.

**S3 – 20 TB**

Lo más probable es que la mayoría de objetos no se acceden hace meses pero siguen en S3 Standard. Una **lifecycle policy** los mueve automáticamente a clases más baratas según antigüedad (Standard → Standard-IA → Glacier). [Documentación de S3 Storage Classes](https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage-class-intro.html).

---

Ahorro estimado con solo las tres acciones anteriores: **~$900–1,000/mes** sin tocar ninguna infraestructura en producción. Para más ahorros habría que meterse a right-sizing y migración a Graviton, pero eso requiere validar primero con el equipo.

Para no perder el control de costos de nuevo, lo mínimo es activar un **AWS Budget** con alerta al 80% del límite mensual desde el Billing Console.
