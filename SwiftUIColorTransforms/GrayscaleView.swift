//
//  GrayscaleView.swift
//  SwiftUIiOS26
//

import SwiftUI

struct GrayscaleView: View {
    var body: some View {
        HStack {
            
            Spacer()
            
            ForEach(0..<6) {
                Image(.siriOrb)
                    .resizable()
                    .frame(width: 42, height: 42, alignment: .center)
                    .grayscale(Double($0) * 0.1999)
                    .overlay(Text("\(Double($0) * 0.1999 * 100, specifier: "%.2f")%").font(.caption2),
                             alignment: .bottom)
            }
            
            Spacer()
            
        }
    }
}


#Preview {
    GrayscaleView()
}
