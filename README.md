# UMLStudio

Aplicación nativa para **macOS Apple Silicon (`arm64`)** escrita en **Swift 6** y **SwiftUI / AppKit** para el modelado de **Diagramas de Clases UML 2.5**.

Inspirada en la separación estricta Modelo/Vista de [Gaphor](https://github.com/gaphor/gaphor), la notación y QuickEdit de [StarUML](https://docs.staruml.io/) y la compatibilidad con diagramas Mermaid de [staruml-mcp-server](https://github.com/staruml/staruml-mcp-server).

---

## Arquitectura Limpia (4 Módulos)

| Módulo | Responsabilidad | Patrones y Principios |
| :--- | :--- | :--- |
| **`UMLDomain`** | Entidades UML 2.5 puras, Value Objects, catálogo ordenado de tipos, presentación y puertos (`DomainPorts`). | SRP, Dependency Inversion (Ports & Adapters), `Sendable` / `Codable` / `Hashable`. |
| **`UMLApplication`** | Casos de uso con historial granular, fábricas, parser QuickEdit y estrategias de layout/ruteo. | **Command Pattern** (`ProjectCommand` + `CommandHistoryManager`), **Factory Pattern**, **Strategy Pattern**. |
| **`UMLInfrastructure`** | Persistencia `.umlproj` en JSON y codec bidireccional Mermaid `classDiagram`. | **Repository Pattern** (`JSONProjectRepository`), **Adapter / Facade** (`MermaidClassDiagramCodec`). |
| **`UMLStudioApp`** | Interfaz nativa macOS de 3 paneles, lienzo 2D libre en ambos ejes, inspector contextual y exportador PNG/PDF. | **MVVM Segregado** (`WorkspaceViewModel`, `CanvasInteractionViewModel`). |

---

## Funcionalidades Principales

- **Modelado UML 2.5 Completo:** `Class`, `Abstract Class`, `Interface` y `Enumeration`, visibilidad (`+`, `-`, `#`, `~`), miembros `static` subrayados y `abstract` en cursiva, estereotipos y paquetes.
- **Todas las Relaciones UML 2.5:** `Association`, `Directed Association`, `Aggregation`, `Composition`, `Generalization`, `Interface Realization` y `Dependency`, con multiplicidades, roles, ruteo recto u ortogonal e inversión de extremos.
- **Separación Modelo vs. Vista:** Múltiples diagramas compartiendo el mismo repositorio `UMLModel`.
- **Lienzo 2D Interactivo:** Movimiento simultáneo en ambos ejes (`X` e `Y`), zoom, arrastre fluido con clic sostenido y puertos de conexión directa.
- **Selectores Ordenados de Tipos & QuickEdit:** Dropdown con tipos de datos ordenados de más comunes a menos comunes (incluyendo clasificadores del proyecto) al crear o modificar atributos, más parser QuickEdit.
- **Mermaid & Exportación:** Importador/exportador `classDiagram`, guardado/apertura `.umlproj` (JSON) y exportación a **PNG (2x Retina)** y **PDF vectorial**.

---

## Compilación, Pruebas y Ejecución

```bash
# Ejecutar suite de pruebas unitarias
swift test

# Compilar binario nativo ARM64 en modo release
swift build -c release

# Ejecutar la aplicación
.build/release/UMLStudioApp
```
