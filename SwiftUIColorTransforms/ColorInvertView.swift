//
//  ColorInvertView.swift

import SwiftUI

struct ColorInvertSiriView: View {
    var body: some View {
        Image(.siriOrb)
            .resizable()
    }
}

struct ColorInvertView: View {
    var body: some View {
        HStack(spacing: 32) {
            Spacer()
            
            Color.red.frame(width: 42, height: 42, alignment: .center)
                .overlay(ColorInvertSiriView(), alignment: .center)
                .overlay(Text("Normal")
                    .font(.caption2),
                         alignment: .bottom)
                .foregroundStyle(.background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .glassEffect()
            
            Color.red.frame(width: 42, height: 42, alignment: .center)
                .overlay(ColorInvertSiriView(), alignment: .center)
                .colorInvert()
                .overlay(Text("Invert")
                    .font(.caption2),
                         alignment: .bottom)
                .foregroundStyle(.background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .glassEffect()
            
            Spacer()
        }
    }
}

#Preview {
    ColorInvertView()
}
