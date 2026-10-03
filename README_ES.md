# TechCare: análisis de tickets y oportunidades de automatización

**Idioma:** [English](README.md) | Español

Proyecto de análisis de datos orientado a identificar categorías de consultas de soporte con potencial de automatización, combinando volumen, prioridad, esfuerzo operativo y grado de estandarización.

El proyecto integra **Python**, **MySQL** y **Power BI** en un flujo reproducible que abarca preparación de datos, modelado dimensional, validación, análisis y visualización.

> **Conclusión principal:** `Battery life` destaca como candidato para un piloto controlado de automatización. En la simulación operativa reúne 2.175 tickets candidatos y 752,33 horas de gestión. Una reducción hipotética del 20 % equivaldría a 150,47 horas potencialmente liberadas. Este escenario debe validarse mediante un piloto y no representa un ahorro económico demostrado.

## Problema de negocio

Un equipo de soporte multicanal necesita decidir qué consultas conviene estudiar primero para una futura automatización. Priorizar únicamente por volumen puede conducir a automatizar casos complejos, críticos o difíciles de estandarizar.

El análisis plantea una priorización más prudente basada en cuatro criterios:

- volumen de tickets;
- prioridad baja o media;
- esfuerzo operativo;
- repetición y posible estandarización del caso.

La automatización se trata como una **hipótesis que debe validarse**, no como una conclusión automática derivada de los datos.

## Objetivos

- Evaluar la calidad y las limitaciones de los datos disponibles.
- Diseñar un modelo dimensional que permita analizar conjuntamente dos fases con estructuras diferentes.
- Identificar subconjuntos de tickets adecuados para estudiar un piloto de automatización.
- Cuantificar el esfuerzo operativo asociado sin confundir tiempo de ciclo con trabajo directo del agente.
- Construir un dashboard que conecte resultados, limitaciones y recomendaciones.

## Datos

El proyecto utiliza dos conjuntos con funciones distintas:

| Fase | Registros | Naturaleza | Uso |
|---|---:|---|---|
| Fase 1 | 8.469 | Muestra pública de tickets de soporte | Exploración inicial y formulación de hipótesis |
| Fase 2 | 60.000 | Dataset sintético de seis meses | Demostración metodológica y simulación operativa |

### Consideraciones de calidad

- En la Fase 1, solo 2.769 tickets están cerrados.
- Únicamente 1.404 tickets cerrados tienen fechas en orden lógico para calcular duración.
- La muestra temporal de la Fase 1 no permite analizar tendencias fiables.
- En la Fase 2, los resultados proceden de datos sintéticos y no constituyen validación externa de la hipótesis.
- Los valores ausentes vinculados a tickets abiertos, pendientes o no escalados se conservan como nulos estructurales; no se imputan sin una regla de negocio.

### Privacidad y naturaleza de los datos

- Los datos utilizados en la Fase 1 están anonimizados en la versión pública del proyecto.
- Los datos de la Fase 2 son completamente sintéticos y se utilizan únicamente para demostrar el método analítico.
- Los notebooks no muestran datos personales reales y pueden revisarse como parte del flujo técnico.
- Los CSV no se incluyen en el repositorio; los notebooks, el modelo y las validaciones documentan el proceso sin distribuir los archivos de origen.

## Flujo de trabajo

```mermaid
flowchart LR
    A[CSV de origen] --> B[Python y pandas]
    B --> C[CSV preparados]
    C --> D[(MySQL)]
    D --> E[Modelo dimensional]
    E --> F[Vistas de negocio]
    E --> G[Power BI]
    F --> G
    G --> H[Dashboard y recomendaciones]
```

### Python

- Inspección de estructura, tipos, duplicados y valores ausentes.
- Conversión y validación de fechas.
- Comprobaciones de coherencia temporal y de rangos numéricos.
- Preparación de archivos compatibles con MySQL.
- Validación posterior a la exportación para comprobar filas, columnas, identificadores y nulos.

### MySQL

- Creación de tablas de origen.
- Construcción de un modelo dimensional con dos tablas de hechos.
- Dimensiones conformadas para fase, asunto, producto y canal.
- Dimensiones específicas de fecha, agente y equipo para la Fase 2.
- Vistas que centralizan las reglas de selección de candidatos.
- Controles de unicidad, integridad referencial y conciliación de recuentos.
- Consultas analíticas con CTE, funciones de ventana y agregaciones.

### Power BI

- Integración de ambas fases en un único informe.
- Medidas DAX para indicadores operativos e inteligencia temporal.
- Comparación general, diagnóstico, tendencias y priorización.
- Navegación por páginas y segmentadores controlados.
- Página específica de propuesta de automatización y limitaciones.

## Modelo analítico

Se mantienen dos tablas de hechos porque las fases no comparten el mismo esquema ni la misma calidad temporal:

- `fact_tickets_fase1`: conserva los 8.469 tickets e identifica las 1.404 duraciones válidas.
- `fact_tickets_fase2`: conserva los 60.000 tickets e incorpora métricas operativas, fechas, agentes, equipos y escalado.

Las dimensiones de fase, asunto, producto y canal son compartidas. La dimensión de fecha se relaciona con la fecha de creación de la Fase 2. Agente y equipo se modelan por separado porque un mismo agente puede aparecer asociado a varios equipos.

Las vistas `vw_candidatos_fase2` y `vw_battery_life_candidatos` evitan duplicar las reglas de selección en SQL, DAX y visualizaciones.

## Resultados principales

### Fase 1: exploración inicial

| Indicador | Resultado |
|---|---:|
| Tickets totales | 8.469 |
| Tickets cerrados | 2.769 |
| Tickets cerrados con duración válida | 1.404 |
| Duración media válida | 7,58 h |
| Satisfacción media de tickets cerrados | 2,99/5 |

`Battery life` obtuvo la mayor puntuación exploratoria al combinar volumen, prioridad, duración y satisfacción. Esta fase permitió formular la hipótesis, pero sus limitaciones temporales impiden estimar un impacto operativo fiable.

### Fase 2: simulación operativa

| Indicador | Resultado |
|---|---:|
| Tickets totales | 60.000 |
| Tickets cerrados | 49.059 |
| Tiempo medio de primera respuesta | 4,01 h |
| Tiempo medio de resolución | 30,94 h |
| Tiempo medio de gestión | 28,22 min |
| Satisfacción media | 3,41/5 |

La regla de candidatos selecciona tickets cerrados, no escalados y de prioridad baja o media:

| Resultado de priorización | Valor |
|---|---:|
| Tickets candidatos de Fase 2 | 26.062 |
| Horas de gestión asociadas | 9.463,95 h |
| Candidatos de `Battery life` | 2.175 |
| Horas de gestión de `Battery life` | 752,33 h |
| Gestión media por ticket | 20,75 min |
| Satisfacción media | 3,30/5 |
| Escenario hipotético de reducción del 20 % | 150,47 h |

La repetición de resoluciones y patrones de descripción apoya la hipótesis de estandarización. Sin embargo, el texto disponible no demuestra que el procedimiento real de resolución sea idéntico en todos los casos.

## Dashboard

### Comparación general y resumen de fases

| Vista general | Detalle de `Battery life` en Fase 2 |
|---|---|
| ![Vista general de las fases](images/01_vista_general_fases.jpg) | ![Vista de la Fase 2 filtrada a Battery life](images/02_vista_general_fase2.jpg) |

| Resumen de Fase 1 | Tendencia mensual de Fase 2 |
|---|---|
| ![Resumen de la Fase 1](images/03_resumen_fase1.jpg) | ![Tendencia mensual de la Fase 2](images/04_tendencia_mensual_fase2.jpg) |

### Propuesta de automatización

![Propuesta de automatización de la Fase 2](images/05_propuesta_automatizacion_fase2.jpg)

## Estructura del repositorio

```text
techcare-analytics/
├── README.md
├── images/
│   ├── 01_vista_general_fases.jpg
│   ├── 02_vista_general_fase2.jpg
│   ├── 03_resumen_fase1.jpg
│   ├── 04_tendencia_mensual_fase2.jpg
│   └── 05_propuesta_automatizacion_fase2.jpg
├── notebooks/
│   ├── 01_phase1_preprocessing.ipynb
│   └── 02_phase2_preprocessing.ipynb
├── powerbi/
│   └── techcare_dashboard.pbix
└── sql/
    ├── 01_database_setup.sql
    ├── 02_dimensional_model.sql
    ├── 03_business_views.sql
    ├── 04_data_quality_checks.sql
    └── 05_analysis_queries.sql
```

## Reproducción

### Requisitos

- Python con `pandas` y un entorno compatible con Jupyter Notebook.
- MySQL 8.x.
- Power BI Desktop.

### Secuencia

1. Colocar los archivos de origen junto a los notebooks con los nombres esperados por cada uno.
2. Ejecutar `01_phase1_preprocessing.ipynb` y `02_phase2_preprocessing.ipynb` de principio a fin.
3. Ejecutar `01_database_setup.sql` sobre un esquema nuevo.
4. Cargar en las tablas de origen los CSV generados por los notebooks.
5. Ejecutar, en orden, `02_dimensional_model.sql`, `03_business_views.sql`, `04_data_quality_checks.sql` y `05_analysis_queries.sql`.
6. Abrir `techcare_dashboard.pbix` y actualizar las credenciales o la conexión local de MySQL si se desea refrescar el modelo.

Las rutas de los CSV y las credenciales no se incluyen porque dependen del entorno local.

## Validaciones

La ejecución controlada del flujo SQL confirmó:

- 8.469 filas de Fase 1 y 60.000 de Fase 2, sin pérdidas al construir las tablas de hechos;
- identificadores duplicados, claves sin correspondencia y duplicados en dimensiones iguales a cero;
- 26.062 candidatos de Fase 2;
- 2.175 candidatos de `Battery life`;
- 752,33 horas de gestión y satisfacción media de 3,30 para ese subconjunto.

Los dos notebooks también se ejecutaron desde un kernel reiniciado y finalizaron sin errores.

## Limitaciones

- La Fase 1 tiene cobertura temporal insuficiente y contiene fechas invertidas en parte de los tickets cerrados.
- La Fase 2 es sintética; permite demostrar el enfoque, no confirmar su impacto en una operación real.
- La similitud textual no sustituye una revisión del procedimiento, los riesgos y las excepciones de cada caso.
- El escenario del 20 % es una hipótesis de capacidad potencial y no una estimación financiera.
- Antes de automatizar sería necesario validar exactitud, seguridad, derivación a agentes, experiencia del cliente y resultados del piloto.

## Recomendación

Realizar un piloto acotado sobre consultas de `Battery life` de prioridad baja o media, con respuesta inicial guiada y derivación inmediata cuando se detecten excepciones, casos críticos o necesidad de diagnóstico técnico.

El piloto debería comparar un grupo asistido con un grupo de control y medir, como mínimo:

- tasa de resolución sin intervención adicional;
- tiempo de gestión del agente;
- tasa de reapertura;
- escalados posteriores;
- satisfacción del cliente;
- errores o respuestas incorrectas.

Solo después de esa validación debería estimarse el impacto operativo o económico real.
