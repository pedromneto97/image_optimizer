import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserResponse {
  final int id;
  final String name;
  final String email;

  const UserResponse({required this.id, required this.name, required this.email});

  factory UserResponse.fromJson(Map<String, dynamic> json) => _$UserResponseFromJson(json);

  User toEntity() => User(id: id, name: name, email: email);
}
