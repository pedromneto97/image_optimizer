# Domain Exceptions

Domain exceptions are small, typed exceptions the domain and application layers understand. Map infra/transport errors to these types in the data layer.

Example (copy into `lib/domain/exceptions.dart`):

```dart
class NotFoundException implements Exception {}

class InvalidCredentialsException implements Exception {}

class ValidationException implements Exception {}
```

Mapping guidance
- Data layer implementations should catch transport exceptions (e.g., `DioException`) and rethrow mapped domain exceptions.
- Document mapped errors on repository interfaces so callers know what to expect.
