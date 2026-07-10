import 'package:app/core/auth/user_profile.dart';
import 'package:equatable/equatable.dart';

abstract class LoginState extends Equatable {
  const LoginState();

  @override
  List<Object?> get props => [];
}

class LoginInitial extends LoginState {
  const LoginInitial();
}

class LoginLoading extends LoginState {
  const LoginLoading();
}

class LoginOtpRequired extends LoginState {
  const LoginOtpRequired({required this.email});

  final String email;

  @override
  List<Object?> get props => [email];
}

class LoginSuccess extends LoginState {
  const LoginSuccess({
    required this.accessToken,
    required this.user,
  });

  final String accessToken;
  final UserProfile user;

  @override
  List<Object?> get props => [accessToken, user];
}

class LoginFailure extends LoginState {
  const LoginFailure({required this.errorMessage});

  final String errorMessage;

  @override
  List<Object?> get props => [errorMessage];
}
