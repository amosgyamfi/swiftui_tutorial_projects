//
//  SaturationView.swift
//  SwiftUIiOS26
//
//  Created by Amos Gyamfi on 17.8.2025.
//

import SwiftUI

struct SaturationView: View {
    var body: some View {
        HStack {
            
            Spacer()
            
            ForEach(0..<6) {
                Image(.siriOrb)
                    .resizable()
                    .frame(width: 42, height: 42, alignment: .center)
                    .saturation(Double($0) * 0.2)
                    .overlay(Text("\(Double($0) * 0.2 * 100, specifier: "%.0f")%").font(.caption2),
                             alignment: .bottom)
            }
            
            Spacer()
            
        }
    }
}

#Preview {
    SaturationView()
}
