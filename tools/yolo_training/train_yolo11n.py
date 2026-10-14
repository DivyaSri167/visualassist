#!/usr/bin/env python3
"""
VisionAssist -- YOLO11n Custom Training Pipeline
================================================
Trains a YOLO11n model for mobility-specific object detection, then exports
to TFLite (Float32 and INT8 quantised) for on-device inference in the
VisionAssist Android app.

Usage
-----
  # 1. Install dependencies (run once)
  pip install ultralytics onnx onnx2tf tensorflow onnxruntime

  # 2. Train on default COCO128 sample dataset
  python train_yolo11n.py

  # 3. Export only (already trained)
  python train_yolo11n.py --export-only --weights runs/train/vision_assist/weights/best.pt

  # 4. Validate existing TFLite
  python train_yolo11n.py --validate-only --tflite export/yolo11n_float32.tflite

Environment
-----------
  Windows / Linux / macOS
  Python 3.10 or 3.11
  CUDA GPU recommended (CPU fallback works but is slow)
  ~4 GB VRAM minimum for YOLO11n batch=16

Outputs
-------
  runs/train/vision_assist/weights/best.pt   PyTorch weights
  export/yolo11n.onnx                        ONNX graph
  export/yolo11n_saved_model/                TF SavedModel
  export/yolo11n_float32.tflite             Float32 TFLite  <-- copy to app
  export/yolo11n_int8.tflite                INT8 TFLite (optional)

  Final destination in Flutter project:
    assets/models/yolo11n.tflite
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import textwrap
from pathlib import Path


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
class TrainingConfig:
    MODEL_NAME = "yolo11n.pt"

    # Override with custom mobility-hazard dataset.yaml for production use.
    # A custom dataset should include: stairs, curb, pothole, door, tactile_paving
    DATA_YAML = "coco128.yaml"

    EPOCHS = 100
    IMAGE_SIZE = 320       # Must match YoloConfig.defaultInputSize in Dart code
    BATCH_SIZE = 16
    WORKERS = 4
    PATIENCE = 20
    DEVICE = "0"           # "0" = first CUDA GPU, "cpu" = force CPU

    AUGMENT_MOSAIC = 1.0
    AUGMENT_DEGREES = 5.0  # Small rotation: cameras are hat-mounted
    AUGMENT_TRANSLATE = 0.1
    AUGMENT_SCALE = 0.5
    AUGMENT_FLIPLR = 0.5

    EXPORT_DIR = Path("export")
    ONNX_PATH = EXPORT_DIR / "yolo11n.onnx"
    TFLITE_F32_PATH = EXPORT_DIR / "yolo11n_float32.tflite"
    TFLITE_INT8_PATH = EXPORT_DIR / "yolo11n_int8.tflite"
    TFLITE_TARGET_NAME = "yolo11n.tflite"

    # Paths to representative JPEG images for INT8 PTQ calibration.
    # Leave empty to skip INT8 (Float32 is the default for VisionAssist).
    INT8_REPRESENTATIVE_IMAGES: list[str] = []


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def run(cmd: list[str]) -> None:
    print(f"\n>> {' '.join(cmd)}\n")
    result = subprocess.run(cmd, check=False)
    if result.returncode != 0:
        print(f"\nERROR: command exited with code {result.returncode}", file=sys.stderr)
        sys.exit(result.returncode)


def ensure_packages() -> None:
    required = ["ultralytics", "onnx", "onnx2tf", "tensorflow", "onnxruntime"]
    for pkg in required:
        try:
            __import__(pkg.replace("-", "_"))
        except ImportError:
            print(f"Installing {pkg}...")
            run([sys.executable, "-m", "pip", "install", pkg, "-q"])


# ---------------------------------------------------------------------------
# Step 1 - Training
# ---------------------------------------------------------------------------
def train(cfg: TrainingConfig) -> Path:
    from ultralytics import YOLO

    print("\n" + "=" * 60)
    print("  STEP 1 -- Training YOLO11n")
    print("=" * 60)

    model = YOLO(cfg.MODEL_NAME)
    model.train(
        data=cfg.DATA_YAML,
        epochs=cfg.EPOCHS,
        imgsz=cfg.IMAGE_SIZE,
        batch=cfg.BATCH_SIZE,
        workers=cfg.WORKERS,
        patience=cfg.PATIENCE,
        device=cfg.DEVICE,
        name="vision_assist",
        degrees=cfg.AUGMENT_DEGREES,
        translate=cfg.AUGMENT_TRANSLATE,
        scale=cfg.AUGMENT_SCALE,
        fliplr=cfg.AUGMENT_FLIPLR,
        mosaic=cfg.AUGMENT_MOSAIC,
        hsv_h=0.015,
        hsv_s=0.7,
        hsv_v=0.4,
        optimizer="AdamW",
        lr0=0.001,
        lrf=0.01,
        warmup_epochs=3,
        close_mosaic=10,
        seed=42,
        deterministic=True,
    )

    best_weights = Path("runs/train/vision_assist/weights/best.pt")
    if not best_weights.exists():
        candidates = sorted(Path("runs/train").glob("vision_assist*/weights/best.pt"))
        if candidates:
            best_weights = candidates[-1]
        else:
            print("ERROR: Training produced no weights.", file=sys.stderr)
            sys.exit(1)

    print(f"\nOK Training complete. Best weights: {best_weights}")
    return best_weights


# ---------------------------------------------------------------------------
# Step 2 - ONNX Export
# ---------------------------------------------------------------------------
def export_onnx(weights_path: Path, cfg: TrainingConfig) -> Path:
    from ultralytics import YOLO

    print("\n" + "=" * 60)
    print("  STEP 2 -- Exporting to ONNX")
    print("=" * 60)

    cfg.EXPORT_DIR.mkdir(parents=True, exist_ok=True)

    model = YOLO(str(weights_path))
    model.export(
        format="onnx",
        imgsz=cfg.IMAGE_SIZE,
        opset=12,
        simplify=True,
        dynamic=False,
    )

    onnx_src = weights_path.with_suffix(".onnx")
    if not onnx_src.exists():
        onnx_src = weights_path.parent / "best.onnx"

    shutil.copy(str(onnx_src), str(cfg.ONNX_PATH))
    print(f"\nOK ONNX model saved to {cfg.ONNX_PATH}")
    return cfg.ONNX_PATH


# ---------------------------------------------------------------------------
# Step 3a - TFLite Float32
# ---------------------------------------------------------------------------
def export_tflite_float32(onnx_path: Path, cfg: TrainingConfig) -> Path:
    """Converts ONNX -> SavedModel -> Float32 TFLite."""

    print("\n" + "=" * 60)
    print("  STEP 3a -- Converting to TFLite Float32")
    print("=" * 60)

    saved_model_dir = cfg.EXPORT_DIR / "yolo11n_saved_model"

    run([
        sys.executable, "-m", "onnx2tf",
        "-i", str(onnx_path),
        "-o", str(saved_model_dir),
        "--non_verbose",
    ])

    import tensorflow as tf
    converter = tf.lite.TFLiteConverter.from_saved_model(str(saved_model_dir))
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
    converter.optimizations = []
    tflite_model = converter.convert()

    cfg.TFLITE_F32_PATH.parent.mkdir(parents=True, exist_ok=True)
    cfg.TFLITE_F32_PATH.write_bytes(tflite_model)
    size_kb = cfg.TFLITE_F32_PATH.stat().st_size // 1024
    print(f"\nOK Float32 TFLite: {cfg.TFLITE_F32_PATH}  ({size_kb} KB)")
    return cfg.TFLITE_F32_PATH


# ---------------------------------------------------------------------------
# Step 3b - TFLite INT8 (optional)
# ---------------------------------------------------------------------------
def export_tflite_int8(onnx_path: Path, cfg: TrainingConfig) -> Path | None:
    """Optional INT8 PTQ quantisation. Requires representative calibration images."""

    if not cfg.INT8_REPRESENTATIVE_IMAGES:
        print("\nWARN: Skipping INT8 export (no representative images configured).")
        print("      Set INT8_REPRESENTATIVE_IMAGES in TrainingConfig to enable.")
        return None

    print("\n" + "=" * 60)
    print("  STEP 3b -- Converting to TFLite INT8")
    print("=" * 60)

    import numpy as np
    import tensorflow as tf
    from PIL import Image as PILImage

    saved_model_dir = cfg.EXPORT_DIR / "yolo11n_saved_model"
    if not saved_model_dir.exists():
        print("ERROR: SavedModel not found. Run float32 export first.", file=sys.stderr)
        return None

    def representative_dataset():
        for img_path in cfg.INT8_REPRESENTATIVE_IMAGES:
            img = PILImage.open(img_path).convert("RGB").resize(
                (cfg.IMAGE_SIZE, cfg.IMAGE_SIZE)
            )
            arr = np.array(img, dtype=np.float32) / 255.0
            yield [arr[np.newaxis, ...]]

    converter = tf.lite.TFLiteConverter.from_saved_model(str(saved_model_dir))
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.representative_dataset = representative_dataset
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
    converter.inference_input_type = tf.float32
    converter.inference_output_type = tf.float32

    try:
        tflite_model = converter.convert()
        cfg.TFLITE_INT8_PATH.write_bytes(tflite_model)
        size_kb = cfg.TFLITE_INT8_PATH.stat().st_size // 1024
        print(f"\nOK INT8 TFLite: {cfg.TFLITE_INT8_PATH}  ({size_kb} KB)")
        return cfg.TFLITE_INT8_PATH
    except Exception as exc:
        print(f"\nERROR INT8 export failed: {exc}", file=sys.stderr)
        return None


# ---------------------------------------------------------------------------
# Step 4 - Validation
# ---------------------------------------------------------------------------
def validate_tflite(tflite_path: Path, cfg: TrainingConfig) -> None:
    print("\n" + "=" * 60)
    print("  STEP 4 -- Validating TFLite Model")
    print("=" * 60)

    import numpy as np
    import tensorflow as tf

    interp = tf.lite.Interpreter(model_path=str(tflite_path))
    interp.allocate_tensors()

    inp = interp.get_input_details()
    out = interp.get_output_details()

    print(f"\nInput :  shape={inp[0]['shape']}  dtype={inp[0]['dtype']}")
    print(f"Output:  shape={out[0]['shape']}  dtype={out[0]['dtype']}")

    dummy = np.random.rand(1, cfg.IMAGE_SIZE, cfg.IMAGE_SIZE, 3).astype(np.float32)
    interp.set_tensor(inp[0]["index"], dummy)
    interp.invoke()
    result = interp.get_tensor(out[0]["index"])
    print(f"\nInference output shape: {result.shape}")
    print(f"Expected for COCO 80-class 320x320: (1, 84, 2100)")

    if list(result.shape) == [1, 84, 2100]:
        print("\nOK Output shape matches YOLO11n COCO 320x320 specification.")
    else:
        print(f"\nWARN: Output shape {result.shape} differs from expected (1, 84, 2100).")
        print("      If you used a custom class count, update in YoloDetector.dart:")
        print("        _numClasses = <your_class_count>")
        print("        _numBoxes   = <output_boxes>   (2100 for imgsz=320)")


# ---------------------------------------------------------------------------
# Step 5 - Copy to Flutter Assets
# ---------------------------------------------------------------------------
def copy_to_assets(tflite_path: Path, cfg: TrainingConfig) -> None:
    # Navigate from tools/yolo_training/ up two levels to project root, then into assets/
    assets_dir = Path(__file__).resolve().parent.parent.parent / "assets" / "models"
    assets_dir.mkdir(parents=True, exist_ok=True)
    dst = assets_dir / cfg.TFLITE_TARGET_NAME
    shutil.copy(str(tflite_path), str(dst))
    print(f"\nOK Copied model to Flutter assets: {dst}")
    print("\nNext: run 'flutter pub get' in the project root, then rebuild the APK.")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="VisionAssist YOLO11n Training Pipeline",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent("""
            Examples
            --------
              # Full pipeline
              python train_yolo11n.py

              # Custom dataset, 150 epochs
              python train_yolo11n.py --data mobility_hazards.yaml --epochs 150

              # Export only (skip training)
              python train_yolo11n.py --export-only --weights runs/train/vision_assist/weights/best.pt

              # Export + INT8
              python train_yolo11n.py --export-only --weights best.pt --int8

              # Validate existing TFLite only
              python train_yolo11n.py --validate-only --tflite export/yolo11n_float32.tflite
        """),
    )
    parser.add_argument("--data", default=None, help="Dataset YAML path")
    parser.add_argument("--epochs", type=int, default=None)
    parser.add_argument("--batch", type=int, default=None)
    parser.add_argument("--imgsz", type=int, default=None,
                        help="Input size (must be 320 for VisionAssist)")
    parser.add_argument("--device", default=None, help="'0' for GPU, 'cpu' for CPU")
    parser.add_argument("--weights", type=Path, default=None,
                        help="Existing .pt weights for --export-only")
    parser.add_argument("--export-only", action="store_true",
                        help="Skip training, use --weights")
    parser.add_argument("--validate-only", action="store_true",
                        help="Only validate TFLite (use --tflite)")
    parser.add_argument("--tflite", type=Path, default=None,
                        help="TFLite path for --validate-only")
    parser.add_argument("--int8", action="store_true",
                        help="Export INT8 quantised model in addition to Float32")
    parser.add_argument("--no-copy", action="store_true",
                        help="Skip copying model to Flutter assets/")
    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    ensure_packages()

    cfg = TrainingConfig()

    if args.data:
        cfg.DATA_YAML = args.data
    if args.epochs:
        cfg.EPOCHS = args.epochs
    if args.batch:
        cfg.BATCH_SIZE = args.batch
    if args.imgsz:
        cfg.IMAGE_SIZE = args.imgsz
    if args.device:
        cfg.DEVICE = args.device

    # -- Validate only
    if args.validate_only:
        tflite_path = args.tflite or cfg.TFLITE_F32_PATH
        if not Path(tflite_path).exists():
            print(f"ERROR: TFLite not found at {tflite_path}", file=sys.stderr)
            sys.exit(1)
        validate_tflite(Path(tflite_path), cfg)
        return

    # -- Determine weights
    if args.export_only:
        if args.weights is None or not args.weights.exists():
            print("ERROR: --export-only requires --weights <path/to/best.pt>",
                  file=sys.stderr)
            sys.exit(1)
        best_weights = args.weights
    else:
        best_weights = train(cfg)

    # -- Export chain
    onnx_path = export_onnx(best_weights, cfg)
    tflite_path = export_tflite_float32(onnx_path, cfg)

    if args.int8:
        int8_path = export_tflite_int8(onnx_path, cfg)
        if int8_path:
            tflite_path = int8_path

    validate_tflite(tflite_path, cfg)

    if not args.no_copy:
        copy_to_assets(tflite_path, cfg)

    print("\n" + "=" * 60)
    print("  PIPELINE COMPLETE")
    print("=" * 60)
    print(f"\n  Model: {tflite_path}")
    print("\n  Next steps:")
    print("    1.  flutter pub get")
    print("    2.  flutter build apk --release")
    print("    3.  Install APK and test 'Walking Assistance' on device.")
    print("=" * 60 + "\n")


if __name__ == "__main__":
    main()
