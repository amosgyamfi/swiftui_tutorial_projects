//
//  CoreAIVisionClassifier.swift
//  SwiftUIFor27
//
//  On-device image classification for the ImagePredict app, driven by two
//  Core AI vision models exported from apple/coreai-models:
//
//   * PVT v2 (Pyramid Vision Transformer) — supervised ImageNet-1k classifier.
//     A single image tensor `x` [1,3,224,224] → `logits` [1,1000].
//
//   * CLIP (Contrastive Language-Image Pretraining) — zero-shot classifier.
//     pixel_values + input_ids + attention_mask → logits_per_image, comparing
//     the frame against natural-language label prompts. Labels are fully
//     open-vocabulary: the user can type their own.
//
//  Both engines ride the low-level Core AI runtime (`AIModel` /
//  `InferenceFunction` / `NDArray`) the same way `CoreAIObjectDetector` does,
//  reusing `ImagePreprocessor` for normalization and `CLIPTokenizer` for text.
//

import CoreGraphics
import Foundation

// MARK: - Shared result type

/// One ranked classification prediction (0...1 confidence).
struct VisionClassification: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let confidence: Float
    let index: Int
}

/// Which Core AI vision model is driving live classification.
enum VisionModelKind: String, CaseIterable, Identifiable, Sendable {
    case pvtV2
    case clip

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pvtV2: "PVT v2"
        case .clip: "CLIP"
        }
    }

    var shortName: String {
        switch self {
        case .pvtV2: "PVT"
        case .clip: "CLIP"
        }
    }

    var symbolName: String {
        switch self {
        case .pvtV2: "rectangle.3.group.fill"
        case .clip: "text.below.photo.fill"
        }
    }

    var tagline: String {
        switch self {
        case .pvtV2: "ImageNet-1k supervised classifier (Pyramid Vision Transformer)."
        case .clip: "Zero-shot, open-vocabulary classifier. Bring your own labels."
        }
    }

    var isZeroShot: Bool { self == .clip }
}

// MARK: - Model catalog (install / side-load locations)

/// Resolves the exported `.aimodel` bundles for PVT v2 and CLIP.
///
/// The app ships both models inside its bundle (the `ImagePredictModels` folder
/// reference, copied verbatim into `SwiftUIFor27.app/ImagePredictModels/`), so
/// they work offline with no download. A user-imported copy in
/// `Documents/models/classification/` takes precedence when present, allowing a
/// freshly exported model to override the bundled one.
enum VisionModelCatalog {
    static let bundleSubdirectory = "ImagePredictModels"
    static let pvtBundleName = "pvt_v2_b0.aimodel"
    static let clipBundleName = "clip.aimodel"
    static let clipTokenizerName = "clip-tokenizer"

    /// Where user-imported overrides are stored.
    static var documentsRoot: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("models/classification")
    }

    static func pvtModelURL() -> URL? {
        resolve(name: pvtBundleName)
    }

    static func clipModelURL() -> URL? {
        resolve(name: clipBundleName)
    }

    /// Folder containing `tokenizer.json` for CLIP (Documents override, else bundle).
    static func clipTokenizerFolder() -> URL? {
        let documents = documentsRoot.appendingPathComponent(clipTokenizerName)
        if FileManager.default.fileExists(
            atPath: documents.appendingPathComponent("tokenizer.json").path
        ) {
            return documents
        }
        if let bundled = bundledURL(clipTokenizerName),
           FileManager.default.fileExists(
               atPath: bundled.appendingPathComponent("tokenizer.json").path
           ) {
            return bundled
        }
        return nil
    }

    static func isInstalled(_ kind: VisionModelKind) -> Bool {
        switch kind {
        case .pvtV2: pvtModelURL() != nil
        case .clip: clipModelURL() != nil && clipTokenizerFolder() != nil
        }
    }

    /// Whether the resolved model is the user-imported override (vs. bundled).
    static func isOverridden(_ kind: VisionModelKind) -> Bool {
        let name = kind == .pvtV2 ? pvtBundleName : clipBundleName
        return isAIModelDirectory(documentsRoot.appendingPathComponent(name))
    }

    // MARK: Resolution

    private static func resolve(name: String) -> URL? {
        let override = documentsRoot.appendingPathComponent(name)
        if isAIModelDirectory(override) { return override }
        if let bundled = bundledURL(name), isAIModelDirectory(bundled) { return bundled }
        return nil
    }

    private static func bundledURL(_ name: String) -> URL? {
        Bundle.main.resourceURL?
            .appendingPathComponent(bundleSubdirectory, isDirectory: true)
            .appendingPathComponent(name)
    }

    /// `.aimodel` is a directory bundle — validate it exists and is one.
    private static func isAIModelDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue && url.pathExtension == "aimodel"
    }
}

/// Curated open-vocabulary label set CLIP scores by default. Users can add
/// their own labels in the UI; CLIP needs no retraining to recognize them.
enum CLIPLabelPresets {
    static let everyday: [String] = [
        "a person", "a laptop", "a smartphone", "a coffee mug", "a water bottle",
        "a book", "a pair of headphones", "a backpack", "a chair", "a desk",
        "a houseplant", "a dog", "a cat", "a car", "a bicycle",
        "a television", "a keyboard", "a pen", "a notebook", "a window",
        "food on a plate", "a cup of coffee", "a pair of glasses", "a wristwatch",
        "a remote control", "a wallet", "a set of keys", "a potted plant",
        "a whiteboard", "a guitar", "a camera", "a clock", "a lamp",
        "a sofa", "a bed", "a kitchen", "an office", "the outdoors", "a street"
    ]
}

#if os(iOS) && !targetEnvironment(simulator) && canImport(CoreAI)

import CoreAI
import CoreAIImageSegmenter
import CoreAIShared

// MARK: - Errors

enum VisionClassifierError: Error, LocalizedError {
    case coreAIUnavailable
    case modelNotFound(String)
    case invalidConfiguration(String)
    case missingOutput(String)

    var errorDescription: String? {
        switch self {
        case .coreAIUnavailable:
            "Core AI classification requires a physical iOS device."
        case .modelNotFound(let path):
            "No .aimodel found at \(path). Export it with uv run export.py and import it."
        case .invalidConfiguration(let reason):
            "Invalid model configuration: \(reason)."
        case .missingOutput(let name):
            "Expected model output missing: \(name)."
        }
    }
}

// MARK: - Numerics helpers

private enum Softmax {
    /// Numerically stable softmax over `[Float]`.
    static func apply(_ logits: [Float]) -> [Float] {
        guard let maxValue = logits.max() else { return logits }
        var exps = logits.map { exp($0 - maxValue) }
        let sum = exps.reduce(0, +)
        guard sum > 0 else { return logits }
        for index in exps.indices { exps[index] /= sum }
        return exps
    }
}

// MARK: - PVT v2 ImageNet classifier

/// Core AI-backed supervised classifier for the PVT v2 ImageNet-1k recipe.
struct PVTClassifier {
    private let function: InferenceFunction
    private let descriptor: InferenceFunctionDescriptor
    private let imageInputName: String
    private let logitsOutputName: String
    private let inputHeight: Int
    private let inputWidth: Int

    /// ImageNet normalization (timm default for PVT v2).
    private static let mean: (CGFloat, CGFloat, CGFloat) = (0.485, 0.456, 0.406)
    private static let std: (CGFloat, CGFloat, CGFloat) = (0.229, 0.224, 0.225)

    init(resourcesAt path: String) async throws {
        let modelURL = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: modelURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue, modelURL.pathExtension == "aimodel"
        else {
            throw VisionClassifierError.modelNotFound(modelURL.path)
        }

        let model = try await AIModel(contentsOf: modelURL)
        guard let descriptor = model.functionDescriptor(for: "main") else {
            throw VisionClassifierError.invalidConfiguration("missing 'main' function")
        }
        guard let imageInputName = Self.findImageInput(in: descriptor.inputNames) else {
            throw VisionClassifierError.invalidConfiguration(
                "no image input among \(descriptor.inputNames)"
            )
        }
        guard let logitsOutputName = Self.findLogitsOutput(in: descriptor.outputNames) else {
            throw VisionClassifierError.invalidConfiguration(
                "no logits output among \(descriptor.outputNames)"
            )
        }
        guard case .ndArray(let imageDescriptor) = descriptor.inputDescriptor(of: imageInputName),
              imageDescriptor.shape.count == 4
        else {
            throw VisionClassifierError.invalidConfiguration("image input is not a 4-D tensor")
        }
        guard let fn = try model.loadFunction(named: "main") else {
            throw VisionClassifierError.invalidConfiguration("could not load 'main' function")
        }

        self.function = fn
        self.descriptor = descriptor
        self.imageInputName = imageInputName
        self.logitsOutputName = logitsOutputName
        self.inputHeight = imageDescriptor.shape[2]
        self.inputWidth = imageDescriptor.shape[3]
    }

    func warmup() async throws {
        guard case .ndArray(let imageDescriptor) = descriptor.inputDescriptor(of: imageInputName) else {
            return
        }
        let imageArray = NDArray(descriptor: imageDescriptor)
        _ = try await function.run(inputs: [imageInputName: imageArray])
    }

    func classify(image: CGImage, topK: Int = 5) async throws -> [VisionClassification] {
        guard case .ndArray(let imageDescriptor) = descriptor.inputDescriptor(of: imageInputName) else {
            throw VisionClassifierError.invalidConfiguration("missing image descriptor")
        }

        let pixels = try ImagePreprocessor(
            targetSize: CGSize(width: inputWidth, height: inputHeight),
            mean: Self.mean,
            std: Self.std,
            rescaleFactor: 1.0
        ).preprocessCHW(cgImage: image)

        var imageArray = NDArray(descriptor: imageDescriptor)
        if imageDescriptor.scalarType == .float16 {
            fillNDArray(&imageArray, as: Float16.self, with: pixels.map(Float16.init))
        } else {
            fillNDArray(&imageArray, as: Float.self, with: pixels)
        }

        var outputs = try await function.run(inputs: [imageInputName: imageArray])
        guard let logitsArray = outputs.remove(logitsOutputName)?.ndArray else {
            throw VisionClassifierError.missingOutput(logitsOutputName)
        }

        let logits = flattenAsFloat(logitsArray)
        let probabilities = Softmax.apply(logits)
        return Self.topK(probabilities, k: topK, labels: ImageNetLabels.all)
    }

    private static func topK(
        _ probabilities: [Float], k: Int, labels: [String]
    ) -> [VisionClassification] {
        probabilities.enumerated()
            .sorted { $0.element > $1.element }
            .prefix(k)
            .map { index, value in
                VisionClassification(
                    label: index < labels.count ? labels[index] : "class \(index)",
                    confidence: value,
                    index: index
                )
            }
    }

    private static func findImageInput(in names: [String]) -> String? {
        if names.count == 1 { return names.first }
        return names.first {
            let lower = $0.lowercased()
            return lower == "x" || lower.contains("pixel") || lower.contains("image")
        }
    }

    private static func findLogitsOutput(in names: [String]) -> String? {
        if names.count == 1 { return names.first }
        return names.first {
            let lower = $0.lowercased()
            return lower.contains("logit") || lower.contains("label") || lower.contains("class")
        }
    }
}

// MARK: - CLIP zero-shot classifier

/// Core AI-backed zero-shot classifier for the CLIP recipe. Scores a frame
/// against arbitrary natural-language labels. Works with both the static export
/// (fixed text batch) and the dynamic export (variable batch) by reading the
/// `input_ids` descriptor and scoring labels in batches that match.
struct CLIPZeroShotClassifier {
    private let function: InferenceFunction
    private let descriptor: InferenceFunctionDescriptor
    private let tokenizer: CLIPTokenizer

    private let pixelInputName: String
    private let idsInputName: String
    private let maskInputName: String
    private let logitsOutputName: String

    private let imageHeight: Int
    private let imageWidth: Int
    private let sequenceLength: Int
    private let textBatch: Int

    /// CLIP normalization (clip-vit-base-patch32, 224x224).
    private static let mean: (CGFloat, CGFloat, CGFloat) = (0.48145466, 0.4578275, 0.40821073)
    private static let std: (CGFloat, CGFloat, CGFloat) = (0.26862954, 0.26130258, 0.27577711)

    init(modelPath: String, tokenizerFolder: URL) async throws {
        let modelURL = URL(fileURLWithPath: NSString(string: modelPath).expandingTildeInPath)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: modelURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue, modelURL.pathExtension == "aimodel"
        else {
            throw VisionClassifierError.modelNotFound(modelURL.path)
        }

        self.tokenizer = try CLIPTokenizer(folder: tokenizerFolder)

        let model = try await AIModel(contentsOf: modelURL)
        guard let descriptor = model.functionDescriptor(for: "main") else {
            throw VisionClassifierError.invalidConfiguration("missing 'main' function")
        }

        guard let pixelInputName = descriptor.inputNames.first(where: {
            $0.lowercased().contains("pixel") || $0.lowercased().contains("image")
        }) else {
            throw VisionClassifierError.invalidConfiguration("no pixel_values input")
        }
        guard let idsInputName = descriptor.inputNames.first(where: {
            $0.lowercased().contains("input_ids") || $0.lowercased().contains("ids")
        }) else {
            throw VisionClassifierError.invalidConfiguration("no input_ids input")
        }
        guard let maskInputName = descriptor.inputNames.first(where: {
            $0.lowercased().contains("mask")
        }) else {
            throw VisionClassifierError.invalidConfiguration("no attention_mask input")
        }
        guard let logitsOutputName = descriptor.outputNames.first(where: {
            $0.lowercased().contains("logits_per_image")
        }) ?? descriptor.outputNames.first(where: { $0.lowercased().contains("logit") }) else {
            throw VisionClassifierError.invalidConfiguration("no logits_per_image output")
        }

        guard case .ndArray(let pixelDescriptor) = descriptor.inputDescriptor(of: pixelInputName),
              pixelDescriptor.shape.count == 4
        else {
            throw VisionClassifierError.invalidConfiguration("pixel input is not a 4-D tensor")
        }
        guard case .ndArray(let idsDescriptor) = descriptor.inputDescriptor(of: idsInputName),
              idsDescriptor.shape.count == 2
        else {
            throw VisionClassifierError.invalidConfiguration("input_ids is not a 2-D tensor")
        }

        guard let fn = try model.loadFunction(named: "main") else {
            throw VisionClassifierError.invalidConfiguration("could not load 'main' function")
        }

        self.function = fn
        self.descriptor = descriptor
        self.pixelInputName = pixelInputName
        self.idsInputName = idsInputName
        self.maskInputName = maskInputName
        self.logitsOutputName = logitsOutputName
        self.imageHeight = pixelDescriptor.shape[2]
        self.imageWidth = pixelDescriptor.shape[3]

        let rawBatch = idsDescriptor.shape[0]
        let rawSeq = idsDescriptor.shape[1]
        self.textBatch = (rawBatch > 0 && rawBatch <= 64) ? rawBatch : 8
        self.sequenceLength = (rawSeq > 0 && rawSeq <= 512) ? rawSeq : 77
    }

    func warmup() async throws {
        _ = try? await classify(image: Self.dummyImage(), labels: ["a photo"], topK: 1)
    }

    /// Score `image` against `labels` (open vocabulary). The raw label is shown;
    /// the prompt template "a photo of {label}" is what CLIP actually encodes.
    func classify(
        image: CGImage,
        labels: [String],
        topK: Int = 5
    ) async throws -> [VisionClassification] {
        let cleanedLabels = labels
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleanedLabels.isEmpty else { return [] }

        guard case .ndArray(let pixelDescriptor) = descriptor.inputDescriptor(of: pixelInputName),
              case .ndArray(let idsDescriptor) = descriptor.inputDescriptor(of: idsInputName),
              case .ndArray(let maskDescriptor) = descriptor.inputDescriptor(of: maskInputName)
        else {
            throw VisionClassifierError.invalidConfiguration("missing input descriptors")
        }

        let pixels = try ImagePreprocessor(
            targetSize: CGSize(width: imageWidth, height: imageHeight),
            mean: Self.mean,
            std: Self.std,
            rescaleFactor: 1.0
        ).preprocessCHW(cgImage: image)

        var pixelArray = NDArray(descriptor: pixelDescriptor)
        if pixelDescriptor.scalarType == .float16 {
            fillNDArray(&pixelArray, as: Float16.self, with: pixels.map(Float16.init))
        } else {
            fillNDArray(&pixelArray, as: Float.self, with: pixels)
        }

        var accumulatedLogits = [Float](repeating: 0, count: cleanedLabels.count)

        for chunkStart in stride(from: 0, to: cleanedLabels.count, by: textBatch) {
            let chunkRange = chunkStart..<min(chunkStart + textBatch, cleanedLabels.count)
            let chunkLabels = Array(cleanedLabels[chunkRange])

            // Tokenize each label prompt, padding the chunk up to `textBatch`.
            var ids = [Int32]()
            var mask = [Int32]()
            ids.reserveCapacity(textBatch * sequenceLength)
            mask.reserveCapacity(textBatch * sequenceLength)

            for row in 0..<textBatch {
                let label = row < chunkLabels.count ? chunkLabels[row] : chunkLabels[0]
                let tokens = tokenizer.encode(promptText(for: label), contextLength: sequenceLength)
                ids.append(contentsOf: tokens)
                mask.append(contentsOf: Self.attentionMask(for: tokens))
            }

            var idsArray = NDArray(descriptor: idsDescriptor)
            fillNDArray(&idsArray, as: Int32.self, with: ids)
            var maskArray = NDArray(descriptor: maskDescriptor)
            fillNDArray(&maskArray, as: Int32.self, with: mask)

            var outputs = try await function.run(inputs: [
                pixelInputName: pixelArray,
                idsInputName: idsArray,
                maskInputName: maskArray,
            ])
            guard let logitsArray = outputs.remove(logitsOutputName)?.ndArray else {
                throw VisionClassifierError.missingOutput(logitsOutputName)
            }

            // logits_per_image is [imageBatch=1, textBatch]; take the valid prefix.
            let logits = flattenAsFloat(logitsArray)
            for (offset, labelIndex) in chunkRange.enumerated() where offset < logits.count {
                accumulatedLogits[labelIndex] = logits[offset]
            }
        }

        let probabilities = Softmax.apply(accumulatedLogits)
        return probabilities.enumerated()
            .sorted { $0.element > $1.element }
            .prefix(topK)
            .map { index, value in
                VisionClassification(
                    label: Self.displayLabel(cleanedLabels[index]),
                    confidence: value,
                    index: index
                )
            }
    }

    private func promptText(for label: String) -> String {
        let lowered = label.lowercased()
        if lowered.hasPrefix("a ") || lowered.hasPrefix("an ") || lowered.hasPrefix("the ") {
            return "a photo of \(label)."
        }
        return "a photo of a \(label)."
    }

    /// Mask is 1 up to and including the first end-of-text token, 0 afterwards.
    private static func attentionMask(for tokens: [Int32]) -> [Int32] {
        var mask = [Int32](repeating: 0, count: tokens.count)
        for (index, token) in tokens.enumerated() {
            mask[index] = 1
            if index > 0, token == CLIPTokenizer.eotTokenId { break }
        }
        return mask
    }

    private static func displayLabel(_ raw: String) -> String {
        var label = raw
        for prefix in ["a photo of ", "an ", "a ", "the "] where label.lowercased().hasPrefix(prefix) {
            label = String(label.dropFirst(prefix.count))
            break
        }
        return label
    }

    private static func dummyImage() -> CGImage {
        let context = CGContext(
            data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        return context!.makeImage()!
    }
}

#endif
