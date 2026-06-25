import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  const UserProfile({
    required this.userId,
    required this.customerId,
    required this.username,
    required this.baseRole,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['userId'] as String,
      customerId: json['customer_id'] as String,
      username: json['username'] as String,
      baseRole: json['baseRole'] as String,
    );
  }

  final String userId;
  final String customerId;
  final String username;
  final String baseRole;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'customer_id': customerId,
      'username': username,
      'baseRole': baseRole,
    };
  }

  @override
  List<Object?> get props => [userId, customerId, username, baseRole];
}
