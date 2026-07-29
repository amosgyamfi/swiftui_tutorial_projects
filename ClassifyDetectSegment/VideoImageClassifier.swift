//
//  VideoImageClassifier.swift
//  SwiftUIFor27
//
//  ImagePredict — a Core AI-powered vision studio.
//
//  Launches straight into a full-screen camera feed with a Liquid Glass
//  toolbar and tab bar floating on top. From a single live frame it can:
//
//   * Classify   — live image classification with a user-chosen Core AI model
//                  (PVT v2 ImageNet-1k, or CLIP open-vocabulary zero-shot).
//   * Detect     — object detection + prediction (RF-DETR via Core AI).
//   * Segment    — instance & semantic segmentation by text prompt (SAM 3).
//   * Ask        — natural-language Q&A about the scene via Apple Intelligence
//                  (Foundation Models), with text or voice input (SpeechAnalyzer
//                  + SpeechTranscriber).
//
//  The detection and segmentation engines, the model downloader, and the
//  dictation controller are shared with RealtimeObjectDetection.
//

import SwiftUI

#if os(iOS) && !targetEnvironment(simulator)
@preconcurrency import AVFoundation
import CoreAIImageSegmenter
import CoreAIObjectDetector
import CoreImage
import FoundationModels
import Observation
import UIKit
import UniformTypeIdentifiers

struct VideoImageClassifier: View {
    @State private var store = ImagePredictStore()
    @State private var dictation = DictationController()
    @FocusState private var promptFocused: Bool
    @FocusState private var labelFieldFocused: Bool
    @FocusState private var segmentFocused: Bool

    var body: some View {
        ZStack {
            IPCameraPreview(session: store.captureSession)
                .ignoresSafeArea()
                .overlay(.black.opacity(store.cameraOverlayOpacity))

            IPDetectionOverlay(detections: store.detections, imageSize: store.framePixelSize)
                .ignoresSafeArea()
                .opacity(store.selectedTab == .detect ? 1 : 0)

            IPSegmentationOverlay(segments: store.segments, imageSize: store.framePixelSize)
                .ignoresSafeArea()

            if store.selectedTab == .classify {
                ClassificationScrim()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            dismissTapLayer

            overlayChrome
        }
        .preferredColorScheme(.dark)
        .task { await store.start() }
        .onDisappear { store.stop() }
        .fileImporter(
            isPresented: $store.isImportingModel,
            allowedContentTypes: [.folder, .directory, .item],
            allowsMultipleSelection: false
        ) { result in
            store.handleImport(result)
        }
    }

    // MARK: - Dismiss layer

    private var dismissTapLayer: some View {
        Color.clear
            .contentShape(.rect)
            .ignoresSafeArea()
            .allowsHitTesting(needsDismissLayer)
            .onTapGesture { dismissTransientUI(clearSegments: true) }
    }

    private var needsDismissLayer: Bool {
        promptFocused || labelFieldFocused || segmentFocused
            || store.selectedTab == .models || !store.segments.isEmpty
    }

    private func dismissTransientUI(clearSegments: Bool) {
        promptFocused = false
        labelFieldFocused = false
        segmentFocused = false
        dictation.stopIfNeeded()
        withAnimation(.smooth(duration: 0.22)) {
            if store.selectedTab == .models { store.selectedTab = .classify }
            if clearSegments { store.clearSegments() }
        }
    }

    // MARK: - Chrome

    private var overlayChrome: some View {
        VStack(spacing: 12) {
            topToolbar
                .padding(.horizontal, 14)
                .padding(.top, 10)

            Spacer(minLength: 0)

            panel
                .animation(.smooth(duration: 0.25), value: store.selectedTab)

            bottomTabBar
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
        }
    }

    @ViewBuilder
    private var panel: some View {
        switch store.selectedTab {
        case .classify:
            classifyPanel
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .detect:
            detectStatusStrip
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
        case .segment:
            segmentPanel
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .ask:
            askPanel
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .models:
            modelsPanel
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Top toolbar

    private var topToolbar: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 10) {
                if store.selectedTab == .classify {
                    Menu {
                        ForEach(VisionModelKind.allCases) { kind in
                            Button {
                                Task { await store.selectModel(kind) }
                            } label: {
                                if store.selectedModel == kind {
                                    Label(kind.displayName, systemImage: "checkmark")
                                } else {
                                    Label(kind.displayName, systemImage: kind.symbolName)
                                }
                            }
                        }
                    } label: {
                        Label(store.selectedModel.displayName, systemImage: store.selectedModel.symbolName)
                            .labelStyle(.titleAndIcon)
                            .lineLimit(1)
                    }
                    .buttonStyle(.glass)
                }

                Spacer(minLength: 8)

                Button {
                    withAnimation(.smooth) { store.isLiveEnabled.toggle() }
                } label: {
                    Image(systemName: store.isLiveEnabled ? "pause.fill" : "play.fill")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)

                Button {
                    withAnimation(.smooth) { store.selectedTab = .models }
                } label: {
                    Image(systemName: VisionModelCatalog.isInstalled(store.selectedModel)
                          ? "checkmark.seal.fill" : "arrow.down.circle.fill")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
            }
        }
    }

    // MARK: - Classify panel

    private var classifyPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: store.selectedModel.symbolName)
                    .symbolEffect(.variableColor.iterative, isActive: store.isLiveEnabled && store.isClassifying)
                Text(store.selectedModel.displayName)
                    .font(.headline)
                Spacer(minLength: 0)
                Text(store.classifyStatus)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if VisionModelCatalog.isInstalled(store.selectedModel) {
                if store.topClassifications.isEmpty {
                    Label("Point the camera at something to classify.", systemImage: "viewfinder")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(store.topClassifications.enumerated()), id: \.element.id) { rank, prediction in
                        PredictionRow(prediction: prediction, isTop: rank == 0)
                    }
                }

                if store.selectedModel.isZeroShot {
                    Divider().overlay(.secondary.opacity(0.45))
                    clipLabelEditor
                }
            } else {
                missingModelCallout
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.white)
        .glassEffect(.regular.tint(.black.opacity(0.22)), in: .rect(cornerRadius: 28))
        .padding(.horizontal, 14)
    }

    private var clipLabelEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CLIP labels")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                TextField("Add a label, e.g. \"a red mug\"", text: $store.newLabel)
                    .textFieldStyle(.plain)
                    .focused($labelFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { store.commitNewLabel() }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))

                Button {
                    store.commitNewLabel()
                    labelFieldFocused = false
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .disabled(store.newLabel.trimmingCharacters(in: .whitespaces).isEmpty)

                Button { store.resetLabels() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.clipLabels, id: \.self) { label in
                        HStack(spacing: 5) {
                            Text(label).font(.caption)
                            Button { store.removeLabel(label) } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .glassEffect(.regular, in: .capsule)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Detect panel

    private var detectStatusStrip: some View {
        HStack(spacing: 10) {
            Image(systemName: store.detections.isEmpty ? "viewfinder" : "scope")
                .symbolEffect(.variableColor.iterative, isActive: store.isLiveEnabled && !store.detections.isEmpty)
            Text(store.detectStatus)
                .lineLimit(1)
                .font(.callout.weight(.medium))
            Spacer(minLength: 0)
            Text("\(store.detections.count)")
                .font(.headline.monospacedDigit())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .foregroundStyle(.white)
        .glassEffect(.regular.tint(.black.opacity(0.22)), in: .rect(cornerRadius: 22))
        .padding(.horizontal, 14)
    }

    // MARK: - Segment panel

    private var segmentPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TextField("Segment a person, cup, dog…", text: $store.segmentPrompt, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($segmentFocused)
                    .lineLimit(1...3)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .glassEffect(.regular, in: .rect(cornerRadius: 18))

                Button {
                    segmentFocused = false
                    Task { await store.segmentCurrentFrame() }
                } label: {
                    Image(systemName: store.isSegmenting ? "ellipsis" : "lasso.badge.sparkles")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .disabled(store.segmentPrompt.trimmingCharacters(in: .whitespaces).isEmpty || store.isSegmenting)
            }

            if store.segmentationDownloader.busy {
                ProgressView(value: store.segmentationDownloader.fraction)
            }

            HStack(spacing: 8) {
                Image(systemName: store.segments.isEmpty ? "square.dashed" : "square.stack.3d.up.fill")
                Text(store.segmentStatus)
                    .lineLimit(2)
                Spacer(minLength: 0)
                if !store.segments.isEmpty {
                    Button {
                        withAnimation(.smooth(duration: 0.22)) { store.clearSegments() }
                    } label: {
                        Image(systemName: "xmark.circle.fill").frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                Text("\(store.segments.count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .foregroundStyle(.white)
        .glassEffect(.regular.tint(.black.opacity(0.22)), in: .rect(cornerRadius: 28))
        .padding(.horizontal, 14)
    }

    // MARK: - Ask panel

    private var askPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let answer = store.answer, !answer.isEmpty {
                ScrollView {
                    Text(answer)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 180)
            }

            HStack(spacing: 10) {
                TextField("Ask about the scene", text: $store.prompt, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($promptFocused)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .glassEffect(.regular, in: .rect(cornerRadius: 18))

                Button {
                    dictation.toggle(currentText: store.prompt) { store.prompt = $0 }
                } label: {
                    Group {
                        if dictation.isPreparing {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: dictation.isListening ? "waveform" : "mic.fill")
                                .symbolEffect(.variableColor.iterative, isActive: dictation.isListening)
                        }
                    }
                    .frame(width: 22, height: 22)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .tint(dictation.isListening ? .red : nil)

                Button {
                    dictation.stopIfNeeded()
                    promptFocused = false
                    Task { await store.askAboutScene() }
                } label: {
                    Image(systemName: store.isAnswering ? "ellipsis" : "arrow.up")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .disabled(store.prompt.trimmingCharacters(in: .whitespaces).isEmpty || store.isAnswering)
            }

            Text(store.sceneSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(14)
        .foregroundStyle(.white)
        .glassEffect(.regular.tint(.black.opacity(0.22)), in: .rect(cornerRadius: 28))
        .padding(.horizontal, 14)
    }

    // MARK: - Models panel

    private var modelsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vision models")
                .font(.headline)

            ForEach(VisionModelKind.allCases) { kind in
                Button {
                    Task { await store.selectModel(kind) }
                    withAnimation(.smooth(duration: 0.22)) { store.selectedTab = .classify }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: store.selectedModel == kind ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(store.selectedModel == kind ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kind.displayName).font(.callout.weight(.semibold))
                            Text(kind.tagline)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        if VisionModelCatalog.isInstalled(kind) {
                            Image(systemName: "checkmark.icloud.fill").foregroundStyle(.green)
                        } else {
                            Image(systemName: "exclamationmark.icloud").foregroundStyle(.orange)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }

            Divider().overlay(.secondary.opacity(0.45))

            Text(store.modelsHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    store.beginImport(target: .visionModel)
                } label: {
                    Label("Replace \(store.selectedModel.shortName) .aimodel", systemImage: "square.and.arrow.down")
                        .font(.callout.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.glassProminent)

                if store.selectedModel.isZeroShot {
                    Button {
                        store.beginImport(target: .clipTokenizer)
                    } label: {
                        Label("Tokenizer", systemImage: "textformat")
                            .font(.callout.weight(.semibold))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 6)
                    }
                    .buttonStyle(.glass)
                }
            }
        }
        .padding(16)
        .foregroundStyle(.white)
        .glassEffect(.regular.tint(.black.opacity(0.24)), in: .rect(cornerRadius: 28))
        .padding(.horizontal, 14)
    }

    private var missingModelCallout: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(store.selectedModel.displayName) failed to load", systemImage: "exclamationmark.icloud")
                .font(.callout.weight(.semibold))
            Text("The bundled model is missing. Re-run the export and import the .aimodel from the Models tab.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                withAnimation(.smooth) { store.selectedTab = .models }
            } label: {
                Label("Open Models", systemImage: "square.stack.3d.up.fill")
            }
            .buttonStyle(.glassProminent)
            .controlSize(.small)
        }
    }

    // MARK: - Tab bar

    private var bottomTabBar: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                ForEach(ImagePredictTab.allCases) { tab in
                    if store.selectedTab == tab {
                        tabButton(tab).buttonStyle(.glassProminent)
                    } else {
                        tabButton(tab).buttonStyle(.glass)
                    }
                }
            }
        }
    }

    private func tabButton(_ tab: ImagePredictTab) -> some View {
        Button {
            dismissTransientUI(clearSegments: false)
            withAnimation(.smooth) { store.selectedTab = tab }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.symbolName)
                    .font(.body.weight(.semibold))
                Text(tab.title)
                    .font(.caption2.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
        }
    }
}

// MARK: - Store

@MainActor
@Observable
final class ImagePredictStore {
    let captureSession = AVCaptureSession()
    let segmentationDownloader = ModelDownloader()

    var selectedTab: ImagePredictTab = .classify
    var selectedModel: VisionModelKind = .pvtV2

    var topClassifications: [VisionClassification] = []
    var detections: [CameraDetection] = []
    var segments: [CameraSegment] = []
    var framePixelSize: CGSize = .zero

    var isLiveEnabled = true
    var isClassifying = false
    var isDetecting = false
    var isSegmenting = false
    var isAnswering = false
    var isLoadingModel = false

    var classifyStatus = "Preparing…"
    var detectStatus = "Starting camera…"
    var segmentStatus = "Download SAM 3 to segment by text prompt."

    // CLIP labels
    var clipLabels: [String] = CLIPLabelPresets.everyday
    var newLabel = ""

    // Ask
    var prompt = ""
    var answer: String?

    // Segment
    var segmentPrompt = "person"

    // Import
    var isImportingModel = false
    private var importTarget: ImportTarget = .visionModel

    enum ImportTarget { case visionModel, clipTokenizer }

    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoQueue = DispatchQueue(label: "ImagePredict.camera")
    private let frameDelegate = IPFrameDelegate()
    private let ciContext = CIContext()

    private var pvtClassifier: PVTClassifier?
    private var clipClassifier: CLIPZeroShotClassifier?
    private var detector: ObjectDetector?
    private var loadedDetectorID: String?
    private var segmenter: ImageSegmenter?
    private var languageSession: LanguageModelSession?

    private var latestFrame: CGImage?
    private var lastInferenceDate = Date.distantPast
    private var isProcessingFrame = false
    private var didConfigureSession = false

    private let detectorModel = RFDETRModelCatalog.nano

    var cameraOverlayOpacity: Double {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: 0
        default: 0.55
        }
    }

    var modelsHint: String {
        switch selectedModel {
        case .pvtV2:
            "PVT v2 ships built in and classifies into 1000 ImageNet categories. Importing a freshly exported .aimodel overrides the bundled copy."
        case .clip:
            "CLIP ships built in for open-vocabulary zero-shot. Import a custom clip .aimodel (and tokenizer) to override the bundled copy."
        }
    }

    var sceneSummary: String {
        var parts: [String] = []
        if !topClassifications.isEmpty {
            let top = topClassifications.prefix(3)
                .map { "\($0.label) \(Int($0.confidence * 100))%" }
                .joined(separator: ", ")
            parts.append("Classifier: \(top)")
        }
        if !detections.isEmpty {
            parts.append("Detected: \(detectionGrouping)")
        }
        if !segments.isEmpty {
            parts.append("Segments: \(segments.count)")
        }
        return parts.isEmpty ? "Aim the camera, then ask anything about what it sees." : parts.joined(separator: " · ")
    }

    private var detectionGrouping: String {
        let grouped = Dictionary(grouping: detections, by: \.label)
        let counts: [(label: String, count: Int)] = grouped.map { (label: $0.key, count: $0.value.count) }
        let sorted = counts.sorted { lhs, rhs in
            lhs.count == rhs.count ? lhs.label < rhs.label : lhs.count > rhs.count
        }
        return sorted
            .prefix(6)
            .map { "\($0.count) \($0.label)" }
            .joined(separator: ", ")
    }

    // MARK: Lifecycle

    func start() async {
        frameDelegate.store = self
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSessionIfNeeded()
            startSession()
        case .notDetermined:
            if await AVCaptureDevice.requestAccess(for: .video) {
                configureSessionIfNeeded()
                startSession()
            } else {
                classifyStatus = "Camera permission denied."
            }
        case .denied, .restricted:
            classifyStatus = "Camera permission denied."
        @unknown default:
            classifyStatus = "Camera permission unavailable."
        }
        refreshModelStatus()
    }

    func stop() {
        captureSession.stopRunning()
    }

    func selectModel(_ kind: VisionModelKind) async {
        guard selectedModel != kind else { return }
        selectedModel = kind
        topClassifications = []
        refreshModelStatus()
    }

    private func refreshModelStatus() {
        if VisionModelCatalog.isInstalled(selectedModel) {
            classifyStatus = "\(selectedModel.displayName) ready."
        } else {
            classifyStatus = "\(selectedModel.displayName) not installed."
        }
    }

    // MARK: CLIP label management

    func commitNewLabel() {
        let trimmed = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !clipLabels.contains(trimmed) else { newLabel = ""; return }
        clipLabels.append(trimmed)
        newLabel = ""
    }

    func removeLabel(_ label: String) {
        clipLabels.removeAll { $0 == label }
    }

    func resetLabels() {
        clipLabels = CLIPLabelPresets.everyday
    }

    // MARK: Frame pipeline

    func receive(frame cgImage: CGImage) {
        latestFrame = cgImage
        framePixelSize = CGSize(width: cgImage.width, height: cgImage.height)

        guard isLiveEnabled else { return }
        guard selectedTab == .classify || selectedTab == .detect else { return }
        guard !isProcessingFrame else { return }

        let interval: TimeInterval = selectedTab == .detect
            ? detectorModel.minimumFrameInterval
            : (selectedModel.isZeroShot ? 0.9 : 0.35)
        guard Date().timeIntervalSince(lastInferenceDate) > interval else { return }

        isProcessingFrame = true
        lastInferenceDate = Date()

        Task {
            defer { isProcessingFrame = false }
            if selectedTab == .detect {
                await runDetection(on: cgImage)
            } else {
                await runClassification(on: cgImage)
            }
        }
    }

    // MARK: Classification

    private func runClassification(on image: CGImage) async {
        guard VisionModelCatalog.isInstalled(selectedModel) else {
            classifyStatus = "\(selectedModel.displayName) not installed."
            return
        }
        isClassifying = true
        defer { isClassifying = false }

        let clock = ContinuousClock()
        let start = clock.now
        do {
            switch selectedModel {
            case .pvtV2:
                let classifier = try await preparedPVT()
                topClassifications = try await classifier.classify(image: image, topK: 5)
            case .clip:
                let classifier = try await preparedCLIP()
                topClassifications = try await classifier.classify(
                    image: image, labels: clipLabels, topK: 5
                )
            }
            let elapsed = clock.now - start
            classifyStatus = "\(selectedModel.shortName) · \(elapsed.imagePredictMilliseconds)"
        } catch {
            classifyStatus = error.localizedDescription
        }
    }

    private func preparedPVT() async throws -> PVTClassifier {
        if let pvtClassifier { return pvtClassifier }
        guard let url = VisionModelCatalog.pvtModelURL() else {
            throw VisionClassifierError.modelNotFound("PVT v2 (bundled)")
        }
        isLoadingModel = true
        defer { isLoadingModel = false }
        let classifier = try await PVTClassifier(resourcesAt: url.path)
        try? await classifier.warmup()
        pvtClassifier = classifier
        return classifier
    }

    private func preparedCLIP() async throws -> CLIPZeroShotClassifier {
        if let clipClassifier { return clipClassifier }
        guard let modelURL = VisionModelCatalog.clipModelURL(),
              let tokenizerFolder = VisionModelCatalog.clipTokenizerFolder() else {
            throw VisionClassifierError.modelNotFound("CLIP (bundled)")
        }
        isLoadingModel = true
        defer { isLoadingModel = false }
        let classifier = try await CLIPZeroShotClassifier(
            modelPath: modelURL.path,
            tokenizerFolder: tokenizerFolder
        )
        clipClassifier = classifier
        return classifier
    }

    // MARK: Detection

    private func runDetection(on image: CGImage) async {
        guard RFDETRModelCatalog.isInstalled(detectorModel) else {
            await downloadDetectorIfNeeded()
            return
        }
        isDetecting = true
        defer { isDetecting = false }
        do {
            let detector = try await preparedDetector()
            let clock = ContinuousClock()
            let start = clock.now
            let params = DetectionParameters(
                threshold: 0.5,
                maxDetections: 20,
                scoreTransform: .sigmoid,
                normalizationMeans: (0, 0, 0),
                normalizationStds: (1, 1, 1)
            )
            let raw = try await detector.detect(image: image, parameters: params)
            detections = raw.map(CameraDetection.init)
            let elapsed = clock.now - start
            detectStatus = detections.isEmpty
                ? "RF-DETR · scanning"
                : "RF-DETR · \(elapsed.imagePredictMilliseconds)"
        } catch {
            detectStatus = error.localizedDescription
        }
    }

    private func preparedDetector() async throws -> ObjectDetector {
        if let detector, loadedDetectorID == detectorModel.id { return detector }
        isLoadingModel = true
        defer { isLoadingModel = false }
        let detector = try await ObjectDetector(
            resourcesAt: RFDETRModelCatalog.bundleURL(for: detectorModel).path
        )
        try? await detector.warmup()
        self.detector = detector
        loadedDetectorID = detectorModel.id
        return detector
    }

    private func downloadDetectorIfNeeded() async {
        guard !segmentationDownloader.busy else { return }
        detectStatus = "Downloading \(detectorModel.displayName)…"
        await segmentationDownloader.fetch(
            repo: RFDETRModelCatalog.repo,
            items: [ModelDownloader.Item(
                remote: detectorModel.remotePath, local: detectorModel.bundleName
            )],
            into: RFDETRModelCatalog.modelsDirectory
        )
        detectStatus = RFDETRModelCatalog.isInstalled(detectorModel)
            ? "\(detectorModel.displayName) ready."
            : "Download failed."
    }

    // MARK: Segmentation

    func segmentCurrentFrame() async {
        let trimmed = segmentPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let latestFrame else { segmentStatus = "Waiting for a camera frame."; return }

        if !SAM3ModelCatalog.isInstalled {
            await downloadSAM3()
        }
        guard SAM3ModelCatalog.isInstalled else { return }

        isSegmenting = true
        segmentStatus = "Segmenting \"\(trimmed)\"…"
        defer { isSegmenting = false }
        do {
            let segmenter = try await preparedSegmenter()
            let response = try await segmenter.segment(
                image: latestFrame,
                prompt: trimmed,
                parameters: SegmentationParameters(maskThreshold: 0.5, maxSegments: 5)
            )
            segments = response.segments.enumerated().compactMap { index, segment in
                CameraSegment(segment, prompt: trimmed, index: index)
            }
            segmentStatus = segments.isEmpty
                ? "No \(trimmed) found."
                : "SAM 3 found \(segments.count) \(trimmed) instance\(segments.count == 1 ? "" : "s")."
        } catch {
            segmentStatus = error.localizedDescription
        }
    }

    private func preparedSegmenter() async throws -> ImageSegmenter {
        if let segmenter { return segmenter }
        let segmenter = try await ImageSegmenter(resourcesAt: SAM3ModelCatalog.bundleURL.path)
        try? await segmenter.warmup()
        self.segmenter = segmenter
        return segmenter
    }

    private func downloadSAM3() async {
        segmentStatus = "Downloading SAM 3…"
        await segmentationDownloader.fetchBundleRoot(
            repo: SAM3ModelCatalog.repo,
            local: SAM3ModelCatalog.bundleName,
            including: SAM3ModelCatalog.includedPaths,
            into: SAM3ModelCatalog.modelsDirectory
        )
        if SAM3ModelCatalog.isInstalled {
            segmenter = nil
            segmentStatus = "SAM 3 ready. Enter a text prompt."
        }
    }

    func clearSegments() {
        guard !segments.isEmpty else { return }
        segments = []
        segmentStatus = SAM3ModelCatalog.isInstalled
            ? "SAM 3 ready. Enter a text prompt."
            : "Download SAM 3 to segment by text prompt."
    }

    // MARK: Ask (Foundation Models)

    func askAboutScene() async {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        prompt = ""
        answer = ""
        isAnswering = true
        defer { isAnswering = false }
        do {
            let session = try preparedLanguageSession()
            let context = """
            On-device vision context for the current camera frame:
            \(sceneSummary)

            Classifier model: \(selectedModel.displayName).
            User question: \(trimmed)
            """
            let stream = session.streamResponse(
                to: context,
                options: GenerationOptions(maximumResponseTokens: 500)
            )
            for try await snapshot in stream {
                answer = snapshot.content
            }
        } catch {
            answer = error.localizedDescription
        }
    }

    private func preparedLanguageSession() throws -> LanguageModelSession {
        if let languageSession { return languageSession }
        switch SystemLanguageModel.default.availability {
        case .available:
            let session = LanguageModelSession(
                model: .default,
                instructions: "You help a user understand what an on-device camera sees. You receive classification, detection, and segmentation results. Be concise and practical, and note uncertainty when confidence is low."
            )
            languageSession = session
            return session
        case .unavailable(let reason):
            throw NSError(domain: "ImagePredict", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Apple Intelligence is unavailable (\(String(describing: reason)))."
            ])
        }
    }

    // MARK: Import

    func beginImport(target: ImportTarget) {
        importTarget = target
        isImportingModel = true
    }

    func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let source = urls.first else { return }
        let fileManager = FileManager.default
        let destination: URL
        switch importTarget {
        case .visionModel:
            destination = VisionModelCatalog.documentsRoot.appendingPathComponent(
                selectedModel == .pvtV2
                    ? VisionModelCatalog.pvtBundleName
                    : VisionModelCatalog.clipBundleName
            )
        case .clipTokenizer:
            destination = VisionModelCatalog.documentsRoot.appendingPathComponent(
                VisionModelCatalog.clipTokenizerName
            )
        }

        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        do {
            try fileManager.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: source, to: destination)
            pvtClassifier = nil
            clipClassifier = nil
            refreshModelStatus()
        } catch {
            classifyStatus = "Import failed: \(error.localizedDescription)"
        }
    }

    // MARK: Camera plumbing

    private func configureSessionIfNeeded() {
        guard !didConfigureSession else { return }
        didConfigureSession = true

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        defer { captureSession.commitConfiguration() }

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            captureSession.canAddInput(input)
        else {
            detectStatus = "Back camera unavailable."
            return
        }
        captureSession.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        guard captureSession.canAddOutput(videoOutput) else {
            detectStatus = "Camera frames unavailable."
            return
        }
        captureSession.addOutput(videoOutput)
        videoOutput.setSampleBufferDelegate(frameDelegate, queue: videoQueue)

        if let connection = videoOutput.connection(with: .video),
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
    }

    private func startSession() {
        guard !captureSession.isRunning else { return }
        let session = captureSession
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    fileprivate func makeImage(from sampleBuffer: CMSampleBuffer) -> CGImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }
}

// MARK: - Camera frame delegate / preview

private final class IPFrameDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    weak var store: ImagePredictStore?

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let store, let image = store.makeImage(from: sampleBuffer) else { return }
        Task { @MainActor in store.receive(frame: image) }
    }
}

private struct IPCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> IPPreviewView {
        let view = IPPreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: IPPreviewView, context: Context) {
        if let connection = uiView.previewLayer.connection,
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
    }
}

private final class IPPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

// MARK: - Detection & segmentation overlays

private struct IPDetectionOverlay: View {
    let detections: [CameraDetection]
    let imageSize: CGSize

    var body: some View {
        GeometryReader { proxy in
            ForEach(detections) { detection in
                let rect = detection.displayRect(in: proxy.size, imageSize: imageSize)
                IPDetectionBox(detection: detection)
                    .frame(width: max(rect.width, 1), height: max(rect.height, 1))
                    .position(x: rect.midX, y: rect.midY)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct IPDetectionBox: View {
    let detection: CameraDetection

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .stroke(detection.color, lineWidth: 3)
                .shadow(color: .black.opacity(0.45), radius: 6)

            Text("\(detection.label) \(Int(detection.confidence * 100))%")
                .font(.caption2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(detection.color, in: .rect(cornerRadius: 7))
                .offset(x: 0, y: -28)
        }
    }
}

private struct IPSegmentationOverlay: View {
    let segments: [CameraSegment]
    let imageSize: CGSize

    var body: some View {
        GeometryReader { proxy in
            ForEach(segments) { segment in
                if imageSize.width > 0, imageSize.height > 0 {
                    let scale = max(proxy.size.width / imageSize.width, proxy.size.height / imageSize.height)
                    let scaledImageSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
                    Image(decorative: segment.maskImage, scale: 1, orientation: .up)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: scaledImageSize.width, height: scaledImageSize.height)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                        .allowsHitTesting(false)

                    let rect = segment.displayRect(in: proxy.size, imageSize: imageSize)
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(segment.color, style: StrokeStyle(lineWidth: 2, dash: [8, 5]))
                        .shadow(color: .black.opacity(0.45), radius: 5)
                        .frame(width: max(rect.width, 1), height: max(rect.height, 1))
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)
                }
            }
        }
    }
}

// MARK: - Small subviews

private struct PredictionRow: View {
    let prediction: VisionClassification
    let isTop: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(prediction.label.capitalized)
                    .font(isTop ? Font.title3.weight(.bold) : Font.callout.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(Int(prediction.confidence * 100))%")
                    .font((isTop ? Font.title3 : Font.callout).monospacedDigit().weight(.semibold))
            }
            ProgressView(value: Double(prediction.confidence))
                .tint(isTop ? .green : .white.opacity(0.7))
        }
    }
}

/// Subtle top-and-bottom darkening so glass panels and predictions stay legible.
private struct ClassificationScrim: View {
    var body: some View {
        LinearGradient(
            colors: [.black.opacity(0.35), .clear, .clear, .black.opacity(0.35)],
            startPoint: .top, endPoint: .bottom
        )
    }
}

// MARK: - Tabs

enum ImagePredictTab: String, CaseIterable, Identifiable {
    case classify, detect, segment, ask, models

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classify: "Classify"
        case .detect: "Detect"
        case .segment: "Segment"
        case .ask: "Ask"
        case .models: "Models"
        }
    }

    var symbolName: String {
        switch self {
        case .classify: "wand.and.stars.inverse"
        case .detect: "viewfinder"
        case .segment: "square.stack.3d.up.fill"
        case .ask: "text.bubble.fill"
        case .models: "cpu.fill"
        }
    }
}

// MARK: - Duration formatting

private extension Duration {
    var imagePredictMilliseconds: String {
        let (seconds, attoseconds) = components
        let milliseconds = (Double(seconds) * 1000) + (Double(attoseconds) / 1e15)
        return String(format: "%.0f ms", milliseconds)
    }
}

#else

struct VideoImageClassifier: View {
    var body: some View {
        ContentUnavailableView(
            "ImagePredict",
            systemImage: "camera.viewfinder",
            description: Text("Core AI video classification (PVT v2 / CLIP) requires a physical iOS device.")
        )
    }
}

#endif

#Preview {
    VideoImageClassifier()
}
