import 'package:app/core/auth/user_profile.dart';
import 'package:app/features/login/bloc/login_bloc.dart';
import 'package:app/features/login/bloc/login_event.dart';
import 'package:app/features/login/bloc/login_state.dart';
import 'package:app/features/login/data/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  group('LoginBloc', () {
    late AuthRepository authRepository;
    late LoginBloc loginBloc;

    const customerId = 'customer-id';
    const email = 'test@example.com';
    const password = 'secure-password';
    const user = UserProfile(
      userId: 'user-id',
      customerId: customerId,
      username: 'username',
      baseRole: 'OPERATOR',
    );

    setUp(() {
      authRepository = MockAuthRepository();
      loginBloc = LoginBloc(authRepository: authRepository);
    });

    tearDown(() {
      loginBloc.close();
    });

    test('initial state is LoginInitial', () {
      expect(loginBloc.state, const LoginInitial());
    });

    blocTest<LoginBloc, LoginState>(
      'emits [LoginLoading, LoginSuccess] when LoginSubmitted succeeds',
      build: () {
        when(() => authRepository.login(
              customerId: customerId,
              email: email,
              password: password,
            )).thenAnswer(
          (_) async => const AuthResult(
            accessToken: 'access-token',
            user: user,
          ),
        );
        return loginBloc;
      },
      act: (bloc) => bloc.add(const LoginSubmitted(
        customerId: customerId,
        email: email,
        password: password,
      )),
      expect: () => [
        const LoginLoading(),
        const LoginSuccess(accessToken: 'access-token', user: user),
      ],
    );

    blocTest<LoginBloc, LoginState>(
      'emits [LoginLoading, LoginFailure] when credentials are invalid',
      build: () {
        when(() => authRepository.login(
              customerId: customerId,
              email: email,
              password: password,
            )).thenThrow(const UnauthorizedException());
        return loginBloc;
      },
      act: (bloc) => bloc.add(const LoginSubmitted(
        customerId: customerId,
        email: email,
        password: password,
      )),
      expect: () => [
        const LoginLoading(),
        const LoginFailure(
          errorMessage: 'Invalid credentials. '
              'Please verify Organization ID, Email, and Password.',
        ),
      ],
    );

    blocTest<LoginBloc, LoginState>(
      'emits [LoginLoading, LoginFailure] when rate limited',
      build: () {
        when(() => authRepository.login(
              customerId: customerId,
              email: email,
              password: password,
            )).thenThrow(const RateLimitException());
        return loginBloc;
      },
      act: (bloc) => bloc.add(const LoginSubmitted(
        customerId: customerId,
        email: email,
        password: password,
      )),
      expect: () => [
        const LoginLoading(),
        const LoginFailure(
          errorMessage: 'Too many failed login attempts. '
              'Please try again after 1 minute.',
        ),
      ],
    );

    blocTest<LoginBloc, LoginState>(
      'emits [LoginLoading, LoginFailure] on network exception',
      build: () {
        when(() => authRepository.login(
              customerId: customerId,
              email: email,
              password: password,
            )).thenThrow(const NetworkException('Server down'));
        return loginBloc;
      },
      act: (bloc) => bloc.add(const LoginSubmitted(
        customerId: customerId,
        email: email,
        password: password,
      )),
      expect: () => [
        const LoginLoading(),
        const LoginFailure(errorMessage: 'Connection failure: Server down'),
      ],
    );
  });
}
