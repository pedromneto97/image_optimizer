import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserBody {
  final int id;
  final String name;
  final String email;

  const UserBody({required this.id, required this.name, required this.email});

  factory UserBody.fromEntity(User entity) => UserBody(id: entity.id, name: entity.name, email: entity.email);

  Map<String, dynamic> toJson() => _$UserBodyToJson(this);
}
