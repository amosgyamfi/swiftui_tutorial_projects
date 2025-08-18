//
//  BrightnessView.swift
//
//  Created by Amos Gyamfi on 17.8.2025.
//

import SwiftUI

struct BrightnessSiriView: View {
    var body: some View {
        Image(.siriOrb)
            .resizable()
            .padding(4)
    }
}

struct  BrightnessView: View {
    var body: some View {
        HStack {
            Spacer()
            
            ForEach(0..<6) {
                Color.indigo.frame(width: 42, height: 42, alignment: .center)
                    .overlay(BrightnessSiriView(), alignment: .center)
                    .brightness(Double($0) * 0.2)
                    .overlay(Text("\(Double($0) * 0.2 * 100, specifier: "%.0f")%")
                        .font(.caption2),
                             alignment: .bottom)
                    .foregroundStyle(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .glassEffect()
            }
            
            Spacer()
        }
    }
}

#Preview {
    BrightnessView()
        .preferredColorScheme(.dark)
}
