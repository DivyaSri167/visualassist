# YOLO11n Training & TFLite Conversion Pipeline

This directory contains the Python training and conversion pipeline that trains a YOLO11n model or converts a pre-trained checkpoint to a 320x320 TFLite model optimized for VisionAssist on mobile devices.

## Requirements

Python 3.10 or 3.11 is recommended for smooth `onnx2tf` and TensorFlow 2.16 compatibility.

```bash
cd tools/yolo_training
python -m venv venv
# On Windows:
.\venv\Scripts\activate
# On Linux/macOS:
source venv/bin/activate

pip install -r requirements.txt
```

## Usage

### 1. Direct Export from Pretrained YOLO11n (Float32)
Converts official Ultralytics YOLO11n to 320x320 ONNX and then into TFLite Float32 with shape `[1, 84, 2100]` and copies it to `assets/models/yolo11n.tflite`:

```bash
python train_yolo11n.py --export-only --input-size 320
```

### 2. INT8 Post-Training Quantization (PTQ)
For faster inference on edge devices:

```bash
python train_yolo11n.py --export-only --input-size 320 --int8
```

### 3. Custom Training on Assistive / Hazard Dataset
To fine-tune on a custom dataset YAML:

```bash
python train_yolo11n.py --data path/to/dataset.yaml --epochs 50 --batch 16 --input-size 320
```

### 4. Validation Only
Verify existing model against test images without re-exporting:

```bash
python train_yolo11n.py --validate-only --tflite-path ../../assets/models/yolo11n.tflite
```

## Model Output Format

- **Input Shape**: `[1, 320, 320, 3]` (Normalized RGB Float32 in [0.0, 1.0])
- **Output Shape**: `[1, 84, 2100]`
  - `84` = 4 bounding box coordinates `[cx, cy, w, h]` + 80 COCO class probabilities
  - `2100` = Total anchor predictions for 320x320 input
