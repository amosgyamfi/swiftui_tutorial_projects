//
//  RealtimeObjectDetection.swift
//  SwiftUIFor27
//
//  Created by Amos Gyamfi on 23.6.2026.
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

struct RealtimeObjectDetection: View {
    @State private var store = RealtimeObjectDetectionStore()
    @State private var dictation = DictationController()
    @FocusState private var promptFocused: Bool
    @FocusState private var segmentationPromptFocused: Bool

    var body: some View {
        ZStack {
            CameraPreview(session: store.captureSession)
                .ignoresSafeArea()
                .overlay(.black.opacity(store.cameraOverlayOpacity))

            DetectionOverlay(
                detections: store.detections,
                imageSize: store.framePixelSize
            )
            .ignoresSafeArea()

            SegmentationOverlay(
                segments: store.segments,
                imageSize: store.framePixelSize
            )
            .ignoresSafeArea()

            dismissTapLayer

            overlayChrome
        }
        .task { await store.start() }
        .onDisappear { store.stop() }
    }

    private var dismissTapLayer: some View {
        Color.clear
            .contentShape(.rect)
            .ignoresSafeArea()
            .allowsHitTesting(needsDismissTapLayer)
            .onTapGesture {
                dismissTransientUI(clearSegments: true)
            }
    }

    private var needsDismissTapLayer: Bool {
        promptFocused || segmentationPromptFocused || store.selectedTab == .models || !store.segments.isEmpty
    }

    private func dismissTransientUI(clearSegments: Bool) {
        promptFocused = false
        segmentationPromptFocused = false
        dictation.stopIfNeeded()

        withAnimation(.smooth(duration: 0.22)) {
            if store.selectedTab == .models {
                store.selectedTab = .detect
            }
            if clearSegments {
                store.clearSegments()
            }
        }
    }

    private var overlayChrome: some View {
        VStack(spacing: 12) {
            topToolbar
                .padding(.horizontal, 14)
                .padding(.top, 10)

            Spacer(minLength: 0)

            if store.selectedTab == .ask {
                questionPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if store.selectedTab == .segment {
                segmentPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if store.selectedTab == .models {
                modelPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                detectionStatusStrip
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            bottomTabBar
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
        }
        .animation(.smooth(duration: 0.25), value: store.selectedTab)
    }

    private var topToolbar: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 10) {
                Menu {
                    ForEach(RFDETRModelCatalog.all) { model in
                        Button {
                            Task { await store.select(model) }
                        } label: {
                            if store.selectedModel == model {
                                Label(model.displayName, systemImage: "checkmark")
                            } else {
                                Text(model.displayName)
                            }
                        }
                    }
                } label: {
                    Label(store.selectedModel.shortName, systemImage: "shippingbox.fill")
                        .labelStyle(.titleAndIcon)
                        .lineLimit(1)
                }
                .buttonStyle(.glass)

                Spacer(minLength: 8)

                if store.isLoadingModel || store.isLoadingSegmenter || store.downloader.busy || store.segmentationDownloader.busy {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 30, height: 30)
                        .glassEffect(.regular, in: .circle)
                }

                Button {
                    withAnimation(.smooth) { store.isDetectionEnabled.toggle() }
                } label: {
                    Image(systemName: store.isDetectionEnabled ? "pause.fill" : "play.fill")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)

                Button {
                    Task { await store.downloadSelectedModelIfNeeded(force: true) }
                } label: {
                    Image(systemName: store.isSelectedModelInstalled ? "checkmark.icloud.fill" : "arrow.down.circle.fill")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .disabled(store.downloader.busy)
            }
        }
    }

    private var detectionStatusStrip: some View {
        HStack(spacing: 10) {
            Image(systemName: store.statusSymbol)
                .symbolEffect(.variableColor.iterative, isActive: store.isDetectionEnabled && !store.detections.isEmpty)
            Text(store.statusLine)
                .lineLimit(1)
                .font(.callout.weight(.medium))
            Spacer(minLength: 0)
            Text("\(store.detections.count)")
                .font(.headline.monospacedDigit())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .foregroundStyle(.white)
        .shadow(radius: 10)
        .glassEffect(.regular.tint(.black.opacity(0.2)), in: .rect(cornerRadius: 22))
        .padding(.horizontal, 14)
    }

    private var questionPanel: some View {
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
                .disabled(store.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isAnswering)
            }

            Text(store.sceneSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(14)
        .glassEffect(.regular.tint(.black.opacity(0.2)), in: .rect(cornerRadius: 28))
        .padding(.horizontal, 14)
    }

    private var modelPanel: some View {
        VStack(spacing: 10) {
            ForEach(RFDETRModelCatalog.all) { model in
                Button {
                    Task { await store.select(model) }
                    withAnimation(.smooth(duration: 0.22)) { store.selectedTab = .detect }
                } label: {
                    HStack(spacing: 12) {
                        if store.selectedModel == model {
                            Image(systemName: "largecircle.fill.circle")
                                .foregroundStyle(.tint)
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.displayName)
                                .font(.callout.weight(.semibold))
                            Text("\(model.inputPixels)x\(model.inputPixels) - \(model.detail)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if RFDETRModelCatalog.isInstalled(model) {
                            Image(systemName: "checkmark.icloud.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }

            if store.downloader.busy {
                ProgressView(value: store.downloader.fraction)
            }

            Divider()
                .overlay(.secondary.opacity(0.45))

            HStack(spacing: 12) {
                Image(systemName: store.isSAM3Installed ? "checkmark.icloud.fill" : "wand.and.stars")
                    .foregroundStyle(store.isSAM3Installed ? .green : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(SAM3ModelCatalog.displayName)
                        .font(.callout.weight(.semibold))
                    Text("Text-prompted segmentation masks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    Task { await store.downloadSAM3IfNeeded(force: true) }
                } label: {
                    Image(systemName: store.isSAM3Installed ? "checkmark" : "arrow.down")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .disabled(store.segmentationDownloader.busy)
            }
        }
        .padding(16)
        .glassEffect(.regular.tint(.black.opacity(0.2)), in: .rect(cornerRadius: 28))
        .padding(.horizontal, 14)
    }

    private var segmentPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TextField("Segment a person, cup, dog...", text: $store.segmentationPrompt, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($segmentationPromptFocused)
                    .lineLimit(1...3)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .glassEffect(.regular, in: .rect(cornerRadius: 18))

                Button {
                    Task { await store.downloadSAM3IfNeeded(force: true) }
                } label: {
                    Image(systemName: store.isSAM3Installed ? "checkmark.icloud.fill" : "arrow.down.circle.fill")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .disabled(store.segmentationDownloader.busy)

                Button {
                    Task { await store.segmentCurrentFrame() }
                    segmentationPromptFocused = false
                } label: {
                    Image(systemName: store.isSegmenting ? "ellipsis" : "sparkle.magnifyingglass")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .disabled(store.segmentationPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isSegmenting)
            }

            if store.segmentationDownloader.busy {
                ProgressView(value: store.segmentationDownloader.fraction)
            }

            HStack(spacing: 8) {
                Image(systemName: store.segments.isEmpty ? "lasso" : "lasso.badge.sparkles")
                Text(store.segmentationStatusLine)
                    .lineLimit(2)
                Spacer(minLength: 0)
                if !store.segments.isEmpty {
                    Button {
                        withAnimation(.smooth(duration: 0.22)) {
                            store.clearSegments()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .frame(width: 20, height: 20)
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
        .glassEffect(.regular.tint(.black.opacity(0.2)), in: .rect(cornerRadius: 28))
        .padding(.horizontal, 14)
    }

    private var bottomTabBar: some View {
        GlassEffectContainer(spacing: 14) {
            HStack(spacing: 14) {
                ForEach(RealtimeObjectDetectionTab.allCases) { tab in
                    if store.selectedTab == tab {
                        tabButton(tab)
                            .buttonStyle(.glassProminent)
                    } else {
                        tabButton(tab)
                            .buttonStyle(.glass)
                    }
                }
            }
        }
    }

    private func tabButton(_ tab: RealtimeObjectDetectionTab) -> some View {
        Button {
            if store.selectedTab == tab, tab == .models {
                dismissTransientUI(clearSegments: true)
                return
            }
            dismissTransientUI(clearSegments: tab != .segment)
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

@MainActor
@Observable
final class RealtimeObjectDetectionStore {
    let captureSession = AVCaptureSession()
    let downloader = ModelDownloader()
    let segmentationDownloader = ModelDownloader()

    var selectedModel = RFDETRModelCatalog.nano
    var selectedTab: RealtimeObjectDetectionTab = .detect
    var detections: [CameraDetection] = []
    var segments: [CameraSegment] = []
    var framePixelSize: CGSize = .zero
    var prompt = ""
    var answer: String?
    var segmentationPrompt = "person"
    var segmentationStatusLine = "Download SAM 3 to segment by text prompt."
    var statusLine = "Starting camera..."
    var isDetectionEnabled = true
    var isLoadingModel = false
    var isLoadingSegmenter = false
    var isAnswering = false
    var isSegmenting = false

    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoQueue = DispatchQueue(label: "RealtimeObjectDetection.camera")
    private let frameDelegate = CameraFrameDelegate()
    private let ciContext = CIContext()
    private var detector: ObjectDetector?
    private var segmenter: ImageSegmenter?
    private var loadedModelID: String?
    private var languageSession: LanguageModelSession?
    private var latestFrame: CGImage?
    private var lastInferenceDate = Date.distantPast
    private var isProcessingFrame = false
    private var didConfigureSession = false

    var cameraOverlayOpacity: Double {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: 0
        default: 0.5
        }
    }

    var isSelectedModelInstalled: Bool {
        RFDETRModelCatalog.isInstalled(selectedModel)
    }

    var isSAM3Installed: Bool {
        SAM3ModelCatalog.isInstalled
    }

    var statusSymbol: String {
        if downloader.busy { return "arrow.down.circle.fill" }
        if isLoadingModel { return "shippingbox.fill" }
        if !isSelectedModelInstalled { return "icloud.and.arrow.down" }
        if detections.isEmpty { return "viewfinder" }
        return "scope"
    }

    var sceneSummary: String {
        guard !detections.isEmpty else { return "No confident objects in view." }
        let grouped = Dictionary(grouping: detections) { $0.label }
        let counts: [(label: String, count: Int)] = grouped.map { key, value in
            (label: key, count: value.count)
        }
        let sortedCounts = counts.sorted { lhs, rhs in
            lhs.count == rhs.count ? lhs.label < rhs.label : lhs.count > rhs.count
        }
        return sortedCounts.prefix(6)
            .map { "\($0.count) \($0.label)" }
            .joined(separator: ", ")
    }

    var segmentationSummary: String {
        guard !segments.isEmpty else { return "No SAM 3 segments." }
        return segments.prefix(5)
            .map { "\($0.label) \(Int($0.score * 100)) percent" }
            .joined(separator: ", ")
    }

    func start() async {
        frameDelegate.store = self
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSessionIfNeeded()
            startSession()
            await downloadSelectedModelIfNeeded(force: false)
        case .notDetermined:
            if await AVCaptureDevice.requestAccess(for: .video) {
                configureSessionIfNeeded()
                startSession()
                await downloadSelectedModelIfNeeded(force: false)
            } else {
                statusLine = "Camera permission denied."
            }
        case .denied, .restricted:
            statusLine = "Camera permission denied."
        @unknown default:
            statusLine = "Camera permission unavailable."
        }
    }

    func stop() {
        captureSession.stopRunning()
    }

    func clearSegments() {
        guard !segments.isEmpty else { return }
        segments = []
        segmentationStatusLine = isSAM3Installed
            ? "SAM 3 ready. Enter a text prompt to segment."
            : "Download SAM 3 to segment by text prompt."
    }

    func select(_ model: RFDETRModel) async {
        guard selectedModel != model else { return }
        selectedModel = model
        detector = nil
        loadedModelID = nil
        detections = []
        statusLine = "\(model.displayName) selected."
        await downloadSelectedModelIfNeeded(force: false)
    }

    func downloadSelectedModelIfNeeded(force: Bool) async {
        guard force || !isSelectedModelInstalled else { return }
        statusLine = "Downloading \(selectedModel.displayName)..."
        await downloader.fetch(
            repo: RFDETRModelCatalog.repo,
            items: [
                ModelDownloader.Item(
                    remote: selectedModel.remotePath,
                    local: selectedModel.bundleName
                )
            ],
            into: RFDETRModelCatalog.modelsDirectory
        )

        if isSelectedModelInstalled {
            statusLine = "\(selectedModel.displayName) ready."
        } else if case .failed(let message) = downloader.phase {
            statusLine = message
        }
    }

    func downloadSAM3IfNeeded(force: Bool) async {
        guard force || !isSAM3Installed else {
            segmentationStatusLine = "\(SAM3ModelCatalog.displayName) ready."
            return
        }
        segmentationStatusLine = "Downloading \(SAM3ModelCatalog.displayName)..."
        await segmentationDownloader.fetchBundleRoot(
            repo: SAM3ModelCatalog.repo,
            local: SAM3ModelCatalog.bundleName,
            including: SAM3ModelCatalog.includedPaths,
            into: SAM3ModelCatalog.modelsDirectory
        )

        if isSAM3Installed {
            segmenter = nil
            segmentationStatusLine = "\(SAM3ModelCatalog.displayName) ready."
        } else if case .failed(let message) = segmentationDownloader.phase {
            segmentationStatusLine = message
        }
    }

    func receive(frame cgImage: CGImage) {
        latestFrame = cgImage
        framePixelSize = CGSize(width: cgImage.width, height: cgImage.height)

        guard isDetectionEnabled, isSelectedModelInstalled else {
            if !isSelectedModelInstalled {
                statusLine = "\(selectedModel.displayName) is not downloaded."
            }
            return
        }
        guard !isProcessingFrame else { return }
        guard Date().timeIntervalSince(lastInferenceDate) > selectedModel.minimumFrameInterval else { return }

        isProcessingFrame = true
        lastInferenceDate = Date()

        Task {
            defer { isProcessingFrame = false }
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
                let raw = try await detector.detect(image: cgImage, parameters: params)
                detections = raw.map(CameraDetection.init)
                let elapsed = clock.now - start
                statusLine = detections.isEmpty
                    ? "\(selectedModel.shortName) - scanning"
                    : "\(selectedModel.shortName) - \(elapsed.formattedMilliseconds)"
            } catch {
                statusLine = error.localizedDescription
            }
        }
    }

    func askAboutScene() async {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        prompt = ""
        answer = ""
        isAnswering = true
        defer { isAnswering = false }

        do {
            let session = try preparedLanguageSession()
            let prompt = """
            The camera detector currently sees: \(sceneSummary).
            Current detections: \(detectionListForPrompt).
            Current SAM 3 segments: \(segmentationSummary).

            User question: \(trimmedPrompt)
            """
            let stream = session.streamResponse(
                to: prompt,
                options: GenerationOptions(maximumResponseTokens: 500)
            )
            for try await snapshot in stream {
                answer = snapshot.content
            }
        } catch {
            answer = error.localizedDescription
        }
    }

    func segmentCurrentFrame() async {
        let trimmedPrompt = segmentationPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }
        guard let latestFrame else {
            segmentationStatusLine = "Waiting for a camera frame."
            return
        }

        if !isSAM3Installed {
            await downloadSAM3IfNeeded(force: false)
        }
        guard isSAM3Installed else { return }

        isSegmenting = true
        segmentationStatusLine = "Segmenting \"\(trimmedPrompt)\"..."
        defer { isSegmenting = false }

        do {
            let segmenter = try await preparedSegmenter()
            let response = try await segmenter.segment(
                image: latestFrame,
                prompt: trimmedPrompt,
                parameters: SegmentationParameters(maskThreshold: 0.5, maxSegments: 5)
            )
            segments = response.segments.enumerated().compactMap { index, segment in
                CameraSegment(segment, prompt: trimmedPrompt, index: index)
            }
            segmentationStatusLine = segments.isEmpty
                ? "No \(trimmedPrompt) segment found."
                : "SAM 3 found \(segments.count) \(trimmedPrompt) segment\(segments.count == 1 ? "" : "s")."
        } catch {
            segmentationStatusLine = error.localizedDescription
        }
    }

    private var detectionListForPrompt: String {
        guard !detections.isEmpty else { return "none" }
        return detections.prefix(20)
            .map { detection in
                "\(detection.label) \(Int(detection.confidence * 100)) percent"
            }
            .joined(separator: "; ")
    }

    private func preparedDetector() async throws -> ObjectDetector {
        if let detector, loadedModelID == selectedModel.id { return detector }
        isLoadingModel = true
        defer { isLoadingModel = false }
        let detector = try await ObjectDetector(resourcesAt: RFDETRModelCatalog.bundleURL(for: selectedModel).path)
        try? await detector.warmup()
        self.detector = detector
        loadedModelID = selectedModel.id
        return detector
    }

    private func preparedSegmenter() async throws -> ImageSegmenter {
        if let segmenter { return segmenter }
        isLoadingSegmenter = true
        defer { isLoadingSegmenter = false }
        let segmenter = try await ImageSegmenter(resourcesAt: SAM3ModelCatalog.bundleURL.path)
        try? await segmenter.warmup()
        self.segmenter = segmenter
        return segmenter
    }

    private func preparedLanguageSession() throws -> LanguageModelSession {
        if let languageSession { return languageSession }
        switch SystemLanguageModel.default.availability {
        case .available:
            let session = LanguageModelSession(
                model: .default,
                instructions: "You answer questions about objects detected by an on-device camera detector. Be concise, practical, and mention uncertainty when detections are weak."
            )
            languageSession = session
            return session
        case .unavailable(let reason):
            throw NSError(
                domain: "RealtimeObjectDetection",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Apple Intelligence is unavailable (\(String(describing: reason)))."
                ]
            )
        }
    }

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
            statusLine = "Back camera unavailable."
            return
        }
        captureSession.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        guard captureSession.canAddOutput(videoOutput) else {
            statusLine = "Camera frames unavailable."
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
        statusLine = isSelectedModelInstalled ? "\(selectedModel.displayName) ready." : "Preparing \(selectedModel.displayName)..."
    }

    fileprivate func makeImage(from sampleBuffer: CMSampleBuffer) -> CGImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }
}

private final class CameraFrameDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    weak var store: RealtimeObjectDetectionStore?

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let store, let image = store.makeImage(from: sampleBuffer) else { return }
        Task { @MainActor in
            store.receive(frame: image)
        }
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if let connection = uiView.previewLayer.connection,
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
    }
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

private struct DetectionOverlay: View {
    let detections: [CameraDetection]
    let imageSize: CGSize

    var body: some View {
        GeometryReader { proxy in
            ForEach(detections) { detection in
                let rect = detection.displayRect(in: proxy.size, imageSize: imageSize)
                DetectionBox(detection: detection)
                    .frame(width: max(rect.width, 1), height: max(rect.height, 1))
                    .position(x: rect.midX, y: rect.midY)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct SegmentationOverlay: View {
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

private struct DetectionBox: View {
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

struct CameraDetection: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let labelIndex: Int
    let confidence: Float
    let boundingBox: CGRect

    init(_ detectedObject: DetectedObject) {
        label = detectedObject.label
        labelIndex = detectedObject.labelIndex
        confidence = detectedObject.confidence
        boundingBox = detectedObject.boundingBox
    }

    var color: Color {
        Self.palette[labelIndex % Self.palette.count]
    }

    func displayRect(in viewport: CGSize, imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, viewport.width > 0, viewport.height > 0 else {
            return .zero
        }

        let scale = max(viewport.width / imageSize.width, viewport.height / imageSize.height)
        let scaledImageSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let xOffset = (viewport.width - scaledImageSize.width) / 2
        let yOffset = (viewport.height - scaledImageSize.height) / 2

        return CGRect(
            x: boundingBox.minX * scale + xOffset,
            y: boundingBox.minY * scale + yOffset,
            width: boundingBox.width * scale,
            height: boundingBox.height * scale
        )
    }

    private static let palette: [Color] = [
        .red, .orange, .yellow, .green, .mint, .cyan, .blue, .indigo, .purple, .pink
    ]
}

struct CameraSegment: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let score: Float
    let box: CGRect
    let maskImage: CGImage
    let colorIndex: Int

    init?(_ segment: CoreAIImageSegmenter.Segment, prompt: String, index: Int) {
        guard let maskImage = Self.makeMaskImage(
            mask: segment.mask,
            width: segment.maskWidth,
            height: segment.maskHeight,
            color: Self.palette[index % Self.palette.count]
        ) else {
            return nil
        }
        label = prompt
        score = segment.score
        box = segment.box
        self.maskImage = maskImage
        colorIndex = index
    }

    var color: Color {
        let rgba = Self.palette[colorIndex % Self.palette.count]
        return Color(red: Double(rgba.r) / 255, green: Double(rgba.g) / 255, blue: Double(rgba.b) / 255)
    }

    func displayRect(in viewport: CGSize, imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, viewport.width > 0, viewport.height > 0 else {
            return .zero
        }

        let scale = max(viewport.width / imageSize.width, viewport.height / imageSize.height)
        let scaledImageSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let xOffset = (viewport.width - scaledImageSize.width) / 2
        let yOffset = (viewport.height - scaledImageSize.height) / 2

        return CGRect(
            x: box.minX * scale + xOffset,
            y: box.minY * scale + yOffset,
            width: box.width * scale,
            height: box.height * scale
        )
    }

    private static func makeMaskImage(
        mask: [Bool],
        width: Int,
        height: Int,
        color: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)
    ) -> CGImage? {
        guard width > 0, height > 0, mask.count == width * height else { return nil }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for index in mask.indices where mask[index] {
            let pixelIndex = index * 4
            pixels[pixelIndex + 0] = color.r
            pixels[pixelIndex + 1] = color.g
            pixels[pixelIndex + 2] = color.b
            pixels[pixelIndex + 3] = color.a
        }
        let data = Data(pixels) as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    private static let palette: [(r: UInt8, g: UInt8, b: UInt8, a: UInt8)] = [
        (255, 59, 48, 96),
        (52, 199, 89, 96),
        (0, 122, 255, 96),
        (255, 149, 0, 96),
        (191, 90, 242, 96)
    ]
}

struct RFDETRModel: Identifiable, Hashable, Sendable {
    let id: String
    let bundleName: String
    let remotePath: String
    let displayName: String
    let shortName: String
    let inputPixels: Int
    let detail: String
    let minimumFrameInterval: TimeInterval
}

enum RFDETRModelCatalog {
    static let repo = "mlboydaisuke/RF-DETR-CoreAI"

    static let nano = RFDETRModel(
        id: "rfdetr-nano",
        bundleName: "rfdetr-nano_float32.aimodel",
        remotePath: "rfdetr-nano_float32.aimodel",
        displayName: "RF-DETR Nano",
        shortName: "Nano",
        inputPixels: 384,
        detail: "fastest live detector",
        minimumFrameInterval: 0.12
    )

    static let all: [RFDETRModel] = [
        nano,
        RFDETRModel(
            id: "rfdetr-small",
            bundleName: "rfdetr-small_float32.aimodel",
            remotePath: "rfdetr-small_float32.aimodel",
            displayName: "RF-DETR Small",
            shortName: "Small",
            inputPixels: 512,
            detail: "balanced detail",
            minimumFrameInterval: 0.16
        ),
        RFDETRModel(
            id: "rfdetr-medium",
            bundleName: "rfdetr-medium_float32.aimodel",
            remotePath: "rfdetr-medium_float32.aimodel",
            displayName: "RF-DETR Medium",
            shortName: "Medium",
            inputPixels: 576,
            detail: "higher accuracy",
            minimumFrameInterval: 0.25
        ),
        RFDETRModel(
            id: "rfdetr-large",
            bundleName: "rfdetr-large_float32.aimodel",
            remotePath: "rfdetr-large_float32.aimodel",
            displayName: "RF-DETR Large",
            shortName: "Large",
            inputPixels: 704,
            detail: "largest detector",
            minimumFrameInterval: 0.33
        )
    ]

    static var modelsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("models/object-detection")
    }

    static func isInstalled(_ model: RFDETRModel) -> Bool {
        FileManager.default.fileExists(
            atPath: modelsDirectory.appendingPathComponent(model.bundleName).path
        )
    }

    static func bundleURL(for model: RFDETRModel) -> URL {
        modelsDirectory.appendingPathComponent(model.bundleName)
    }
}

enum SAM3ModelCatalog {
    static let repo = "mlboydaisuke/sam3-CoreAI-official"
    static let displayName = "SAM 3 Core AI"
    static let bundleName = "sam3_float16"
    static let includedPaths = [
        "metadata.json",
        "sam3_float16.aimodel",
        "tokenizer"
    ]

    static var modelsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("models/segmentation")
    }

    static var bundleURL: URL {
        modelsDirectory.appendingPathComponent(bundleName)
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: bundleURL.appendingPathComponent("metadata.json").path)
            && FileManager.default.fileExists(atPath: bundleURL.appendingPathComponent("sam3_float16.aimodel").path)
            && FileManager.default.fileExists(atPath: bundleURL.appendingPathComponent("tokenizer/tokenizer.json").path)
    }
}

enum RealtimeObjectDetectionTab: String, CaseIterable, Identifiable {
    case detect
    case segment
    case ask
    case models

    var id: String { rawValue }

    var title: String {
        switch self {
        case .detect: "Detect"
        case .segment: "Segment"
        case .ask: "Ask"
        case .models: "Models"
        }
    }

    var symbolName: String {
        switch self {
        case .detect: "viewfinder"
        case .segment: "lasso.badge.sparkles"
        case .ask: "text.bubble.fill"
        case .models: "square.stack.3d.up.fill"
        }
    }
}

private extension Duration {
    var formattedMilliseconds: String {
        let (seconds, attoseconds) = components
        let milliseconds = (Double(seconds) * 1000) + (Double(attoseconds) / 1e15)
        return String(format: "%.0f ms", milliseconds)
    }
}

#else

struct RealtimeObjectDetection: View {
    var body: some View {
        ContentUnavailableView(
            "Realtime Object Detection",
            systemImage: "camera.viewfinder",
            description: Text("RF-DETR Core AI detection requires a physical iOS device.")
        )
    }
}

#endif

#Preview {
    RealtimeObjectDetection()
}
