/// Template: copy to `lib/domain/usecases/get_user.dart`
import '../repositories/user_repository.dart';
import '../entities/user.dart';

class GetUser {
  final UserRepository _repository;

  const GetUser({required UserRepository repository}) : _repository = repository;

  Future<User> call(int id) => _repository.getUser(id);
}
