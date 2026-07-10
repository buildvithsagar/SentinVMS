import 'package:equatable/equatable.dart';

abstract class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object?> get props => [];
}

class LoginReset extends LoginEvent {
  const LoginReset();
}

class LoginSubmitted extends LoginEvent {
  const LoginSubmitted({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

class LoginOtpSubmitted extends LoginEvent {
  const LoginOtpSubmitted({
    required this.email,
    required this.otpCode,
  });

  final String email;
  final String otpCode;

  @override
  List<Object?> get props => [email, otpCode];
}
