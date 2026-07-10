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

    const email = 'test@example.com';
    const password = 'secure-password';
    const otpCode = '123456';
    const customerId = 'MOCKTNA1'; // Inferred from test@example.com (does not contain tenantb)
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
      'emits [LoginLoading, LoginOtpRequired] when LoginSubmitted succeeds',
      build: () {
        when(() => authRepository.loginStep1(
              email: email,
              password: password,
            )).thenAnswer((_) async => 'OTP_SENT');
        return loginBloc;
      },
      act: (bloc) => bloc.add(const LoginSubmitted(
        email: email,
        password: password,
      )),
      expect: () => [
        const LoginLoading(),
        const LoginOtpRequired(email: email),
      ],
    );

    blocTest<LoginBloc, LoginState>(
      'emits [LoginLoading, LoginSuccess] when LoginOtpSubmitted succeeds',
      build: () {
        when(() => authRepository.loginStep2(
              email: email,
              otpCode: otpCode,
              customerId: customerId,
            )).thenAnswer(
          (_) async => const AuthResult(
            accessToken: 'access-token',
            user: user,
          ),
        );
        return loginBloc;
      },
      act: (bloc) => bloc.add(const LoginOtpSubmitted(
        email: email,
        otpCode: otpCode,
      )),
      expect: () => [
        const LoginLoading(),
        const LoginSuccess(accessToken: 'access-token', user: user),
      ],
    );

    blocTest<LoginBloc, LoginState>(
      'emits [LoginLoading, LoginFailure] when credentials are invalid on Step 1',
      build: () {
        when(() => authRepository.loginStep1(
              email: email,
              password: password,
            )).thenThrow(const UnauthorizedException());
        return loginBloc;
      },
      act: (bloc) => bloc.add(const LoginSubmitted(
        email: email,
        password: password,
      )),
      expect: () => [
        const LoginLoading(),
        const LoginFailure(
          errorMessage: 'Invalid credentials. '
              'Please verify Email and Password.',
        ),
      ],
    );

    blocTest<LoginBloc, LoginState>(
      'emits [LoginLoading, LoginFailure] when OTP code is invalid on Step 2',
      build: () {
        when(() => authRepository.loginStep2(
              email: email,
              otpCode: otpCode,
              customerId: customerId,
            )).thenThrow(const UnauthorizedException());
        return loginBloc;
      },
      act: (bloc) => bloc.add(const LoginOtpSubmitted(
        email: email,
        otpCode: otpCode,
      )),
      expect: () => [
        const LoginLoading(),
        const LoginFailure(
          errorMessage: 'Invalid OTP code. Please try again.',
        ),
      ],
    );

    blocTest<LoginBloc, LoginState>(
      'emits [LoginLoading, LoginFailure] when rate limited on Step 1',
      build: () {
        when(() => authRepository.loginStep1(
              email: email,
              password: password,
            )).thenThrow(const RateLimitException());
        return loginBloc;
      },
      act: (bloc) => bloc.add(const LoginSubmitted(
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
      'emits [LoginLoading, LoginFailure] on network exception on Step 1',
      build: () {
        when(() => authRepository.loginStep1(
              email: email,
              password: password,
            )).thenThrow(const NetworkException('Server down'));
        return loginBloc;
      },
      act: (bloc) => bloc.add(const LoginSubmitted(
        email: email,
        password: password,
      )),
      expect: () => [
        const LoginLoading(),
        const LoginFailure(errorMessage: 'Connection failure: Server down'),
      ],
    );

    blocTest<LoginBloc, LoginState>(
      'emits [LoginInitial] on LoginReset',
      build: () => loginBloc,
      act: (bloc) => bloc.add(const LoginReset()),
      expect: () => [
        const LoginInitial(),
      ],
    );
  });
}
