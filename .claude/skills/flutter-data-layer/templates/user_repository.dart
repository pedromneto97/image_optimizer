import 'package:dio/dio.dart';
import './models/user_response.dart';
import '../../domain/data/user_repository.dart';
import '../../domain/exceptions.dart';
import '../../domain/entities/user.dart';


class UserRepositoryImpl implements UserRepository {
  final Dio dio;
  
  const UserRepositoryImpl(this.dio);

  @override
  Future<User> getUser(int id) async {
    try {
      final response = await dio.get<Map<String, dynamic>>('/users/$id');

      final model = UserResponse.fromJson(response.data!);
      
      return model.toEntity();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) throw InvalidCredentialsException();
      
      rethrow;
    }
  }
}
