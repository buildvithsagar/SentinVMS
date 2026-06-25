import 'package:equatable/equatable.dart';

abstract class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object?> get props => [];
}

class LoginSubmitted extends LoginEvent {
  const LoginSubmitted({
    required this.customerId,
    required this.email,
    required this.password,
    this.totpCode,
  });

  final String customerId;
  final String email;
  final String password;
  final String? totpCode;

  @override
  List<Object?> get props => [customerId, email, password, totpCode];
}
