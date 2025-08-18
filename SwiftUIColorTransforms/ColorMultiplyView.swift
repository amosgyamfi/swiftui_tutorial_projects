//
//  ColorMultiplyView.swift
//  SwiftUIiOS26
//

import SwiftUI

struct ColorMultiplySiriView: View {
    var body: some View {
        Image(.siriOrb)
            .resizable()
    }
}

struct ColorMultiplyView: View {
    var body: some View {
        HStack(spacing: 32) {
            Spacer()
            
            Color.red.frame(width: 42, height: 42, alignment: .center)
                .overlay(ColorMultiplySiriView(), alignment: .center)
                .overlay(Text("Normal")
                    .font(.caption2),
                         alignment: .bottom)
                .foregroundStyle(.background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .glassEffect()
            
            Color.red.frame(width: 42, height: 42, alignment: .center)
                .overlay(ColorMultiplySiriView(), alignment: .center)
                .colorMultiply(.cyan)
                .overlay(Text("Multiply")
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
    ColorMultiplyView()
}
