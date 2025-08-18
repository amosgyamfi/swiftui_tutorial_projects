//
//  ContrastView.swift
//  SwiftUIiOS26
//
//  Created by Amos Gyamfi on 17.8.2025.
//

import SwiftUI

struct CircularView: View {
    var body: some View {
        //Circle()
            //.fill(Color.green)
            //.frame(width: 25, height: 25, alignment: .center)
        Image(.siriOrb)
            .resizable()
            .padding(4)
    }
}

struct ContrastView: View {
    var body: some View {
        HStack {
            
            Spacer()
            
            ForEach(-1..<6) {
                Color.indigo.frame(width: 42, height: 42, alignment: .center)
                    .overlay(CircularView(), alignment: .center)
                    .contrast(Double($0) * 0.2)
                    .overlay(Text("\(Double($0) * 0.2 * 100, specifier: "%.0f")%")
                        .font(.caption2),
                             alignment: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .glassEffect()
            }
            
            Spacer()
        }
        
    }
}

#Preview {
    ContrastView()
        .preferredColorScheme(.dark)
}
