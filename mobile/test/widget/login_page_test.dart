import 'package:app/core/auth/auth_bloc.dart';
import 'package:app/features/login/bloc/login_bloc.dart';
import 'package:app/features/login/bloc/login_state.dart';
import 'package:app/features/login/data/auth_repository.dart';
import 'package:app/features/login/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
class MockLoginBloc extends Mock implements LoginBloc {}

void main() {
  final getIt = GetIt.instance;

  group('LoginPage Widget Tests', () {
    late AuthRepository authRepository;
    late AuthBloc authBloc;
    late LoginBloc loginBloc;

    setUp(() {
      getIt.reset();
      authRepository = MockAuthRepository();
      authBloc = AuthBloc();
      loginBloc = MockLoginBloc();
      
      when(() => loginBloc.state).thenReturn(const LoginInitial());
      when(() => loginBloc.stream).thenAnswer((_) => const Stream<LoginState>.empty());
      when(() => loginBloc.close()).thenAnswer((_) async {});
      
      getIt
        ..registerSingleton<AuthBloc>(authBloc)
        ..registerSingleton<AuthRepository>(authRepository);
    });

    tearDown(() {
      authBloc.close();
    });

    Widget createWidgetUnderTest({LoginBloc? customBloc}) {
      return MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: Scaffold(
            body: BlocProvider<LoginBloc>.value(
              value: customBloc ?? loginBloc,
              child: const LoginPage(),
            ),
          ),
        ),
      );
    }

    testWidgets('renders all credentials input fields and submit button initially',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('OPERATOR EMAIL'), findsOneWidget);
      expect(find.text('SECURITY PASSCODE'), findsOneWidget);
      expect(find.text('AUTHENTICATE SESSION'), findsOneWidget);
      
      // Org ID and OTP fields should not be visible initially
      expect(find.text('ORGANIZATION ID'), findsNothing);
      expect(find.text('MFA VERIFICATION CODE'), findsNothing);
    });

    testWidgets('shows validation errors when fields are empty and submitted',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      // Clear the text fields
      final emailField = find.byKey(const Key('emailField'));
      final passwordField = find.byKey(const Key('passwordField'));
      
      await tester.enterText(emailField, '');
      await tester.enterText(passwordField, '');
      await tester.pump();

      await tester.tap(find.text('AUTHENTICATE SESSION'));
      await tester.pump(); 

      expect(find.text('Email address is required'), findsOneWidget);
      expect(find.text('Security Passcode is required'), findsOneWidget);
    });

    testWidgets('shows validation error for invalid email format',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      final emailField = find.byKey(const Key('emailField'));
      final passwordField = find.byKey(const Key('passwordField'));

      await tester.enterText(emailField, 'invalid-email');
      await tester.enterText(passwordField, 'pass123');
      await tester.pump();

      await tester.tap(find.text('AUTHENTICATE SESSION'));
      await tester.pump(); 

      expect(find.text('Please enter a valid email address'), findsOneWidget);
    });

    testWidgets('renders OTP verification screen when state is LoginOtpRequired',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final customLoginBloc = MockLoginBloc();
      when(() => customLoginBloc.state).thenReturn(const LoginOtpRequired(email: 'operator@demo.com'));
      when(() => customLoginBloc.stream).thenAnswer(
        (_) => Stream<LoginState>.fromIterable([const LoginOtpRequired(email: 'operator@demo.com')]),
      );
      when(() => customLoginBloc.close()).thenAnswer((_) async {});

      await tester.pumpWidget(createWidgetUnderTest(customBloc: customLoginBloc));
      // First pump to trigger listener
      await tester.pump();
      // Second pump to render the state change
      await tester.pump();

      expect(find.text('MFA VERIFICATION CODE'), findsOneWidget);
      expect(find.text('Please enter the 6-digit OTP code sent to operator@demo.com'), findsOneWidget);
      expect(find.byKey(const Key('otpField')), findsOneWidget);
      expect(find.text('VERIFY CODE'), findsOneWidget);
      expect(find.text('Back to login'), findsOneWidget);
      
      await customLoginBloc.close();
    });
  });
}
