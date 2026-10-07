import 'dart:convert';

class UserModel {
  final int id;
  final String name;
  final String email;
  final List<String> roles;
  final bool hasPin;
  final String? avatarUrl;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.roles,
    this.hasPin = false,
    this.avatarUrl,
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

    final hasPinValue = json['has_pin'] == true ||
        json['has_pin'] == 1 ||
        json['has_pin'] == '1';

    return UserModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      roles: parsedRoles,
      hasPin: hasPinValue,
      avatarUrl: json['avatar_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'roles': roles,
      'has_pin': hasPin,
      'avatar_url': avatarUrl,
    };
  }

  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    List<String>? roles,
    bool? hasPin,
    String? avatarUrl,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      roles: roles ?? this.roles,
      hasPin: hasPin ?? this.hasPin,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  String toRawJson() => json.encode(toJson());

  factory UserModel.fromRawJson(String str) => UserModel.fromJson(json.decode(str));
}
