import 'package:app/app/router.dart';
import 'package:app/core/auth/auth_bloc.dart';
import 'package:app/core/network/connectivity_service.dart';
import 'package:app/core/widgets/connectivity_banner.dart';
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
        builder: (context, child) {
          final connectivityService = GetIt.instance<ConnectivityService>();
          return ConnectivityBanner(
            connectivityService: connectivityService,
            child: child ?? const SizedBox.shrink(),
          );
        },
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0F172A),
          cardColor: const Color(0x1F000000),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF2563EB),
            error: Color(0xFFEF4444),
            surface: Color(0xFF1E293B),
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Colors.white),
            bodyMedium: TextStyle(color: Color(0xFF94A3B8)),
            titleLarge: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Color(0x0FFFFFFF),
            labelStyle: TextStyle(color: Color(0xFF94A3B8)),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0x1FFFFFFF)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFEF4444)),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
