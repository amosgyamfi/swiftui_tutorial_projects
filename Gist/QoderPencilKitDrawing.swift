//
//  QoderPencilKitDrawing.swift
//  SwiftUIiOS26
//
//  A comprehensive and beautiful SwiftUI drawing app using PencilKit
//  Features: Advanced drawing tools, templates, layers, export options, and more
//

import SwiftUI
import PencilKit
import UIKit
import UniformTypeIdentifiers
import Photos

struct QoderPencilKitDrawing: View {
    // MARK: - Drawing State
    @State private var drawing: PKDrawing = PKDrawing()
    @State private var canvasView: PKCanvasView = PKCanvasView()
    @State private var showsToolPicker: Bool = true
    @State private var allowsFingerDrawing: Bool = true
    @State private var isRulerActive: Bool = false
    
    // MARK: - UI State
    @State private var isShareSheetPresented: Bool = false
    @State private var isSettingsPresented: Bool = false
    @State private var isTemplatePickerPresented: Bool = false
    @State private var isGalleryPresented: Bool = false
    @State private var exportedImage: UIImage? = nil
    @State private var showingExportOptions: Bool = false
    @State private var showingSaveAlert: Bool = false
    @State private var saveAlertMessage: String = ""
    
    // MARK: - Drawing Configuration
    @State private var backgroundColor: Color = .white
    @State private var canvasOpacity: Double = 1.0
    @State private var showGrid: Bool = false
    @State private var gridSize: Double = 20
    @State private var selectedTemplate: DrawingTemplate? = nil
    
    // MARK: - Gesture State
    @State private var currentScale: CGFloat = 1.0
    @State private var finalScale: CGFloat = 1.0
    @State private var currentOffset: CGSize = .zero
    @State private var finalOffset: CGSize = .zero
    
    // MARK: - Animation
    @State private var toolbarOffset: CGFloat = 0
    @State private var isToolbarVisible: Bool = true
    @State private var imageSaveHelper = ImageSaveHelper()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                backgroundView
                
                // Main Canvas Area
                canvasArea
                
                // Floating Tool Panel
                if isToolbarVisible {
                    floatingToolPanel
                }
                
                // Quick Actions
                quickActionButtons
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .navigationTitle("Qoder Drawing")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isGalleryPresented = true
                    } label: {
                        Image(systemName: "photo.stack")
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("Open Gallery")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isSettingsPresented = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $isShareSheetPresented, onDismiss: { exportedImage = nil }) {
                if let image = exportedImage {
                    ShareSheet(activityItems: [image])
                }
            }
            .sheet(isPresented: $isSettingsPresented) {
                DrawingSettingsView(
                    backgroundColor: $backgroundColor,
                    canvasOpacity: $canvasOpacity,
                    showGrid: $showGrid,
                    gridSize: $gridSize,
                    allowsFingerDrawing: $allowsFingerDrawing
                )
            }
            .sheet(isPresented: $isTemplatePickerPresented) {
                TemplatePickerView(selectedTemplate: $selectedTemplate)
            }
            .sheet(isPresented: $isGalleryPresented) {
                DrawingGalleryView()
            }
            .confirmationDialog("Export Options", isPresented: $showingExportOptions) {
                Button("Export as PNG") { exportImage(format: .png) }
                Button("Export as PDF") { exportImage(format: .pdf) }
                Button("Share Drawing") { shareDrawing() }
                Button("Save to Gallery") { saveToGallery() }
                Button("Cancel", role: .cancel) { }
            }
            .alert("Gallery Save", isPresented: $showingSaveAlert) {
                Button("OK") { }
            } message: {
                Text(saveAlertMessage)
            }
            .onAppear {
                setupCanvas()
            }
            .onChange(of: selectedTemplate) { _, newTemplate in
                applyTemplate(newTemplate)
            }
        }
    }
}

// MARK: - View Components
extension QoderPencilKitDrawing {
    
    private var backgroundView: some View {
        backgroundColor
            .opacity(canvasOpacity)
            .overlay {
                if showGrid {
                    GridOverlay(size: gridSize)
                        .opacity(0.3)
                }
            }
            .ignoresSafeArea()
    }
    
    private var canvasArea: some View {
        QoderPencilCanvas(
            drawing: $drawing,
            canvasView: $canvasView,
            showsToolPicker: $showsToolPicker,
            allowsFingerDrawing: $allowsFingerDrawing,
            isRulerActive: $isRulerActive,
            backgroundColor: backgroundColor
        )
        .scaleEffect(currentScale * finalScale)
        .offset(
            x: currentOffset.width + finalOffset.width,
            y: currentOffset.height + finalOffset.height
        )
        // Only apply zoom/pan gestures when tool picker is hidden to avoid conflicts
        .gesture(
            !showsToolPicker ? 
            SimultaneousGesture(
                magnificationGesture,
                dragGesture
            ) : nil
        )
        .onTapGesture(count: 2) {
            if !showsToolPicker {
                withAnimation(.spring()) {
                    resetZoomAndPan()
                }
            }
        }
    }
    
    private var floatingToolPanel: some View {
        VStack(spacing: 16) {
            // Tool Picker Toggle
            Button {
                withAnimation(.spring()) {
                    toggleToolPickerVisibility()
                }
            } label: {
                Image(systemName: showsToolPicker ? "pencil.tip.crop.circle.badge.minus" : "pencil.tip.crop.circle")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.3))
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            }
                    )
            }
            .accessibilityLabel("Toggle Tool Picker")
            
            // Ruler Toggle
            Button {
                withAnimation(.spring()) {
                    isRulerActive.toggle()
                }
            } label: {
                Image(systemName: isRulerActive ? "ruler.fill" : "ruler")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(isRulerActive ? .blue : Color.black.opacity(0.3))
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            }
                    )
            }
            .accessibilityLabel("Toggle Ruler")
            
            // Finger Drawing Toggle
            Button {
                withAnimation(.spring()) {
                    allowsFingerDrawing.toggle()
                }
            } label: {
                Image(systemName: allowsFingerDrawing ? "hand.draw.fill" : "hand.draw")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(allowsFingerDrawing ? .green : Color.black.opacity(0.3))
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            }
                    )
            }
            .accessibilityLabel("Toggle Finger Drawing")
            
            // Undo
            Button {
                canvasView.undoManager?.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.3))
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            }
                    )
            }
            .disabled(!(canvasView.undoManager?.canUndo ?? false))
            .accessibilityLabel("Undo")
            
            // Redo
            Button {
                canvasView.undoManager?.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.3))
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            }
                    )
            }
            .disabled(!(canvasView.undoManager?.canRedo ?? false))
            .accessibilityLabel("Redo")
        }
        .padding(.trailing, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .offset(x: toolbarOffset)
        .transition(.move(edge: .trailing))
    }
    
    private var quickActionButtons: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 16) {
                // Templates
                Button {
                    isTemplatePickerPresented = true
                } label: {
                    Image(systemName: "doc.richtext")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(.purple.gradient)
                                .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                }
                .accessibilityLabel("Choose Template")
                
                // Clear Canvas
                Button(role: .destructive) {
                    clearCanvas()
                } label: {
                    Image(systemName: "trash")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(.red.gradient)
                                .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                }
                .accessibilityLabel("Clear Canvas")
                
                Spacer()
                
                // Export Options
                Button {
                    showingExportOptions = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(.blue.gradient)
                                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                }
                .accessibilityLabel("Export Drawing")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 50)
        }
    }
}

// MARK: - Gestures
extension QoderPencilKitDrawing {
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                currentScale = value
            }
            .onEnded { value in
                finalScale *= currentScale
                currentScale = 1.0
                
                // Constrain scale
                if finalScale < 0.5 {
                    finalScale = 0.5
                } else if finalScale > 3.0 {
                    finalScale = 3.0
                }
            }
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                currentOffset = value.translation
            }
            .onEnded { value in
                finalOffset.width += currentOffset.width
                finalOffset.height += currentOffset.height
                currentOffset = .zero
            }
    }
}

// MARK: - Methods
extension QoderPencilKitDrawing {
    
    private func setupCanvas() {
        // Ensure canvas is ready for drawing
        DispatchQueue.main.async {
            if self.showsToolPicker {
                self.canvasView.becomeFirstResponder()
            }
        }
    }
    
    private func toggleToolPickerVisibility() {
        showsToolPicker.toggle()
        if showsToolPicker {
            canvasView.becomeFirstResponder()
        } else {
            canvasView.resignFirstResponder()
        }
    }
    
    private func clearCanvas() {
        canvasView.drawing = PKDrawing()
        drawing = canvasView.drawing
    }
    
    private func resetZoomAndPan() {
        currentScale = 1.0
        finalScale = 1.0
        currentOffset = .zero
        finalOffset = .zero
    }
    
    private func exportImage(format: ExportFormat) {
        guard let image = exportImage() else { return }
        
        switch format {
        case .png:
            exportedImage = image
            isShareSheetPresented = true
        case .pdf:
            // TODO: Implement PDF export
            break
        }
    }
    
    private func shareDrawing() {
        exportedImage = exportImage()
        isShareSheetPresented = exportedImage != nil
    }
    
    private func saveToGallery() {
        guard let image = exportImage() else {
            saveAlertMessage = "Failed to generate image from drawing."
            showingSaveAlert = true
            return
        }
        
        // Check photo library permission
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .authorized, .limited:
            // Permission granted, save the image
            saveImageToPhotoLibrary(image)
            
        case .denied, .restricted:
            // Permission denied
            saveAlertMessage = "Photo library access denied. Please enable access in Settings to save drawings."
            showingSaveAlert = true
            
        case .notDetermined:
            // Request permission
            PHPhotoLibrary.requestAuthorization { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        self.saveImageToPhotoLibrary(image)
                    } else {
                        self.saveAlertMessage = "Photo library access is required to save drawings."
                        self.showingSaveAlert = true
                    }
                }
            }
            
        @unknown default:
            saveAlertMessage = "Unable to access photo library."
            showingSaveAlert = true
        }
    }
    
    private func saveImageToPhotoLibrary(_ image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetCreationRequest.creationRequestForAsset(from: image)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.saveAlertMessage = "Drawing saved to Photos successfully! 🎨"
                    self.showingSaveAlert = true
                } else {
                    // Try fallback method if the modern API fails
                    self.saveImageWithFallback(image)
                }
            }
        }
    }
    
    private func saveImageWithFallback(_ image: UIImage) {
        imageSaveHelper.saveImage(image) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.saveAlertMessage = "Drawing saved to Photos successfully! 🎨"
                } else {
                    self.saveAlertMessage = "Failed to save drawing to Photos. \(error?.localizedDescription ?? "Unknown error")"
                }
                self.showingSaveAlert = true
            }
        }
    }
    
    private func exportImage() -> UIImage? {
        let bounds = canvasView.bounds
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let scale = UIScreen.main.scale
        return canvasView.drawing.image(from: bounds, scale: scale)
    }
    
    private func applyTemplate(_ template: DrawingTemplate?) {
        guard let template = template else { return }
        
        // Apply template settings
        backgroundColor = template.backgroundColor
        canvasOpacity = template.opacity
        showGrid = template.showGrid
        gridSize = template.gridSize
        
        // Apply template drawing if available
        if let templateDrawing = template.drawing {
            canvasView.drawing = templateDrawing
            drawing = templateDrawing
        }
    }
}

// MARK: - Supporting Types
enum ExportFormat {
    case png
    case pdf
}

struct DrawingTemplate: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let backgroundColor: Color
    let opacity: Double
    let showGrid: Bool
    let gridSize: Double
    let drawing: PKDrawing?
    let thumbnail: UIImage?
    
    static func == (lhs: DrawingTemplate, rhs: DrawingTemplate) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Enhanced PencilKit Canvas

struct QoderPencilCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    @Binding var canvasView: PKCanvasView
    @Binding var showsToolPicker: Bool
    @Binding var allowsFingerDrawing: Bool
    @Binding var isRulerActive: Bool
    let backgroundColor: Color
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawing = drawing
        canvasView.isOpaque = false
        canvasView.backgroundColor = UIColor(backgroundColor)
        canvasView.delegate = context.coordinator
        canvasView.drawingPolicy = allowsFingerDrawing ? .anyInput : .pencilOnly
        canvasView.isRulerActive = isRulerActive
        canvasView.minimumZoomScale = 0.5
        canvasView.maximumZoomScale = 3.0
        canvasView.bouncesZoom = true
        
        // Enable user interaction
        canvasView.isUserInteractionEnabled = true
        canvasView.isMultipleTouchEnabled = true
        
        // Enhanced drawing policy configuration
        if #available(iOS 14.0, *) {
            canvasView.drawingPolicy = allowsFingerDrawing ? .anyInput : .pencilOnly
        }
        
        // Setup tool picker
        setupToolPicker(for: canvasView, coordinator: context.coordinator)
        
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
        
        uiView.backgroundColor = UIColor(backgroundColor)
        uiView.drawingPolicy = allowsFingerDrawing ? .anyInput : .pencilOnly
        uiView.isRulerActive = isRulerActive
        
        // Update tool picker visibility
        updateToolPicker(for: uiView, coordinator: context.coordinator)
    }
    
    private func setupToolPicker(for canvasView: PKCanvasView, coordinator: Coordinator) {
        if coordinator.toolPicker == nil {
            coordinator.toolPicker = PKToolPicker()
        }
        
        guard let toolPicker = coordinator.toolPicker else { return }
        
        // Configure the tool picker
        toolPicker.addObserver(canvasView)
        toolPicker.setVisible(showsToolPicker, forFirstResponder: canvasView)
        
        if showsToolPicker {
            DispatchQueue.main.async {
                canvasView.becomeFirstResponder()
            }
        }
        
        // Ensure we have a default tool selected
        if let inkingTool = toolPicker.selectedTool as? PKInkingTool {
            // Tool is already an inking tool, which is good
        } else {
            // Set a default pen tool if no inking tool is selected
            let defaultTool = PKInkingTool(.pen, color: .black, width: 5)
            toolPicker.selectedTool = defaultTool
        }
    }
    
    private func updateToolPicker(for canvasView: PKCanvasView, coordinator: Coordinator) {
        guard let toolPicker = coordinator.toolPicker else { return }
        
        toolPicker.setVisible(showsToolPicker, forFirstResponder: canvasView)
        
        if showsToolPicker {
            DispatchQueue.main.async {
                canvasView.becomeFirstResponder()
            }
        } else {
            canvasView.resignFirstResponder()
        }
    }
    
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: QoderPencilCanvas
        var toolPicker: PKToolPicker?
        
        init(_ parent: QoderPencilCanvas) {
            self.parent = parent
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            DispatchQueue.main.async {
                self.parent.drawing = canvasView.drawing
            }
        }
        
        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            // Tool usage started - drawing is active
            let toolDescription: String
            if let inkingTool = toolPicker?.selectedTool as? PKInkingTool {
                toolDescription = "Inking tool: \(inkingTool.inkType)"
            } else if toolPicker?.selectedTool is PKEraserTool {
                toolDescription = "Eraser tool"
            } else if toolPicker?.selectedTool is PKLassoTool {
                toolDescription = "Lasso tool"
            } else {
                toolDescription = "Unknown tool"
            }
            print("Drawing started with \(toolDescription)")
        }
        
        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            // Tool usage ended
            print("Drawing ended")
        }
        
        func canvasViewDidFinishRendering(_ canvasView: PKCanvasView) {
            // Canvas finished rendering
        }
    }
}

// MARK: - Settings View

struct DrawingSettingsView: View {
    @Binding var backgroundColor: Color
    @Binding var canvasOpacity: Double
    @Binding var showGrid: Bool
    @Binding var gridSize: Double
    @Binding var allowsFingerDrawing: Bool
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Canvas") {
                    ColorPicker("Background Color", selection: $backgroundColor)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Canvas Opacity")
                        Slider(value: $canvasOpacity, in: 0...1, step: 0.1) {
                            Text("Opacity")
                        } minimumValueLabel: {
                            Text("0%")
                        } maximumValueLabel: {
                            Text("100%")
                        }
                        Text("\(Int(canvasOpacity * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Grid") {
                    Toggle("Show Grid", isOn: $showGrid)
                    
                    if showGrid {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Grid Size")
                            Slider(value: $gridSize, in: 10...50, step: 5) {
                                Text("Grid Size")
                            } minimumValueLabel: {
                                Text("10")
                            } maximumValueLabel: {
                                Text("50")
                            }
                            Text("\(Int(gridSize)) points")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section("Input") {
                    Toggle("Allow Finger Drawing", isOn: $allowsFingerDrawing)
                }
                
                Section("About") {
                    Label("Qoder Drawing App", systemImage: "paintbrush")
                    Label("Version 1.0", systemImage: "info.circle")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Template Picker

struct TemplatePickerView: View {
    @Binding var selectedTemplate: DrawingTemplate?
    @Environment(\.dismiss) private var dismiss
    
    private let templates: [DrawingTemplate] = [
        DrawingTemplate(
            name: "Blank Canvas",
            backgroundColor: .white,
            opacity: 1.0,
            showGrid: false,
            gridSize: 20,
            drawing: nil,
            thumbnail: nil
        ),
        DrawingTemplate(
            name: "Grid Paper",
            backgroundColor: .white,
            opacity: 1.0,
            showGrid: true,
            gridSize: 20,
            drawing: nil,
            thumbnail: nil
        ),
        DrawingTemplate(
            name: "Dark Canvas",
            backgroundColor: .black,
            opacity: 1.0,
            showGrid: false,
            gridSize: 20,
            drawing: nil,
            thumbnail: nil
        ),
        DrawingTemplate(
            name: "Sepia",
            backgroundColor: Color(red: 0.96, green: 0.93, blue: 0.85),
            opacity: 1.0,
            showGrid: false,
            gridSize: 20,
            drawing: nil,
            thumbnail: nil
        )
    ]
    
    var body: some View {
        NavigationStack {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 150), spacing: 16)
            ], spacing: 16) {
                ForEach(templates) { template in
                    TemplateCard(template: template) {
                        selectedTemplate = template
                        dismiss()
                    }
                }
            }
            .padding()
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TemplateCard: View {
    let template: DrawingTemplate
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(template.backgroundColor.gradient)
                    .frame(height: 120)
                    .overlay {
                        if template.showGrid {
                            GridOverlay(size: template.gridSize)
                                .opacity(0.3)
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    }
                
                Text(template.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Gallery View

struct DrawingGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var savedDrawings: [SavedDrawing] = []
    
    var body: some View {
        NavigationStack {
            if savedDrawings.isEmpty {
                ContentUnavailableView(
                    "No Drawings Yet",
                    systemImage: "paintbrush",
                    description: Text("Your saved drawings will appear here")
                )
            } else {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 150), spacing: 16)
                ], spacing: 16) {
                    ForEach(savedDrawings) { drawing in
                        DrawingCard(drawing: drawing)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Gallery")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            loadSavedDrawings()
        }
    }
    
    private func loadSavedDrawings() {
        // TODO: Implement loading from persistent storage
    }
}

struct DrawingCard: View {
    let drawing: SavedDrawing
    
    var body: some View {
        VStack(spacing: 8) {
            if let thumbnail = drawing.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 120)
                    .overlay {
                        Image(systemName: "paintbrush")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(drawing.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(drawing.dateCreated, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Grid Overlay

struct GridOverlay: View {
    let size: Double
    
    var body: some View {
        Canvas { context, canvasSize in
            let gridSpacing = size
            
            // Vertical lines
            for x in stride(from: 0, through: canvasSize.width, by: gridSpacing) {
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: canvasSize.height))
                    },
                    with: .color(.primary.opacity(0.2)),
                    lineWidth: 0.5
                )
            }
            
            // Horizontal lines
            for y in stride(from: 0, through: canvasSize.height, by: gridSpacing) {
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: canvasSize.width, y: y))
                    },
                    with: .color(.primary.opacity(0.2)),
                    lineWidth: 0.5
                )
            }
        }
    }
}

// MARK: - Supporting Models

struct SavedDrawing: Identifiable {
    let id = UUID()
    let name: String
    let drawing: PKDrawing
    let thumbnail: UIImage?
    let dateCreated: Date
}

// MARK: - Image Save Helper Class

class ImageSaveHelper: NSObject {
    var completion: ((Bool, Error?) -> Void)?
    
    func saveImage(_ image: UIImage, completion: @escaping (Bool, Error?) -> Void) {
        self.completion = completion
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        completion?(error == nil, error)
        completion = nil
    }
}

#Preview {
    QoderPencilKitDrawing()
}
