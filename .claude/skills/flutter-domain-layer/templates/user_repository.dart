/// Template: copy to `lib/domain/repositories/user_repository.dart`
import '../entities/user.dart';

abstract interface class UserRepository {
  const UserRepository();
  /// May throw domain exceptions (see domain/exceptions.dart)
  Future<User> getUser(int id);

  Future<void> saveUser(User user);
}
