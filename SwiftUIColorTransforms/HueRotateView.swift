//
//  HueRotateView.swift
//  SwiftUIiOS26
//
//  Created by Amos Gyamfi on 17.8.2025.
//

import SwiftUI

struct HueRotateView: View {
    var body: some View {
        HStack {
            
            Spacer()
            
            ForEach(0..<6) {
                Image(.siriOrb)
                    .resizable()
                    .frame(width: 42, height: 42, alignment: .center)
                    .hueRotation((.degrees(Double($0 * 72))))
                    .overlay(Text("\(Double($0) * 72, specifier: "%.0f")°").font(.caption2),
                             alignment: .bottom)
            }
            
            Spacer()
            
        }
    }
}

#Preview {
    HueRotateView()
}
