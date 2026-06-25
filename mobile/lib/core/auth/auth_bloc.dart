import 'package:app/core/auth/auth_event.dart';
import 'package:app/core/auth/auth_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(const AuthInitial()) {
    on<AuthLoggedIn>(_onLoggedIn);
    on<AuthLoggedOut>(_onLoggedOut);
    on<AuthTokenRefreshed>(_onTokenRefreshed);
  }

  void _onLoggedIn(AuthLoggedIn event, Emitter<AuthState> emit) {
    emit(Authenticated(
      accessToken: event.accessToken,
      user: event.user,
    ));
  }

  void _onLoggedOut(AuthLoggedOut event, Emitter<AuthState> emit) {
    emit(const Unauthenticated());
  }

  void _onTokenRefreshed(AuthTokenRefreshed event, Emitter<AuthState> emit) {
    final currentState = state;
    if (currentState is Authenticated) {
      emit(Authenticated(
        accessToken: event.token,
        user: currentState.user,
      ));
    }
  }
}
