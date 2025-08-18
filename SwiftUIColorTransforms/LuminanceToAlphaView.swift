//
//  LuminanceToAlphaView.swift
//  SwiftUIiOS26
//
//  Created by Amos Gyamfi on 17.8.2025.
//

import SwiftUI

struct PaletteView: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<10) { index in
                Color(white: Double(index) / Double(9))
                    .frame(width: 20, height: 40)
            }
        }
    }
}

struct LuminanceToAlphaView: View {
    var body: some View {
        HStack {
            
            Spacer()
            
            VStack(spacing: 20) {
                Palette()
                PaletteView()
                    .luminanceToAlpha()
            }
            
            Spacer()
        }
        .padding()
        .background(.blue)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

#Preview {
    LuminanceToAlphaView()
}
