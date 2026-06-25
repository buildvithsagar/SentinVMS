import 'package:app/features/login/bloc/login_event.dart';
import 'package:app/features/login/bloc/login_state.dart';
import 'package:app/features/login/data/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc({required this.authRepository}) : super(const LoginInitial()) {
    on<LoginSubmitted>(_onLoginSubmitted);
  }

  final AuthRepository authRepository;

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(const LoginLoading());
    try {
      final result = await authRepository.login(
        customerId: event.customerId,
        email: event.email,
        password: event.password,
        totpCode: event.totpCode,
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
          errorMessage: 'Invalid credentials. '
              'Please verify Organization ID, Email, and Password.',
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
}
