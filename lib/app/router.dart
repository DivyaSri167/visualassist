import 'package:go_router/go_router.dart';

import '../features/camera/presentation/captured_image_screen.dart';
import '../features/camera/presentation/live_camera_screen.dart';
import '../features/device_connection/presentation/connection_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/object_detection/presentation/object_detection_screen.dart';
import '../features/safety/presentation/safety_screen.dart';
import '../features/scene_understanding/presentation/scene_understanding_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/text_reader/presentation/text_reader_screen.dart';
import '../features/voice_assistant/presentation/voice_assistant_screen.dart';
import '../features/walking_assistance/presentation/walking_assistance_screen.dart';

/// Central application navigation router using go_router.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/connection',
      name: 'connection',
      builder: (context, state) => const DeviceConnectionScreen(),
    ),
    GoRoute(
      path: '/camera/live',
      name: 'camera_live',
      builder: (context, state) => const LiveCameraScreen(),
    ),
    GoRoute(
      path: '/camera/capture',
      name: 'camera_capture',
      builder: (context, state) => const CapturedImageScreen(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/walking-assistance',
      name: 'walking_assistance',
      builder: (context, state) => const WalkingAssistanceScreen(),
    ),
    // Roadmap placeholders
    GoRoute(
      path: '/features/object-detection',
      name: 'object_detection',
      builder: (context, state) => const ObjectDetectionScreen(),
    ),
    GoRoute(
      path: '/features/text-reader',
      name: 'text_reader',
      builder: (context, state) => const TextReaderScreen(),
    ),
    GoRoute(
      path: '/features/scene-understanding',
      name: 'scene_understanding',
      builder: (context, state) => const SceneUnderstandingScreen(),
    ),
    GoRoute(
      path: '/features/voice-assistant',
      name: 'voice_assistant',
      builder: (context, state) => const VoiceAssistantScreen(),
    ),
    GoRoute(
      path: '/features/safety',
      name: 'safety',
      builder: (context, state) => const SafetyScreen(),
    ),
  ],
);
