# Validación ASR de Disponibilidad (Gestión de Salidas con Falla de Inventario)

## 1. Especificación

**Título del experimento:**  
Validación de Disponibilidad y Continuidad Operativa ante fallas del Servicio de Inventario usando Circuit Breaker, Buffer Local y Verificador de Consistencia.

**ASR involucrado:**  
**ASR1 – Disponibilidad:**  
Como Operador de Bodega, dado que el sistema puede presentar fallas en la actualización del inventario, cuando reporto la salida de un producto, quiero que el error sea detectado en menos de 300 ms para mantener la disponibilidad del sistema sin afectar el flujo operativo.

**Propósito del experimento:**  
Validar que la arquitectura con Circuit Breaker (CB), Buffer Local y Verificador de Consistencia mantiene la disponibilidad del sistema cuando el servicio de inventario falla o no refleja el cambio.  

Se evaluará si:  
1. El fallo es detectado en ≤ 300 ms.  
2. El sistema continúa operando sin interrupción.  
3. Las salidas se sincronizan correctamente una vez restablecido el servicio.

---

## 2. Resultados esperados

**Métricas principales:**

| Métrica | Resultado esperado |
|----------|--------------------|
| Tiempo de detección de falla | ≤ 300 ms |
| Disponibilidad del sistema (UI + Gestor de Bodega) | ≥ 99.5 % |
| Tasa de operaciones rechazadas | 0 % |
| Porcentaje de operaciones correctamente sincronizadas tras recuperación | 100 % |

---

## 3. Infraestructura computacional requerida

1. **Instancia EC2 AWS – Gestor de Bodega:** Contiene el Gestor de Salidas, el Buffer Local (SQLite/EBS) y el Verificador de Consistencia.  
2. **Instancia EC2 AWS – Circuit Breaker (Kong):** Implementa la lógica de detección de fallas con _timeout_ de 300 ms.  
3. **Instancia EC2 AWS – Servicio de Inventario:** Simula el servicio externo con _endpoints REST_ de actualización y lectura de _stock_.  
4. **Instancia AWS RDS – Base de Datos Inventario:** PostgreSQL como almacenamiento persistente.  
5. **Software de simulación de fallas y pruebas de resiliencia:** Locust o Chaos Mesh para inyectar demoras, caídas y errores controlados.

---

## 4. Descripción del experimento

1. **Preparación del entorno:**  
   Desplegar las instancias EC2 (Gestor de Bodega, CB, Inventario) y configurar el _timeout_ del CB en 300 ms.

2. **Dataset inicial:**  
   Cargar 1 000 productos en la base de datos del inventario (RDS).

3. **Escenario 1 – Falla técnica:**  
   Simular caída total del servicio de inventario (EC2 Inventario apagada).  
   Ejecutar 50 operaciones de salida desde la UI mediante Apache JMeter, midiendo:  
   a) Tiempo de detección de falla.  
   b) Continuidad del flujo.

4. **Escenario 2 – Falla lógica:**  
   El servicio responde 200 OK pero no modifica _stock_.  
   Validar que el Verificador de Consistencia detecta la falta de reflejo y guarda la salida en el Buffer Local.  
   Medir con JMeter los tiempos de respuesta y el estado final de cada transacción.

5. **Escenario 3 – Recuperación:**  
   Restaurar el servicio de inventario y medir que el _sync worker_ procese y sincronice el 100 % de las operaciones pendientes.  
   Utilizar JMeter para verificar que las operaciones en _buffer_ se reenvían exitosamente y sin duplicados.

6. **Análisis:**  
   Consolidar los tiempos promedio de detección, latencias por solicitud y tasas de éxito desde los reportes de JMeter (Dashboard HTML).  
   Verificar cumplimiento del ASR (< 300 ms detección, 0 % fallas, continuidad garantizada).

---

## 5. Plan de uso de IAG

1. **Generación de componentes base:** Uso de IAG para crear el código _boilerplate_ del microservicio “Gestor de Salidas” (API REST + almacenamiento local).  
2. **Configuración de Kong CB:** Generar la configuración YAML con _timeout_ 300 ms y políticas de reintento.  
3. **Automatización de fallas:** Generar _scripts_ para simular caídas (`curl delay` o _shutdown EC2_ ) y medir tiempos de detección del CB.  
4. **Análisis de logs:** Utilizar IAG para crear _scripts_ de _parsing_ de logs que calculen métricas de detección y sincronización.

---

## 6. Elementos de arquitectura

### 6.1 Diagrama de componentes
![ComponentesDisponibilidad](./ComponentesDisponibilidad.png)

### 6.2 Diagrama de despliegue
![DespliegueDisponibilidad](./DespliegueDisponibilidad.png)

---

## 7. Estilos de arquitectura

| Estilo | Argumentación | Beneficios y Desventajas (ASRs) |
|---------|----------------|--------------------------------|
| **Microservicios** | Cada servicio (Bodega, CB, Inventario) se despliega de forma independiente en una instancia EC2 distinta, comunicándose vía HTTP. | **Beneficio (Disponibilidad):** El aislamiento de fallas impide que la caída del servicio de inventario afecte el flujo operativo del Gestor de Bodega. **Desventaja:** Aumenta la complejidad de monitoreo y configuración de red entre instancias. |
| **Eventual Consistency** | Los movimientos no confirmados se almacenan temporalmente y se sincronizan una vez restaurado el servicio. | **Beneficio (Disponibilidad):** El sistema se mantiene operativo incluso sin conectividad total. **Desventaja:** La información del inventario puede quedar desactualizada temporalmente. |
| **Observador / Supervisor (Monitor Pattern)** | El Verificador de Consistencia actúa como observador que detecta fallas lógicas en la actualización del inventario. | **Beneficio (Confiabilidad):** Detecta errores silenciosos que el CB no cubre. **Desventaja:** Introduce sobrecarga de validación y consultas adicionales. |

---

## 8. Tácticas y patrones de arquitectura

| Táctica / Patrón | Descripción | Beneficios y Desventajas (ASRs) |
|------------------|--------------|--------------------------------|
| **Circuit Breaker Pattern** | Interrumpe solicitudes a servicios no disponibles tras fallos repetidos o _timeouts_, devolviendo respuestas rápidas (_fallback_). | **Beneficio:** Cumple el requisito de detección < 300 ms y evita bloquear el sistema. **Desventaja:** Requiere configuración cuidadosa de umbrales. |
| **Fallback Local (Store-and-Forward)** | Guarda operaciones localmente cuando un servicio externo no responde, y las reenvía cuando se recupera. | **Beneficio:** Mantiene disponibilidad sin pérdida de datos. **Desventaja:** Introduce complejidad en la reconciliación posterior. |
| **Verificador de Consistencia (Supervisor Pattern)** | Componente que valida que las operaciones realmente se reflejen en la base de datos y corrige si no. | **Beneficio:** Detecta fallas lógicas invisibles al CB. **Desventaja:** Incrementa consultas y tiempo total de ciclo. |
| **Idempotent Commands** | Identifica operaciones con ID único para evitar duplicados en reintentos. | **Beneficio:** Garantiza integridad en sincronizaciones. |
| **Timeout Management** | Limita el tiempo máximo de espera en llamadas externas (300 ms). | **Beneficio:** Cumple explícitamente el ASR de detección rápida de fallas. |

---

## 9. Tecnologías y argumentación

| Tecnología | Descripción | Alternativas |
|-------------|--------------|--------------|
| **AWS EC2 (Ubuntu 20.04)** | Entorno de ejecución para los microservicios del Gestor de Bodega, Circuit Breaker y API de Inventario. | ECS Fargate o AWS Lambda (si se busca menor administración). |
| **Kong Gateway** | Proxy/API Gateway con soporte nativo de Circuit Breaker y _timeouts_ configurables. | Istio, NGINX, o Spring Cloud Gateway. |
| **SQLite (Buffer Local)** | Base de datos ligera embebida en el servidor del Gestor de Bodega, usada para almacenar operaciones en modo _offline_. | Redis, Amazon SQS o DynamoDB Local. |
| **Python/Django REST Framework** | Framework para construir los microservicios de salida e inventario. | Node.js/Express, FastAPI, Spring Boot. |
| **PostgreSQL (AWS RDS)** | Base de datos relacional para el inventario principal. | MySQL, Aurora, MongoDB Atlas. |
| **JMeter** | Herramientas de inyección de fallas y medición de resiliencia. | Gremlin, Artillery. |

---

## 10. Argumentación complementaria

La selección tecnológica prioriza disponibilidad, simplicidad de despliegue y control experimental:

- **AWS EC2 + RDS** proporcionan aislamiento y persistencia controlada, asegurando independencia entre servicios y trazabilidad de métricas.  
- **Kong Gateway** implementa el _Circuit Breaker_ con _timeout_ de 300 ms que cumple el ASR de detección rápida.  
- **SQLite** garantiza *store-and-forward* local sin dependencias externas.  
- **Python (Django REST/ FastAPI)** permite APIs ligeras y reproducibles.  
- **JMeter** mide latencias y disponibilidad de extremo a extremo.  

Esta combinación cumple los ASR de Disponibilidad y Continuidad Operativa, manteniendo el sistema funcional incluso durante fallas técnicas o lógicas del servicio de inventario.
