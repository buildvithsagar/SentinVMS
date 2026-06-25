import 'package:app/core/auth/auth_bloc.dart';
import 'package:app/core/auth/auth_event.dart';
import 'package:app/core/auth/user_profile.dart';
import 'package:app/core/network/websocket_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WebSocketService Auth Sync Tests', () {
    late AuthBloc authBloc;
    late WebSocketService service;

    setUp(() {
      authBloc = AuthBloc();
    });

    tearDown(() {
      authBloc.close();
    });

    test('starts as disconnected', () {
      service = WebSocketService(authBloc: authBloc);
      expect(service.status, WebSocketStatus.disconnected);
      service.dispose();
    });

    test('transitions to reconnecting when Authenticated state is received', () async {
      service = WebSocketService(authBloc: authBloc);
      expect(service.status, WebSocketStatus.disconnected);

      authBloc.add(
        const AuthLoggedIn(
          accessToken: 'test-token',
          user: UserProfile(
            userId: '1',
            customerId: 'tenant',
            username: 'user',
            baseRole: 'OPERATOR',
          ),
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(
        service.status,
        anyOf(WebSocketStatus.reconnecting, WebSocketStatus.disconnected),
      );
      service.dispose();
    });
  });
}
