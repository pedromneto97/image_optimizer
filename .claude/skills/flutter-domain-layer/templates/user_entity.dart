import 'package:equatable/equatable.dart';

/// Template: copy to `lib/domain/entities/user.dart`
class User extends Equatable {
  final int id;
  final String name;
  final String email;

  const User({required this.id, required this.name, required this.email});

  @override
  List<Object?> get props => [id, name, email];
}
