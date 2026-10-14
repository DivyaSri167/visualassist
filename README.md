# VisionAssist

> **AI-Powered Edge Computer Vision, Multi-Object Tracking, Footstep Counting, and Directional Walking Assistance for Blind and Low-Vision Individuals**

VisionAssist is an accessibility-first Android mobile application built with Flutter, Riverpod, and edge TensorFlow Lite. It connects to an **AI-Thinker ESP32-CAM (OV2640)** Wi-Fi camera, processes real-time MJPEG video frames using an edge-optimized **YOLO11n** neural network, tracks obstacles with spatial trajectory estimation, and vocalizes directional walking instructions through Bluetooth earphones—all while maintaining local smartphone sensor step counting.

---

## 🏛️ System Architecture

```
 ┌──────────────────────────┐
 │  AI-Thinker ESP32-CAM    │
 │  • OV2640 Sensor         │
 │  • Wi-Fi AP Mode         │
 │  • http://192.168.4.1    │
 │    ├─ /stream   (MJPEG)  │
 │    ├─ /capture  (JPEG)   │
 │    └─ /status   (JSON)   │
 └─────────────┬────────────┘
               │ HTTP MJPEG Stream (802.11 b/g/n)
               ▼
 ┌─────────────────────────────────────────────────────────────┐
 │                VisionAssist Android App                     │
 │                                                             │
 │  ┌───────────────────────────────────────────────────────┐  │
 │  │              CameraStreamService & Queue              │  │
 │  │  • Non-blocking frame queue & boundary parser         │  │
 │  │  • FPS & bandwidth diagnostics                        │  │
 │  └──────────────────────────┬────────────────────────────┘  │
 │                             ▼                               │
 │  ┌───────────────────────────────────────────────────────┐  │
 │  │             Edge YOLO11n TFLite Detector              │  │
 │  │  • 320x320 Letterboxing & Float32 normalization       │  │
 │  │  • Output shape: [1, 84, 2100] (Boxes + 80 COCO)      │  │
 │  │  • NMS (IoU 0.45) & Direction Zone mapping (L/C/R)    │  │
 │  └──────────────────────────┬────────────────────────────┘  │
 │                             ▼                               │
 │  ┌───────────────────────────────────────────────────────┐  │
 │  │             Multi-Object Tracker (IoU)                │  │
 │  │  • Temporal track association across frames           │  │
 │  │  • Approaching hazard detection (size expansion >25%) │  │
 │  │  • Ghost-rejection (min 2 consecutive hits)           │  │
 │  └──────────────────────────┬────────────────────────────┘  │
 │                             ▼                               │
 │  ┌───────────────────────────────────────────────────────┐  │
 │  │         Directional Speech Announcement Engine        │  │
 │  │  • Modes: A (Hazards), B (All), C (Walking Path)      │  │
 │  │  • Priority queue with deduplication & cooldown       │  │
 │  └──────────────────────────┬────────────────────────────┘  │
 │                             │                               │
 │  ┌──────────────────────────┴────────────────────────────┐  │
 │  │        Step Counter & Visible Person Gait Analyzer    │  │
 │  │  • Phone: Native pedometer + Accelerometer fallback   │  │
 │  │  • Camera: Visible person stride & bounce estimator   │  │
 │  │  • Clear "Estimate" labeling for user safety          │  │
 │  └───────────────────────────────────────────────────────┘  │
 └─────────────────────────────┬───────────────────────────────┘
                               │ Bluetooth A2DP / Low Latency
                               ▼
 ┌─────────────────────────────────────────────────────────────┐
 │      Bone-Conduction / Open-Ear Bluetooth Earphones         │
 │      "Caution: chair ahead center zone, 2 steps away"       │
 └─────────────────────────────────────────────────────────────┘
```

---

## ✨ Key Features

### 1. Ultra-Low-Latency Edge Detection (YOLO11n)
- **Model Format:** TensorFlow Lite Float32 (or INT8 Post-Training Quantized).
- **Input Resolution:** 320×320×3 RGB (aspect-preserving letterbox with symmetric padding).
- **Output Tensor:** `[1, 84, 2100]` anchors containing 4 bounding-box coordinates + 80 COCO classification scores.
- **Directional Zones:** Automatically maps each object's horizontal centroid into **Left** ($< 0.35$), **Center** ($0.35 - 0.65$), or **Right** ($> 0.65$).

### 2. Multi-Object Tracking & Proximity Escalation
- Fast IoU-based tracking associates detections across consecutive frames.
- Rejects single-frame sensor noise (`isReliable` requires $\ge 2$ consecutive confirmations).
- Analyzes normalized bounding box area growth: if an object's bounding box expands by $> 25\%$, it is flagged as **Approaching**, jumping to the front of the speech priority queue.

### 3. Directional Spoken Assistance Engine
Integrated with `flutter_tts`, routing announcements according to three user-selectable modes:
- **Mode A (Important Only):** Focuses exclusively on high-priority hazards (pedestrians, vehicles, stairs, doors, drop-offs).
- **Mode B (All Objects):** Describes all detected obstacles meeting the confidence threshold.
- **Mode C (Walking Guidance):** High-priority focus on obstacles located directly in the center walking path.
- Configurable cooldown timer (default: 5 seconds) prevents repetitive audio chatter.

### 4. Dual Footstep Counting & Gait Estimation
- **User Phone Pedometer:** Uses Android's hardware step sensor (`pedometer` plugin). Automatically falls back to a 3-axis gravity-separated linear acceleration peak detector with exponential smoothing if hardware pedometer sensors are absent.
- **Visible Person Gait Estimator:** Evaluates visible pedestrians in the camera field of view through vertical center bounce and aspect ratio oscillations. Includes explicit safety guards that reject estimates if camera FPS drops below 4.0 or feet are occluded at the frame border.
- **Mandatory Safety Label:** Every step reading is explicitly communicated as an estimate:
  > *"You have taken approximately 142 steps. This is an estimate, not a verified step count."*

### 5. High-Contrast Accessible Design
- Built in accordance with WCAG AAA accessibility guidelines.
- Amber-on-slate color palette (`#FFC107` on `#0F172A`) for maximum visual legibility for low-vision users.
- Minimum touch target sizing $\ge 48\times48\text{ dp}$ (buttons $\ge 56-58\text{ dp}$).
- Full TalkBack and screen-reader semantics annotations on all interactive controls.

---

## 🛠️ Hardware Requirements & Wiring

| Component | Description | Recommended Specification |
| :--- | :--- | :--- |
| **Microcontroller** | AI-Thinker ESP32-CAM | With OV2640 Camera Module |
| **Power Supply** | Dedicated 5V regulator | $\ge 2.0\text{ A}$ (prevent Wi-Fi brownouts) |
| **Programmer** | FTDI USB-to-TTL Adapter | Set to 3.3V logic (GPIO0 to GND for flash) |
| **Audio** | Bluetooth Earphones | Bone-conduction or open-ear (maintains ambient ear canal awareness) |
| **Phone** | Android Smartphone | Android 8.0+ (API 26+) with Wi-Fi & Bluetooth |

### ESP32-CAM Default Endpoints
When booted in Access Point (AP) mode:
- **Default IP:** `http://192.168.4.1`
- **MJPEG Stream:** `http://192.168.4.1/stream`
- **High-Res Still Capture:** `http://192.168.4.1/capture`
- **Sensor Status:** `http://192.168.4.1/status`

---

## 🤖 YOLO11n Training & Export Pipeline

The training and TFLite conversion pipeline is maintained independently in `tools/yolo_training/`.

### Setup
```bash
cd tools/yolo_training
python -m venv venv

# On Windows:
.\venv\Scripts\activate
# On Linux/macOS:
source venv/bin/activate

pip install -r requirements.txt
```

### Export Pre-Trained YOLO11n to 320x320 TFLite
```bash
python train_yolo11n.py --export-only --input-size 320
```
This script:
1. Downloads official `yolo11n.pt` from Ultralytics.
2. Exports to ONNX with static shape `[1, 3, 320, 320]`.
3. Runs `onnx2tf` to generate a TensorFlow Lite model with output `[1, 84, 2100]`.
4. Copies the output file directly to `assets/models/yolo11n.tflite`.

### INT8 Post-Training Quantization (PTQ)
```bash
python train_yolo11n.py --export-only --input-size 320 --int8
```

### Custom Dataset Training
```bash
python train_yolo11n.py --data path/to/dataset.yaml --epochs 50 --batch 16 --input-size 320
```

---

## 📱 Mobile App Setup & Execution

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (version 3.24+ or 3.47+)
- Android SDK (API level 26 minimum, API level 34 target)

### Install Dependencies
```bash
flutter pub get
```

### Run Unit Tests
```bash
flutter test
```

### Run Analyzer
```bash
flutter analyze
```

### Build Release APK
```bash
flutter build apk --release
```

---

## 🧭 Navigation Structure

- **`/home` (Home Screen):** Camera connectivity status banner, live preview card, quick feature buttons, and direct **Start Walking Assistance** primary button.
- **`/camera` (Live Stream):** Fullscreen ESP32-CAM MJPEG stream with pan/zoom and one-tap high-resolution snapshot capture.
- **`/walking-assistance` (Walking Guidance):** Live detection bounding box overlays with direction zone indicators (Left/Center/Right), real-time path hazard warnings, step counter stats, and audible guidance controls.
- **`/voice-assistant` (Voice Assistant Screen):** TTS speech engine status, on-demand speech tester, audio presets, and Bluetooth earphone guidance.
- **`/settings` (Configuration Screen):** ESP32-CAM host address settings, YOLO11n model loader, confidence & cooldown sliders, announcement mode radio selectors, and pedometer calibration.

---

## ⚠️ Assistive Technology & Safety Disclaimer

> **IMPORTANT NOTICE:**  
> VisionAssist is an **experimental assistive technology prototype**. It is designed to supplement, but **never replace**, primary mobility aids such as white canes, guide dogs, or certified orientation & mobility (O&M) instruction.
>
> - Camera-based detection can fail under extreme backlight, low lighting, camera lens smudges, motion blur, or unexpected physical barriers (e.g., clear glass doors, low-hanging wires, curbs).
> - Step counts and cadence figures are **estimates** and are explicitly labeled as such.
> - Users must always exercise caution and maintain physical environmental awareness while navigating.

---

## 📄 License
This project is licensed under the MIT License.
