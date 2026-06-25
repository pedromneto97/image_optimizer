# Repositories (ports)

Repository interfaces define the contracts the data layer implements. Keep them focused on domain types and document expected domain exceptions.

Example (copy into `lib/domain/repositories/user_repository.dart`):

```dart
import '../entities/user.dart';

abstract interface class UserRepository {
  /// Returns the user for [id].
  ///
  /// Implementations should map infra errors to domain exceptions (e.g., 404 -> NotFoundException).
  Future<User> getUser(int id);

  Future<void> saveUser(User user);
}
```

Guidance
- Do not expose transport types (e.g., Dio, Response, DTOs) in repository signatures.
- Document which domain exceptions a method may throw so callers can handle them.
