import SwiftUI

/*
 Create the following SwiftUI animations for the sparkle, circle, and music symbols.
 1. Sparkle: Repeating spinning animation in clockwise direction using easeInOut.
 2. Circle: Repeating spinning animation in clockwise direction using easeInOut. Animate the strokeStart from 0.5 to 0.3 repeatedly as the circle rotates. At the same time, animate the strokeEnd from 0.8 to 1.0 repeatedly.
 3. Music symbol: Repeating animation using y-offset of 0 to -10 and y-scale of 1.0 to 0.8.
 Use PhaseAnimator for all the animations.
*/

struct LoadingView: View {
    // Drives the phase changes for all three animated elements
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Music symbol – bounces up/down and scales on the Y‑axis
            Image(systemName: "music.quarternote.3")
                .font(.system(size: 80))
                .phaseAnimator([false, true],
                               trigger: isAnimating) { content, phase in
                    content
                        .offset(y: phase ? -10 : 0)
                        .scaleEffect(x: 1.0, y: phase ? 0.8 : 1.0)
                } animation: { _ in
                        .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                }
            
            // Circle + Sparkle (sparkle sits on top‑right of circle)
            ZStack(alignment: .topTrailing) {
                
                // Circle – rotates and “breathes” its trim values
                Circle() // placeholder; real drawing handled inside phaseAnimator
                    .phaseAnimator([false, true],
                                   trigger: isAnimating) { _, phase in
                        Circle()
                            .trim(from: phase ? 0.3 : 0.5,
                                  to: phase ? 1.0 : 0.8)
                            .stroke(style: StrokeStyle(
                                lineWidth: 20,
                                lineCap: .round,
                                lineJoin: .round))
                            .frame(width: 200, height: 200)
                            .rotationEffect(Angle.degrees(phase ? 360 : 0))
                    } animation: { _ in
                            .easeInOut(duration: 1.5).repeatForever(autoreverses: false)
                    }
                
                // Sparkle – continuous clockwise spin
                Image(systemName: "sparkle")
                    .font(.system(size: 48))
                    .padding(32)
                    .phaseAnimator([false, true],
                                   trigger: isAnimating) { content, phase in
                        content
                            .rotationEffect(Angle.degrees(phase ? 360 : 0))
                    } animation: { _ in
                            .easeInOut(duration: 1.2).repeatForever(autoreverses: false)
                    }
            }
        }
        // Kick‑off the phase loop once the view appears
        .padding()
        .onAppear {
            isAnimating.toggle()
        }
    }
}

#Preview {
    LoadingView()
}
