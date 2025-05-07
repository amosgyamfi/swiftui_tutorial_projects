//
//  Gemini25Pro05_06.swift
//  CoreSwiftUI
//
//  Created by Amos Gyamfi on 7.5.2025.
//

import SwiftUI

struct Gemini25Pro05_06: View {
    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 40) {
                MicrophoneAnimationView()
                HeartAnimationView()
                SparkleAnimationView()
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.95))
        .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - Microphone Animation

struct MicrophoneAnimationViews: View {
    @State private var animatePulses = false
    let iconSize: CGFloat = 70
    let pulseAnimationDuration = 2.0 // Duration of one pulse expansion

    var body: some View {
        ZStack {
            // Outer Pulse
            Circle()
                // Start opaque, end transparent
                .fill(Color.blue.opacity(animatePulses ? 0 : 0.25))
                .frame(width: iconSize, height: iconSize)
                // Start at base size, expand
                .scaleEffect(animatePulses ? 2.8 : 1.0)
                .animation(
                    Animation.easeOut(duration: pulseAnimationDuration)
                             .repeatForever(autoreverses: false), // Repeats the transition from false state to true state
                    value: animatePulses
                )
            
            // Inner Pulse (slightly delayed and smaller)
            Circle()
                .fill(Color.blue.opacity(animatePulses ? 0 : 0.35))
                .frame(width: iconSize, height: iconSize)
                .scaleEffect(animatePulses ? 2.0 : 0.8) // Starts slightly smaller than icon, expands
                .animation(
                    Animation.easeOut(duration: pulseAnimationDuration)
                             .delay(pulseAnimationDuration * 0.25) // Delay this pulse
                             .repeatForever(autoreverses: false),
                    value: animatePulses
                )

            // Central Icon
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: iconSize, height: iconSize)
                Image(systemName: "mic.fill")
                    .font(.system(size: iconSize * 0.45))
                    .foregroundColor(.white)
            }
        }
        .frame(width: iconSize * 3, height: iconSize * 3) // Provide space for pulses
        .onAppear {
            // This single state change triggers the start of the .repeatForever animations.
            // The animation system will loop the transition from the `animatePulses = false`
            // defined properties to the `animatePulses = true` defined properties.
            self.animatePulses = true
        }
    }
}

// MARK: - Heart Animation

struct FloatingHeartParticleData: Identifiable {
    let id = UUID()
    let initialRelativeOffset: CGSize // Relative to icon center
    let travelDistance: CGFloat
    let startDelay: Double
    let particleSizeFraction: CGFloat = 0.35
}

struct SingleFloatingHeartView: View {
    let data: FloatingHeartParticleData
    let iconSize: CGFloat
    let burstDuration: Double
    
    @State private var scale: CGFloat = 0.1
    @State private var opacity: Double = 0.0
    @State private var currentOffset: CGSize = .zero

    var body: some View {
        Image(systemName: "heart.fill")
            .foregroundColor(.red)
            .font(.system(size: iconSize * data.particleSizeFraction))
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(currentOffset)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + data.startDelay) {
                    // Initial state for animation
                    self.currentOffset = .zero // Start at center of its ZStack position
                    self.scale = 0.2
                    self.opacity = 1.0

                    // Phase 1: Appear, grow, move out
                    withAnimation(.easeOut(duration: burstDuration * 0.7)) {
                        self.scale = 1.0
                        self.currentOffset = CGSize(
                            width: data.initialRelativeOffset.width * data.travelDistance,
                            height: data.initialRelativeOffset.height * data.travelDistance - (iconSize * 0.2) // Extra upward movement
                        )
                    }
                    
                    // Phase 2: Fade out and shrink
                    withAnimation(.easeIn(duration: burstDuration * 0.4).delay(burstDuration * 0.6)) {
                        self.opacity = 0.0
                        self.scale = 0.3
                    }
                }
            }
    }
}

struct HeartAnimationViews: View {
    let iconSize: CGFloat = 70
    @State private var mainHeartColor: Color = .gray
    @State private var mainHeartScale: CGFloat = 1.0
    
    @State private var particleSetID = UUID() // Used to re-create particle views, triggering their onAppear

    let cycleDuration = 3.0
    let burstAnimationDuration = 1.5
    
    let particlesData: [FloatingHeartParticleData] = [
        .init(initialRelativeOffset: CGSize(width: -0.8, height: -0.7), travelDistance: 45, startDelay: 0.0),
        .init(initialRelativeOffset: CGSize(width: 0.8, height: -0.7), travelDistance: 45, startDelay: 0.05),
        .init(initialRelativeOffset: CGSize(width: -0.5, height: 0.8), travelDistance: 40, startDelay: 0.1),
        .init(initialRelativeOffset: CGSize(width: 0.5, height: 0.8), travelDistance: 40, startDelay: 0.15),
        .init(initialRelativeOffset: CGSize(width: 0.0, height: -1.0), travelDistance: 50, startDelay: 0.08) // Top center
    ]

    var body: some View {
        ZStack {
            Image(systemName: "heart.fill")
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .foregroundColor(mainHeartColor)
                .scaleEffect(mainHeartScale)

            if mainHeartColor == .red { // Only show particles when heart is active
                ZStack { // ZStack for particles, centered on the main heart
                    ForEach(particlesData) { data in
                        SingleFloatingHeartView(data: data, iconSize: iconSize, burstDuration: burstAnimationDuration)
                    }
                }
                .id(particleSetID) // Changing ID forces recreation of ForEach content
            }
        }
        .frame(width: iconSize * 3.5, height: iconSize * 3.5) // Space for particles
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: cycleDuration, repeats: true) { _ in
                triggerHeartAnimation()
            }
            triggerHeartAnimation() // Initial burst
        }
    }

    func triggerHeartAnimation() {
        // Phase 1: Main heart turns red and pops
        withAnimation(.interpolatingSpring(stiffness: 180, damping: 12).speed(1.5)) {
            mainHeartColor = .red
            mainHeartScale = 1.25
        }
        
        particleSetID = UUID() // This triggers recreation and animation of particles

        // Phase 2: Main heart returns to gray after burst
        DispatchQueue.main.asyncAfter(deadline: .now() + burstAnimationDuration) {
            withAnimation(.easeInOut(duration: 0.4)) {
                mainHeartColor = .gray
                mainHeartScale = 1.0
            }
        }
    }
}


// MARK: - Sparkle Animation

struct SparkleAnimationViews: View {
    let iconSize: CGFloat = 70
    @State private var isGlowing = false // Controls the glowing state for one cycle

    // Animated properties for the glowing state
    @State private var circleColorOpacity: Double = 0.7 // Base gray circle opacity
    @State private var circleScale: CGFloat = 1.0
    
    @State private var mainGlowScale: CGFloat = 1.0 // For the colored circle part
    @State private var mainGlowOpacity: Double = 0.0 // For the colored circle part (fade in/out)
    
    @State private var outerSoftGlowScale: CGFloat = 0.5
    @State private var outerSoftGlowOpacity: Double = 0.0

    let cycleDuration = 2.8
    let activeGlowDuration = 1.8 // How long the glow effect is visible and animating

    let rainbowColors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .indigo, .purple
    ]

    var body: some View {
        ZStack {
            // Base gray circle (visible when not glowing)
            Circle()
                .fill(Color.gray)
                .frame(width: iconSize, height: iconSize)
                .scaleEffect(circleScale)
                .opacity(circleColorOpacity)

            // Rainbow colored circle that appears on top when glowing
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: rainbowColors + [rainbowColors.first!]), // Loop colors
                        center: .center,
                        angle: .degrees(isGlowing ? 270 : 90) // Rotate for effect
                    )
                )
                .frame(width: iconSize, height: iconSize)
                .scaleEffect(mainGlowScale)
                .opacity(mainGlowOpacity)
            
            // Softer, larger expanding outer glow
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: rainbowColors.map { $0.opacity(0.4) } + [.clear]),
                        center: .center,
                        startRadius: iconSize * 0.2,
                        endRadius: iconSize * 0.6
                    )
                )
                .scaleEffect(outerSoftGlowScale)
                .opacity(outerSoftGlowOpacity)
                .blur(radius: 15) // Soften the glow

            // Sparkles Icon on top
            Image(systemName: "sparkles")
                .font(.system(size: iconSize * 0.5))
                .foregroundColor(.white)
                .scaleEffect(isGlowing ? 1.1 : 1.0) // Slight pop for icon
                .animation(.spring(response: 0.4, dampingFraction: 0.5).delay(isGlowing ? 0.1 : 0), value: isGlowing)
        }
        .frame(width: iconSize * 3, height: iconSize * 3) // Space for glows
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: cycleDuration, repeats: true) { _ in
                performSparkleAnimation()
            }
            performSparkleAnimation() // Initial animation
        }
    }

    func performSparkleAnimation() {
        isGlowing = true // Mark start of glow cycle

        // Reset properties for the start of the glow
        // Gray circle becomes less visible, rainbow circle appears
        withAnimation(.easeOut(duration: 0.2)) {
            circleColorOpacity = 0.2
            mainGlowOpacity = 0.0 // Start transparent for fade-in
            mainGlowScale = 0.8 // Start smaller for grow effect
            outerSoftGlowOpacity = 0.0
            outerSoftGlowScale = 0.5
        }
        
        // Animate TO glowing state
        // Phase 1: Rainbow circle fades in and scales, outer glow appears
        withAnimation(.easeInOut(duration: activeGlowDuration * 0.6).delay(0.1)) {
            mainGlowOpacity = 1.0
            mainGlowScale = 1.15 // Pulse slightly larger
            
            outerSoftGlowOpacity = 0.8
            outerSoftGlowScale = 2.8 // Expand significantly
        }

        // Animate FROM glowing state (fade out)
        // Phase 2: Rainbow circle and outer glow fade out
        withAnimation(.easeInOut(duration: activeGlowDuration * 0.4).delay(activeGlowDuration * 0.6 + 0.1)) {
            mainGlowOpacity = 0.0
            mainGlowScale = 1.0 // Shrink back slightly
            
            outerSoftGlowOpacity = 0.0
            outerSoftGlowScale = 2.0 // Shrink glow as it fades
        }
        
        // After active glow duration, reset to non-glowing state fully
        DispatchQueue.main.asyncAfter(deadline: .now() + activeGlowDuration + 0.1) {
            isGlowing = false // Mark end of glow cycle
            withAnimation(.easeIn(duration: 0.3)) {
                circleColorOpacity = 0.7 // Gray circle fully visible again
                // Other properties reset based on `isGlowing = false` in their definitions or next cycle's reset
            }
        }
    }
}


#Preview {
    Gemini25Pro05_06()
}
