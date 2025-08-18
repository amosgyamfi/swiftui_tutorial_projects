//
//  SwiftUIColorTransformation.swift
//  SwiftUIiOS26
//
//  Created by Amos Gyamfi on 17.8.2025.
//

import SwiftUI

struct SwiftUIColorTransformation: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    BrightnessView()
                } header: {
                    Text("Brightness")
                } footer: {
                    Text("Brighten the intensity of colors")
                }
                
                Section {
                    ContrastView()
                } header: {
                    Text("Contrast")
                } footer: {
                    Text("Increase or decrease similar color separation")
                }
                
                Section {
                    ColorInvertView()
                } header: {
                    Text("ColorInvert")
                } footer: {
                    Text("Convert to a complementary color")
                }
                
                Section {
                    ColorMultiplyView()
                } header: {
                    Text("ColorMultiply")
                } footer: {
                    Text("Add a color multiplication of Cyan")
                }
                
                Section {
                    SaturationView()
                } header: {
                    Text("Saturation")
                } footer: {
                    Text("Increase or decrease color intensity")
                }
                
                Section {
                    GrayscaleView()
                } header: {
                    Text("Grayscale")
                } footer: {
                    Text("Reduce color intensity")
                }
                
                Section {
                    HueRotateView()
                } header: {
                    Text("HueRotation")
                } footer: {
                    Text("Rotate the chroma value of a view")
                }
                
                Section {
                    LuminanceToAlphaView()
                } header: {
                    Text("LuminanceToAlpha")
                } footer: {
                    Text("Apply a semitransparent mask: Make black transparent & white opaque. Regions of lower luminance become more transparent, while higher luminance yields greater opacity.")
                }
            }
            .navigationTitle("SwiftUI Color Transformation")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SwiftUIColorTransformation()
        .preferredColorScheme(.dark)
}
