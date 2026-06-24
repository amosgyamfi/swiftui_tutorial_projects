# Realtime Object Detection

`RealtimeObjectDetection.swift` is a full-screen SwiftUI camera experience that detects objects on a physical iOS device, draws live bounding boxes, runs text-prompted SAM 3 segmentation, and lets the user ask questions about the detected scene with typed or spoken prompts.

The app combines on-device camera capture, RF-DETR Core AI object detection, SAM 3 Core AI segmentation, Apple Intelligence through Foundation Models, and SpeechAnalyzer/SpeechTranscriber dictation. The goal is to keep the entire workflow local to the device where the required Apple frameworks and model assets are available.

## What It Does

- Shows the device camera full-screen using `AVCaptureSession` and `AVCaptureVideoPreviewLayer`.
- Runs RF-DETR object detection on sampled camera frames.
- Draws colored bounding boxes and labels over detected objects.
- Lets the user switch between RF-DETR Nano, Small, Medium, and Large.
- Downloads missing `.aimodel` bundles from Hugging Face on demand.
- Lets the user pause and resume live detection.
- Runs SAM 3 text-prompted segmentation against the latest camera frame.
- Overlays tinted segmentation masks and dashed segment boxes on the camera.
- Summarizes the current scene from detected object labels and counts.
- Accepts typed questions about the current scene.
- Accepts voice questions with SpeechAnalyzer and SpeechTranscriber.
- Answers questions with Apple's on-device Foundation Models API when Apple Intelligence is available.
- Uses SwiftUI Liquid Glass surfaces for the toolbar, tab bar, prompt panel, model picker, and status strip.

## Main Files

- `RealtimeObjectDetection.swift`: SwiftUI camera UI, detection state, model selection, overlays, and Foundation Models question answering.
- `ModelDownloader.swift`: shared Hugging Face downloader for Core AI `.aimodel` directory bundles and segmenter bundle roots.
- `DictationController.swift`: voice input using `SpeechAnalyzer` and `SpeechTranscriber`.
- `coreai-models/swift/Sources/CoreAIObjectDetector/ObjectDetector.swift`: Core AI object detector wrapper.
- `coreai-models/swift/Sources/CoreAIObjectDetector/DetectionPostprocessor.swift`: RF-DETR/DETR output decoding.
- `coreai-models/swift/Sources/CoreAIImageSegmenter/ImageSegmenter.swift`: high-level SAM 3 segmentation runner.
- `coreai-models/swift/Sources/CoreAIImageSegmenter/ImageSegmentationEngine.swift`: Core AI segmentation engine.

## User Interface

The screen is built as a `ZStack`:

1. 1The camera preview fills the screen.
2. 2`DetectionOverlay` renders bounding boxes in camera coordinates.
3. 3Liquid Glass controls float over the camera feed.

The top toolbar contains:

- Model menu: selects Nano, Small, Medium, or Large.
- Loading spinner: appears while a model downloads or loads.
- Pause/resume button: toggles live detection.
- Download button: fetches the selected model again when needed.

The bottom tab bar has four modes:

- `Detect`: shows the live detection status and object count.
- `Segment`: opens the SAM 3 text prompt and mask-generation controls.
- `Ask`: opens the typed/voice question composer and answer panel.
- `Models`: opens the RF-DETR model picker.

## Object Detection Flow

The detection pipeline is:

1. 1`AVCaptureSession` captures camera frames from the back wide-angle camera.
2. 2`AVCaptureVideoDataOutput` provides 32BGRA sample buffers.
3. 3`CoreImage` converts each sample buffer into a `CGImage`.
4. 4`RealtimeObjectDetectionStore.receive(frame:)` throttles inference by model size.
5. 5`ObjectDetector` loads the selected `.aimodel` with Apple's Core AI framework.
6. 6The detector preprocesses the image into RGB `[1, 3, R, R]` float input.
7. 7Core AI runs the RF-DETR `main` function.
8. 8The postprocessor decodes `labels` and `dets` outputs into `DetectedObject` values.
9. 9SwiftUI maps each detection into an overlay rectangle and label.

RF-DETR is a DETR-style detector, so it does not use non-maximum suppression. The app applies a sigmoid to class logits, takes the highest class per query, filters by confidence, sorts by score, and keeps the top detections.

Current app parameters:

- Confidence threshold: `0.5`
- Max detections per frame: `20`
- Score transform: sigmoid
- Normalization: RGB values in `[0, 1]`; ImageNet mean/std is folded into the RF-DETR graph

## RF-DETR Core AI Models

The app uses the [RF-DETR-CoreAI](https://huggingface.co/mlboydaisuke/RF-DETR-CoreAI) models from the [coreai-model-zoo](https://github.com/john-rocky/coreai-model-zoo).


The RF-DETR graph contract is:

```text
input  "image"  [1, 3, R, R]  float32 RGB in [0, 1]
output "dets"   [1, 300, 4]   normalized cx, cy, width, height boxes
output "labels" [1, 300, 91]  raw COCO class logits
```

The local `ObjectDetector` wrapper recognizes `labels` as the logits output and `dets` as the bounding-box output. COCO class IDs are mapped to readable labels such as `person`, `dog`, `car`, and `laptop`.

## SAM 3 Core AI Segmentation

The Segment tab adds text-prompted segmentation with SAM 3. It uses the Core AI segmenter APIs from Apple's `coreai-models` package and downloads a pre-exported bundle from [mlboydaisuke/sam3-CoreAI-official](https://huggingface.co/mlboydaisuke/sam3-CoreAI-official).

The app runs SAM 3 as a single-shot action against the latest camera frame:

1. 1The user enters a prompt such as `person`, `cup`, `dog`, or `laptop`.
2. 2The app downloads SAM 3 if the segmenter bundle is missing.
3. 3`ImageSegmenter(resourcesAt:)` loads the segmenter bundle.
4. 4The prompt is tokenized with the bundle's CLIP tokenizer.
5. 5Core AI runs SAM 3 on the latest camera `CGImage`.
6. 6`SegmentationPostprocessor` converts mask logits into binary masks and segment boxes.
7. 7SwiftUI overlays tinted masks and dashed boxes over the live camera preview.

The SAM 3 bundle layout is:

```text
sam3_float16/
  metadata.json
  sam3_float16.aimodel/
    main.hash
    main.mlirb
    metadata.json
  tokenizer/
    tokenizer.json
    tokenizer_config.json
```

The app stores the downloaded bundle under:

```text
models/segmentation/sam3_float16
```

SAM 3 is promptable segmentation rather than object detection. RF-DETR continuously proposes object boxes and labels; SAM 3 produces pixel masks for a text prompt when the user asks for a segment.

## Model Downloading

RF-DETR models are stored in the app's documents directory under:

```text
models/object-detection
```

SAM 3 is stored under:

```text
models/segmentation
```

`ModelDownloader` uses the Hugging Face model tree API to download each Core AI directory as a bundle. A Core AI `.aimodel` is a directory, not a single file, so the downloader fetches files such as:

- `main.mlirb`
- `main.hash`
- `metadata.json`

For SAM 3, the downloader fetches a full segmenter bundle root, including `metadata.json`, `sam3_float16.aimodel`, and `tokenizer`. Downloads are staged into a hidden temporary directory and moved into place only after every file succeeds. This prevents Core AI from seeing a partial model bundle.

## Asking About The Scene

The `Ask` tab sends a compact scene summary to `LanguageModelSession` from the Foundation Models framework.

The prompt includes:

- A count-based summary, for example `1 person, 1 laptop, 1 cup`
- Up to 20 current detections with labels and confidence scores
- Current SAM 3 segment summaries when masks are available
- The user's typed or dictated question

The app streams the model response back into the answer panel. This depends on Apple Intelligence availability through `SystemLanguageModel.default.availability`.

## Voice Input

Voice input is handled by `DictationController`.

The dictation pipeline is:

```text
Microphone
-> AVAudioEngine input tap
-> AVAudioConverter
-> AsyncStream<AnalyzerInput>
-> SpeechAnalyzer
-> SpeechTranscriber.results
-> prompt text field
```

`SpeechTranscriber` reports volatile and final transcription results. Volatile text updates the prompt while the user is speaking; final text is committed into the prompt. If a locale speech asset is missing, `AssetInventory` downloads and installs the required on-device asset.

## Platform Requirements

The live detector branch is compiled only for:

```swift
#if os(iOS) && !targetEnvironment(simulator)
```

This is intentional. RF-DETR detection depends on the device-only Core AI framework and camera access. The simulator build shows a `ContentUnavailableView` instead of trying to load Core AI detection.

Required runtime capabilities:

- Physical iOS device
- Camera permission
- Microphone permission for voice prompts
- Network access to download RF-DETR `.aimodel` bundles
- Network access to download the SAM 3 segmenter bundle
- Apple Intelligence availability for Foundation Models answers
- SpeechTranscriber asset availability for the selected locale

## Important Implementation Details

- Detection runs on throttled camera frames to avoid stacking inference work.
- Only one frame is processed at a time with `isProcessingFrame`.
- Larger models use longer minimum frame intervals.
- Detection boxes are converted from normalized RF-DETR `cxcywh` into pixel `CGRect` values.
- SAM 3 masks are converted from binary mask arrays into transparent tinted `CGImage` overlays.
- Overlay placement accounts for the full-screen aspect-fill camera preview.
- The selected detector instance is cached until the user switches models.
- The SAM 3 segmenter instance is cached after first load.
- A warmup pass runs after loading a model to trigger backend setup before live inference.
- Liquid Glass controls use `.glassEffect`, `.buttonStyle(.glass)`, and `.buttonStyle(.glassProminent)` for iOS 26+ visual treatment.

## Troubleshooting

If the app says a model is not downloaded, select the model and tap the cloud download button.

If object detection reports an invalid configuration, confirm that the selected model directory contains a full `.aimodel` bundle with `main.mlirb`, `main.hash`, and `metadata.json`. Partial downloads should normally be avoided by the staged downloader, but deleting the affected model directory and downloading again is a safe recovery path.

If SAM 3 segmentation fails to load, confirm that `models/segmentation/sam3_float16` contains the root `metadata.json`, the `sam3_float16.aimodel` directory, and `tokenizer/tokenizer.json`.

If the app runs in Simulator, detection is unavailable by design. Build and run on a physical iOS device to use RF-DETR Core AI detection.
