import 'package:app/core/auth/auth_bloc.dart';
import 'package:app/features/login/bloc/login_bloc.dart';
import 'package:app/features/login/data/auth_repository.dart';
import 'package:app/features/login/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  final getIt = GetIt.instance;

  group('LoginPage Widget Tests', () {
    late AuthRepository authRepository;
    late AuthBloc authBloc;

    setUp(() {
      getIt.reset();
      authRepository = MockAuthRepository();
      authBloc = AuthBloc();
      getIt
        ..registerSingleton<AuthBloc>(authBloc)
        ..registerSingleton<AuthRepository>(authRepository);
    });

    tearDown(() {
      authBloc.close();
    });

    Widget createWidgetUnderTest() {
      return MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: Scaffold(
            body: BlocProvider<LoginBloc>(
              create: (context) => LoginBloc(authRepository: authRepository),
              child: const LoginPage(),
            ),
          ),
        ),
      );
    }

    testWidgets('renders all input fields and submit button',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byType(TextFormField), findsNWidgets(4));
      expect(find.text('ORGANIZATION ID'), findsOneWidget);
      expect(find.text('EMAIL ADDRESS'), findsOneWidget);
      expect(find.text('PASSWORD'), findsOneWidget);
      expect(find.text('TOTP CODE (2FA)'), findsOneWidget);
      expect(find.text('AUTHENTICATE SESSION'), findsOneWidget);
    });

    testWidgets('shows validation errors when fields are empty and submitted',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      await tester.tap(find.text('AUTHENTICATE SESSION'));
      await tester.pumpAndSettle();

      expect(find.text('Organization ID is required'), findsOneWidget);
      expect(find.text('Email address is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('shows validation error for invalid email format',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      final orgFinder = find.byType(TextFormField).at(0);
      final emailFinder = find.byType(TextFormField).at(1);
      final passwordFinder = find.byType(TextFormField).at(2);

      await tester.enterText(orgFinder, 'tenant-123');
      await tester.enterText(emailFinder, 'invalid-email');
      await tester.enterText(passwordFinder, 'pass123');

      await tester.tap(find.text('AUTHENTICATE SESSION'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
    });
  });
}
