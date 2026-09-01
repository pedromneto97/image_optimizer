# Models & json_serializable

This document shows conventions and examples for API models (DTOs) implemented with `json_serializable` and mapping to domain entities.

Dependencies (pubspec)

```yaml
dependencies:
  json_annotation: ^4.11.0

dev_dependencies:
  build_runner: ^2.13.1
  json_serializable: ^6.13.1
```

Annotate models and generate code. For detailed templates, check [user_body](../templates/user_body.dart) and [user_response](../templates/user_response.dart) examples.

Run codegen

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

Best practices
- Use `JsonKey` and custom converters for dates or special formats.
- Keep DTOs in `data/models` and avoid referencing domain code from model files (use `toEntity()` for mapping).
