import 'package:flutter_test/flutter_test.dart';
import 'package:vision_assist/features/device_connection/domain/connection_state.dart';
import 'package:vision_assist/features/device_connection/domain/device_status.dart';

void main() {
  group('DeviceConnectionState Tests', () {
    test('initial state defaults to disconnected with null properties', () {
      const state = DeviceConnectionState();
      expect(state.status, equals(ConnectionStatus.disconnected));
      expect(state.isConnected, isFalse);
      expect(state.isConnecting, isFalse);
      expect(state.isCameraReady, isFalse);
      expect(state.deviceStatus, isNull);
      expect(state.errorMessage, isNull);
    });

    test('isConnected returns true only for connected and streaming', () {
      for (final status in ConnectionStatus.values) {
        final state = DeviceConnectionState(status: status);
        if (status == ConnectionStatus.connected ||
            status == ConnectionStatus.streaming) {
          expect(
            state.isConnected,
            isTrue,
            reason: '$status should be connected',
          );
        } else {
          expect(
            state.isConnected,
            isFalse,
            reason: '$status should not be connected',
          );
        }
      }
    });

    test('isConnecting returns true for connecting and reconnecting', () {
      expect(
        const DeviceConnectionState(status: ConnectionStatus.connecting)
            .isConnecting,
        isTrue,
      );
      expect(
        const DeviceConnectionState(status: ConnectionStatus.reconnecting)
            .isConnecting,
        isTrue,
      );
      expect(
        const DeviceConnectionState(status: ConnectionStatus.connected)
            .isConnecting,
        isFalse,
      );
    });

    test('isCameraReady requires ready status and active connection', () {
      final readyStatus = DeviceStatus(
        device: 'Cap',
        camera: 'ready',
        ip: '192.168.4.1',
        sosCount: 0,
        timestamp: DateTime.now(),
      );

      final connectedState = DeviceConnectionState(
        status: ConnectionStatus.connected,
        deviceStatus: readyStatus,
      );
      expect(connectedState.isCameraReady, isTrue);

      final unavailState = DeviceConnectionState(
        status: ConnectionStatus.cameraUnavailable,
        deviceStatus: readyStatus,
      );
      expect(unavailState.isCameraReady, isFalse);
    });

    test(
      'copyWith clearError resets errorMessage and troubleshootingGuide',
      () {
        const state = DeviceConnectionState(
          status: ConnectionStatus.error,
          errorMessage: 'Failure',
          troubleshootingGuide: 'Fix it',
        );

        final cleared = state.copyWith(
          status: ConnectionStatus.connecting,
          clearError: true,
        );

        expect(cleared.status, equals(ConnectionStatus.connecting));
        expect(cleared.errorMessage, isNull);
        expect(cleared.troubleshootingGuide, isNull);
      },
    );
  });
}
