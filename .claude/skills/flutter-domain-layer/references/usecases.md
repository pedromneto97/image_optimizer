# Use Cases (Interactors)

Use cases implement business operations and orchestrate domain logic. Use the `call()` API shape for ergonomic usage (e.g., `await getUser(1)`).

Pattern
- Class name describes the action (e.g., `GetUser`, `SaveUser`).
- Provide a `call()` method that performs the operation.
- Inject repository interfaces and other domain dependencies through the constructor.

Example (copy into `lib/domain/usecases/get_user.dart`):

```dart
import '../entities/user.dart';
import '../repositories/user_repository.dart';

class GetUser {
  final UserRepository _repository;

  const GetUser({required UserRepository repository}) : _repository = repository;

  Future<User> call(int id) => _repository.getUser(id);
}
```

Testing
- Unit-test use cases with a fake or mock repository; avoid network or IO in domain tests.
