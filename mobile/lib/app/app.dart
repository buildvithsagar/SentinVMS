import 'package:app/app/router.dart';
import 'package:app/core/auth/auth_bloc.dart';
import 'package:app/core/network/connectivity_service.dart';
import 'package:app/core/theme/vms_theme.dart';
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
        theme: VmsTheme.dark,
      ),
    );
  }
}
