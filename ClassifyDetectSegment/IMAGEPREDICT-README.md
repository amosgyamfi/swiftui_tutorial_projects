# ImagePredict

A Core AI–powered vision studio for iOS 27. ImagePredict opens straight into a
full‑screen camera feed with a Liquid Glass toolbar and tab bar floating on top,
and turns a single live frame into four kinds of on‑device understanding:

| Tab | What it does | Engine |
| --- | --- | --- |
| **Classify** | Live image classification with a user‑chosen vision model | PVT v2 (ImageNet‑1k) or CLIP (zero‑shot) |
| **Detect** | Object detection + prediction with bounding boxes | RF‑DETR via `CoreAIObjectDetector` |
| **Segment** | Instance & semantic segmentation by text prompt | SAM 3 via `CoreAIImageSegmenter` |
| **Ask** | Natural‑language Q&A about the scene (text *or* voice) | Foundation Models + SpeechAnalyzer |

Pick your favorite Core AI vision model from the toolbar menu or the **Models**
tab: **PVT v2** (a supervised Pyramid Vision Transformer that classifies into the
1000 ImageNet categories) or **CLIP** (open‑vocabulary zero‑shot — type your own
labels and it recognizes them with no retraining).

## Files

| File | Role |
| --- | --- |
| `VideoImageClassifier.swift` | The ImagePredict app: camera, Liquid Glass chrome, tabs, and the `ImagePredictStore`. |
| `CoreAIVisionClassifier.swift` | `PVTClassifier` and `CLIPZeroShotClassifier` engines + the model catalog. |
| `ImageNetLabels.swift` | 1000 ImageNet‑1k class names used to decode PVT v2 logits. |

Object detection, segmentation, the model downloader, and dictation are shared
with `RealtimeObjectDetection` and `DictationController`.

## Requirements

- A physical iOS 27 device (Core AI is device‑only — the Simulator shows a
  placeholder).
- Apple Intelligence enabled for the **Ask** tab (Foundation Models).
- Camera and microphone permissions (already declared in the project).

## Getting the vision models

- **RF‑DETR** (Detect) and **SAM 3** (Segment) download automatically in‑app the
  first time you open those tabs.
- **PVT v2** and **CLIP** ship **bundled inside the app** — no download needed.
  They live in the `ImagePredictModels/` folder reference, which Xcode copies
  verbatim into `SwiftUIFor27.app/ImagePredictModels/`, and the app loads them
  from `Bundle.main` at launch.

### Regenerating the bundled models

PVT v2 and CLIP come from [`apple/coreai-models`](https://github.com/apple/coreai-models)
as **export recipes**, so the `.aimodel` files are produced locally rather than
committed (the CLIP model is ~289 MB, above GitHub's 100 MB per‑file limit, so
`ImagePredictModels/` is git‑ignored). After cloning, run the helper once:

```sh
./SwiftUIFor27/Apps/ImagePredict/build-models.sh
```

It exports both models (float16) and assembles:

```
ImagePredictModels/
├── pvt_v2_b0.aimodel/     # PVT v2  (~7 MB)
├── clip.aimodel/          # CLIP    (~289 MB)
└── clip-tokenizer/
    └── tokenizer.json     # CLIP BPE vocab + merges (pair format)
```

Then build and run on a device — both models are ready in the Classify tab.

The static export (default) is what ImagePredict targets: at load time the app
reads each model's input descriptors and adapts preprocessing, text batch size,
and sequence length to whatever the export produced.

### Overriding a bundled model

The **Models** tab also has **Replace … .aimodel** (and **Tokenizer** for CLIP),
which imports a freshly exported model into `Documents/models/classification/`.
A Documents copy takes precedence over the bundled one — handy for trying a
larger PVT variant or a different CLIP checkpoint without rebuilding.

## How classification works

- **PVT v2** — the frame is resized to 224×224 with ImageNet normalization and
  run through the `x → logits` graph. The top‑5 softmax probabilities are mapped
  to `ImageNetLabels`.
- **CLIP** — the frame is encoded once with CLIP normalization while each label
  ("a photo of a …") is tokenized with the bundled `CLIPTokenizer`. ImagePredict
  scores labels in batches that match the model's `input_ids` descriptor, then
  softmaxes `logits_per_image` across all of your labels. Add or remove labels
  live from the Classify tab — CLIP is zero‑shot, so no retraining is needed.

Both engines ride the low‑level Core AI runtime (`AIModel` / `InferenceFunction`
/ `NDArray`), the same path `CoreAIObjectDetector` uses.

## References

- PVT v2 — *Pyramid Vision Transformer* ([paper](https://arxiv.org/abs/2106.13797) · [code](https://github.com/whai362/PVT))
- CLIP — *Learning Transferable Visual Models From Natural Language Supervision* ([code](https://github.com/apple/coreai-models/tree/main/models/clip))
- [Apple Core AI](https://developer.apple.com/core-ai/)
