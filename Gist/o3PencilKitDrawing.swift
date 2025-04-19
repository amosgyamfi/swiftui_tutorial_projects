//
//  o3PencilKitDrawing.swift
//  CoreSwiftUI
//
//  Created by Amos Gyamfi on 19.4.2025.
//

import SwiftUI
import PencilKit
import UIKit

struct o3PencilKitDrawing: View {
    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    
    var body: some View {
        NavigationStack {
            CanvasRepresentable(canvasView: $canvasView, toolPicker: $toolPicker)
                .onAppear {
                    toolPicker.setVisible(true, forFirstResponder: canvasView)
                    toolPicker.addObserver(canvasView)
                    canvasView.becomeFirstResponder()
                }
                .navigationTitle("o3Draw")
                .navigationBarTitleDisplayMode(.inline)
                  .toolbar {
                      ToolbarItemGroup(placement: .navigationBarLeading) {
                          Button {
                              // Save the current drawing to Photos
                              saveToPhotos()
                          } label: {
                              Label("Save", systemImage: "square.and.arrow.down")
                          }
                      }

                      ToolbarItemGroup(placement: .navigationBarTrailing) {
                          Button {
                              // Undo the last stroke
                              canvasView.undoManager?.undo()
                          } label: {
                              Label("Undo", systemImage: "arrow.uturn.backward")
                          }

                          Button {
                              // Redo the last undone stroke
                              canvasView.undoManager?.redo()
                          } label: {
                              Label("Redo", systemImage: "arrow.uturn.forward")
                          }

                          Button {
                              // Clear the current drawing
                              canvasView.drawing = PKDrawing()
                          } label: {
                              Label("Clear", systemImage: "trash")
                          }
                      }
                  }
         }
    }

    // Save the current drawing to the Photos album
    private func saveToPhotos() {
        let image = canvasView.drawing.image(from: canvasView.bounds, scale: UIScreen.main.scale)
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
}

struct CanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var toolPicker: PKToolPicker
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.alwaysBounceVertical = false
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // No dynamic updates needed for the static canvas
    }
}

#Preview {
    o3PencilKitDrawing()
}
