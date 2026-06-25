import 'package:app/core/auth/auth_bloc.dart';
import 'package:app/core/auth/auth_event.dart';
import 'package:app/core/auth/auth_state.dart';
import 'package:app/core/auth/user_profile.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthBloc', () {
    late AuthBloc authBloc;
    const user = UserProfile(
      userId: 'test-user-id',
      customerId: 'test-customer-id',
      username: 'test-username',
      baseRole: 'OPERATOR',
    );

    setUp(() {
      authBloc = AuthBloc();
    });

    tearDown(() {
      authBloc.close();
    });

    test('initial state is AuthInitial', () {
      expect(authBloc.state, const AuthInitial());
    });

    blocTest<AuthBloc, AuthState>(
      'emits Authenticated when AuthLoggedIn is added',
      build: () => authBloc,
      act: (bloc) => bloc.add(const AuthLoggedIn(
        accessToken: 'access-token',
        user: user,
      )),
      expect: () => [
        const Authenticated(accessToken: 'access-token', user: user),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits Unauthenticated when AuthLoggedOut is added',
      build: () => authBloc,
      act: (bloc) => bloc.add(const AuthLoggedOut()),
      expect: () => [
        const Unauthenticated(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits updated Authenticated state when AuthTokenRefreshed is added and '
      'current state is Authenticated',
      build: () => authBloc,
      seed: () => const Authenticated(accessToken: 'old-token', user: user),
      act: (bloc) => bloc.add(const AuthTokenRefreshed(token: 'new-token')),
      expect: () => [
        const Authenticated(accessToken: 'new-token', user: user),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'does not emit when AuthTokenRefreshed is added and current state is '
      'not Authenticated',
      build: () => authBloc,
      act: (bloc) => bloc.add(const AuthTokenRefreshed(token: 'new-token')),
      expect: () => <AuthState>[],
    );
  });
}
