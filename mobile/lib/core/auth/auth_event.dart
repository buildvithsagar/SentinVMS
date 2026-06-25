import 'package:app/core/auth/user_profile.dart';
import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthLoggedIn extends AuthEvent {
  const AuthLoggedIn({
    required this.accessToken,
    required this.user,
  });

  final String accessToken;
  final UserProfile user;

  @override
  List<Object?> get props => [accessToken, user];
}

class AuthLoggedOut extends AuthEvent {
  const AuthLoggedOut();
}

class AuthTokenRefreshed extends AuthEvent {
  const AuthTokenRefreshed({required this.token});

  final String token;

  @override
  List<Object?> get props => [token];
}
