# Entities

Use `equatable` for value equality in domain entities and value objects. Keep entities small and focused on behavior and invariants.

Example entity (copy into `lib/domain/entities/user.dart`):

```dart
import 'package:equatable/equatable.dart';

class User extends Equatable {
  final int id;
  final String name;
  final String email;

  const User({required this.id, required this.name, required this.email});

  @override
  List<Object?> get props => [id, name, email];
}
```

Value objects
- Prefer small, immutable types for validated values (e.g., `Email`, `Money`).
- Validation should happen at construction time and throw a domain exception on invalid input.
- Prefer composition over inheritance.

Notes
- Domain code must not import data-layer nor networking packages (e.g., Dio).
