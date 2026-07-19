# Phase H Context - Enterprise Production Hardening & Reliability

## Overview
Phase H focused on elevating SentinVMS to a production-ready, enterprise-grade application by introducing global uncaught error boundaries, network auto-retry with exponential backoff, app lifecycle resource management, network connectivity state indicators, and multi-environment configuration switching.

## Key Components Touched & Added
- `main.dart`: Enclosed runtime in `runZonedGuarded` with `FlutterError.onError` & `PlatformDispatcher.instance.onError` global crash traps.
- `app_config.dart`: Environment configuration system supporting `dev`, `staging`, and `prod` targets.
- `dio_retry_interceptor.dart`: Dio HTTP interceptor providing automatic exponential backoff retry (1s, 2s, 4s) on transient network drops and server 50x errors.
- `dio_factory.dart`: Integrated `DioRetryInterceptor` into Dio pipeline.
- `connectivity_service.dart`: Live stream connectivity listener checking network status periodically.
- `connectivity_banner.dart`: Tactical non-intrusive animated status bar overlay notifying operators of network dropouts.
- `app_lifecycle_observer.dart`: `WidgetsBindingObserver` auto-throttling WebSocket heartbeats and decoders when backgrounded.
- `app.dart`: Wrapped application router builder with global `ConnectivityBanner`.
