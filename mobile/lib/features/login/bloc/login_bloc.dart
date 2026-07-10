import 'package:app/features/login/bloc/login_event.dart';
import 'package:app/features/login/bloc/login_state.dart';
import 'package:app/features/login/data/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc({required this.authRepository}) : super(const LoginInitial()) {
    on<LoginSubmitted>(_onLoginSubmitted);
    on<LoginOtpSubmitted>(_onLoginOtpSubmitted);
    on<LoginReset>((event, emit) => emit(const LoginInitial()));
  }

  final AuthRepository authRepository;

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(const LoginLoading());
    try {
      final status = await authRepository.loginStep1(
        email: event.email,
        password: event.password,
      );
      if (status == 'OTP_SENT') {
        emit(LoginOtpRequired(email: event.email));
      } else {
        emit(const LoginFailure(errorMessage: 'Authentication server status mismatch.'));
      }
    } on UnauthorizedException {
      emit(
        const LoginFailure(
          errorMessage: 'Invalid credentials. '
              'Please verify Email and Password.',
        ),
      );
    } on RateLimitException {
      emit(
        const LoginFailure(
          errorMessage: 'Too many failed login attempts. '
              'Please try again after 1 minute.',
        ),
      );
    } on NetworkException catch (e) {
      emit(LoginFailure(errorMessage: 'Connection failure: ${e.message}'));
    } catch (e) {
      emit(LoginFailure(errorMessage: 'An unexpected error occurred: $e'));
    }
  }

  Future<void> _onLoginOtpSubmitted(
    LoginOtpSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(const LoginLoading());
    try {
      // Infer the customer/tenant ID from the operator email
      final inferredTenantId = event.email.contains('tenantb') ? 'MOCKTNB2' : 'MOCKTNA1';

      final result = await authRepository.loginStep2(
        email: event.email,
        otpCode: event.otpCode,
        customerId: inferredTenantId,
      );
      emit(
        LoginSuccess(
          accessToken: result.accessToken,
          user: result.user,
        ),
      );
    } on UnauthorizedException {
      emit(
        const LoginFailure(
          errorMessage: 'Invalid OTP code. Please try again.',
        ),
      );
    } on RateLimitException {
      emit(
        const LoginFailure(
          errorMessage: 'Too many verification attempts. Please retry later.',
        ),
      );
    } on NetworkException catch (e) {
      emit(LoginFailure(errorMessage: 'Verification connection failure: ${e.message}'));
    } catch (e) {
      emit(LoginFailure(errorMessage: 'Verification failed: $e'));
    }
  }
}
