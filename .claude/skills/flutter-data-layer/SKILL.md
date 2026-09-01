---
name: flutter-data-layer
description: "**WORKFLOW SKILL** — Short guidance for the data layer in Flutter Clean Architecture (dio + json_serializable)."
---

# Flutter Data Layer (summary)

Purpose: Short, opinionated defaults and pointers for implementing the data layer in a Flutter Clean Architecture app.

Defaults
- **HTTP client**: dio
- **Serialization**: json_serializable (codegen)
- **Error handling**: Only throw mapped/domain errors (example: 401 -> InvalidCredentialsException); rethrow unknown errors so callers can decide.

Details and examples are moved to the `references/` docs and `templates/` examples in this skill:

- Detailed repository & networking guidance: [references/datasource.md](references/datasource.md)
- Model & json_serializable guidance: [references/model.md](references/model.md)
- Working code templates: [templates/](templates/)

Rename guidance
- If an application only uses a remote source, prefer naming the component and folder `repository` (and use `Repository` suffix) instead of `datasource`. Templates use `repository` for that case.

Quick prompts
- "Scaffold a `User` model using `json_serializable` and a `UserRepositoryImpl` using `dio` that maps 401 -> invalid credentials."
- "Generate DTO tests: `fromJson`, `toJson`, and `toEntity()` round-trip for `UserResponse`."

