import 'package:app/app/router.dart';
import 'package:app/core/auth/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>.value(
      value: GetIt.instance<AuthBloc>(),
      child: MaterialApp.router(
        title: 'Enterprise VMS',
        debugShowCheckedModeBanner: false,
        routerConfig: AppRouter.router,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0D0E12),
          cardColor: const Color(0xFF14161F),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF02965E),
            surface: Color(0xFF14161F),
            error: Color(0xFFD32F2F),
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Color(0xFFE2E8F0)),
            bodyMedium: TextStyle(color: Color(0xFF70788C)),
            titleLarge: TextStyle(
              color: Color(0xFFE2E8F0),
              fontWeight: FontWeight.bold,
            ),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Color(0xFF14161F),
            labelStyle: TextStyle(color: Color(0xFF70788C)),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF70788C), width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF02965E)),
            ),
            errorBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFD32F2F), width: 0.5),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF02965E),
              foregroundColor: const Color(0xFFE2E8F0),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
