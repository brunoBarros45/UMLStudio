# Contribuir a UMLStudio

¡Toda ayuda, feedback, reporte de bug o propuesta de mejora es bienvenida! **UMLStudio** es un proyecto Open Source bajo licencia MIT pensado para la comunidad de macOS y desarrolladores Swift.

---

## Cómo puedes colaborar

- **Reportar bugs:** Si encontraste un error en la interfaz, en el lienzo, en el parser QuickEdit o al importar/exportar Mermaid, abrí un Issue usando la plantilla de **Bug Report**.
- **Dar feedback o proponer mejoras:** Compartí ideas de UX, nuevas relaciones, generación de código o atajos mediante un Issue de **Feature Request / Feedback**.
- **Enviar código (Pull Requests):** Arreglos de bugs, tests adicionales o nuevas funcionalidades respetando la arquitectura modular del proyecto.

---

## Flujo de trabajo para Pull Requests

1. Hacé un fork del repositorio y creá tu rama a partir de `develop`:
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feat/mi-mejora
   ```
2. Respetá la separación en 4 módulos (**Clean Architecture / SOLID**):
   - `UMLDomain`: entidades puras, value objects y puertos (sin dependencias de UI ni I/O).
   - `UMLApplication`: comandos reversibles (`ProjectCommand`), factories, estrategias y parsers.
   - `UMLInfrastructure`: adaptadores de persistencia y codecs textuales (Mermaid, JSON).
   - `UMLStudioApp`: vistas SwiftUI y ViewModels segregados.
3. Ejecutá todas las pruebas antes de enviar tu PR:
   ```bash
   swift test
   swift build -c release
   ```
4. Usá mensajes de commit claros (estilo Conventional Commits: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`) y abrí el Pull Request apuntando a `develop`.
