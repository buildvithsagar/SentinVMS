import 'package:app/core/auth/user_profile.dart';
import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthAuthenticating extends AuthState {
  const AuthAuthenticating();
}

class Authenticated extends AuthState {
  const Authenticated({
    required this.accessToken,
    required this.user,
  });

  final String accessToken;
  final UserProfile user;

  @override
  List<Object?> get props => [accessToken, user];
}

class Unauthenticated extends AuthState {
  const Unauthenticated({this.errorMessage});

  final String? errorMessage;

  @override
  List<Object?> get props => [errorMessage];
}
