import 'dart:convert';

class UserModel {
  final int id;
  final String name;
  final String email;
  final List<String> roles;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.roles,
  });

  bool get isDeveloper =>
      roles.contains('ryu_dev') || roles.contains('dev') || roles.contains('developer');

  factory UserModel.fromJson(Map<String, dynamic> json) {
    List<String> parsedRoles = [];
    if (json['roles'] is List) {
      parsedRoles = (json['roles'] as List).map((e) {
        if (e is Map<String, dynamic> && e['name'] != null) {
          return e['name'].toString();
        }
        return e.toString();
      }).toList();
    } else if (json['role'] != null) {
      parsedRoles = [json['role'].toString()];
    }

    return UserModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      roles: parsedRoles,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'roles': roles,
    };
  }

  String toRawJson() => json.encode(toJson());

  factory UserModel.fromRawJson(String str) => UserModel.fromJson(json.decode(str));
}
