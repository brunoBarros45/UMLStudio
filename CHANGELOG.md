# Changelog

Todos los cambios notables de **UMLStudio** se documentan en este archivo.

## [v1.0.0] - 2026-11-17

### Agregado
- **Arquitectura modular en 4 capas:** `UMLDomain`, `UMLApplication`, `UMLInfrastructure` y `UMLStudioApp` en Swift 6 para macOS Apple Silicon (`arm64`).
- **Modelado UML 2.5 completo:** Clases, Clases Abstractas, Interfaces y Enumeraciones, visibilidad (`+`, `-`, `#`, `~`), miembros `static` y `abstract`, estereotipos y paquetes.
- **Todas las relaciones UML 2.5:** `Association`, `Directed Association`, `Aggregation`, `Composition`, `Generalization`, `Interface Realization` y `Dependency`, con multiplicidades, roles, trazado recto u ortogonal e inversión de extremos.
- **Separación Modelo vs. Vista (estilo Gaphor):** Múltiples diagramas compartiendo un mismo repositorio `UMLModel`.
- **Lienzo 2D interactivo en ambos ejes (`X` e `Y`):** Arrastre fluido con clic sostenido, paneo bidimensional simultáneo, zoom y puertos de conexión.
- **Selectores ordenados de tipos de datos & QuickEdit:** Listado de tipos ordenado de más comunes a menos comunes (más tipos definidos en el modelo) al crear y editar atributos y métodos.
- **Persistencia e Interoperabilidad:** Guardado/apertura en formato `.umlproj` (JSON), importación/exportación bidireccional Mermaid `classDiagram` y exportación visual a **PNG (2x Retina)** y **PDF vectorial**.
- **Suite de pruebas:** 16 pruebas unitarias en 6 suites (`UMLStudioTests`) y historial granular Undo/Redo con Command Pattern.
