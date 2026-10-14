# Offline Test Sample Frames

This directory holds offline sample frames captured from the ESP32-CAM (or standard camera) for offline pipeline validation, regression testing, and mock inference when no ESP32-CAM hardware is reachable.

## Supported Formats
- JPEG (`.jpg`, `.jpeg`)
- Resolution: `320x240` (QVGA) or `640x480` (VGA)

## Standard Test Cases
- `corridor_obstacles.jpg`: Indoor hallway with chairs, doors, and pedestrian paths.
- `street_hazard.jpg`: Sidewalk with stairs, bollards, and oncoming pedestrians.
- `indoor_person.jpg`: Clear full-body view for gait estimation and tracking testing.

## Usage in VisionAssist
The app's offline test harnesses and development mocks load images from this directory to test:
1. `YoloDetector.detect()` tensor preprocessing & postprocessing logic.
2. `ObjectTracker.update()` track lifecycle and speed estimation across consecutive sample frames.
3. `VisiblePersonGaitAnalyzer.update()` bounding box aspect ratio and oscillation calculations.
