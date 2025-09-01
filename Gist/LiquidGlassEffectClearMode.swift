//
//  LiquidGlassEffectClearMode.swift
//  SwiftUIiOS26
//
/*
 https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass
 
 https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views
 
 https://developer.apple.com/documentation/SwiftUI/GlassEffectContainer
 
 https://developer.apple.com/documentation/swiftui/view/glasseffectunion(id:namespace:)
 
 https://developer.apple.com/documentation/swiftui/view/glasseffectid(_:in:)
 
 */
//

import SwiftUI

struct LiquidGlassEffectClearMode: View {
    var body: some View {
        ZStack {
            Image("bgImage")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            GlassEffectContainer(spacing: 50) {
                PhaseAnimator([false, true]) { morph in
                    HStack(spacing: morph ? 50.0 : -15.0) {
                        Button {
                            //
                        } label: {
                            Image(systemName: "scribble.variable")
                        }
                        .padding()
                        .glassEffect(.clear)
                        
                        Button {
                            //
                        } label: {
                            Image(systemName: "eraser.fill")
                        }
                        .padding()
                        .glassEffect(.clear)
                    }
                    .tint(.green)
                    .font(.system(size: 64.0))
                } animation: { morph in
                    //.bouncy(duration: 2, extraBounce: 0.5)
                    //.easeOut(duration: 2)
                        .easeInOut(duration: 2)
                    //.timingCurve(0.68, -0.6, 0.32, 1.6, duration: 2)
                    
                }
            }
        }
    }
}

#Preview {
    LiquidGlassEffectClearMode()
        .preferredColorScheme(.dark)
}
