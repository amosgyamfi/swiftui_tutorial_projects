//
//  TextGradientStyles.swift
//  SwiftUIAnimation2026
//
//  Created by Amos Gyamfi on 15.3.2026.
//

import SwiftUI

struct TextGradientStyles: View {
    @State private var shimmer = false
    
    var body: some View {
        
        Text("tts.py")
            .font(.system(size: 64))
            .bold()
        /*.foregroundStyle(
         LinearGradient(gradient: Gradient(colors: [Color.red, Color.blue]), startPoint: .leading, endPoint: .trailing)
         )*/
        
        /*.foregroundStyle(AngularGradient(gradient: Gradient(colors: [Color.red, Color.blue]), center: .trailing))*/
        
        /*.foregroundStyle(RadialGradient(gradient: Gradient(colors: [.red, .green]), center: .bottomTrailing, startRadius: 200, endRadius: 0))*/
         
        
        .foregroundStyle(
         EllipticalGradient(colors:[.blue, .green], center: .center, startRadiusFraction: 0.0, endRadiusFraction: 0.5)
         )
        
        /*.foregroundStyle(
         MeshGradient(
         width: 3,
         height: 3,
         points: [[0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
         [0.0, 0.5], [0.0, 0.5], [1.0, 0.5],
         [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
         ],
         colors: [.red, .purple, .indigo,
         .orange, .white, .blue,
         .yellow, .green, .mint
         ],
         smoothsColors: true,
         colorSpace: .perceptual
         )
         )*/
    }
}


#Preview {
    TextGradientStyles()
        .preferredColorScheme(.dark)
}
