import SwiftUI
import CoreMotion

@main
struct StepTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// Model representing a completed step tracking activity
struct StepActivity: Identifiable, Codable {
    let id: UUID
    let date: Date
    let duration: TimeInterval
    let steps: Int
    let distance: Double
    let calories: Int
    
    init(id: UUID = UUID(), date: Date, duration: TimeInterval, steps: Int, distance: Double, calories: Int) {
        self.id = id
        self.date = date
        self.duration = duration
        self.steps = steps
        self.distance = distance
        self.calories = calories
    }
}

struct ContentView: View {
    // Active tracking state
    @State private var stepCount = 0
    @State private var isTracking = false
    @State private var startTime: Date?
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var animateSteps = false
    
    // Persistent storage for activity history
    @AppStorage("savedActivities") private var savedActivitiesData: Data = Data()
    @State private var showHistory = false
    
    // CoreMotion pedometer for step counting
    private let pedometer = CMPedometer()
    
    private var savedActivities: [StepActivity] {
        (try? JSONDecoder().decode([StepActivity].self, from: savedActivitiesData)) ?? []
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 40) {
                    Spacer()
                        .frame(height: 20)
                    
                    // Timer display with liquid glass effect
                    if #available(iOS 26.0, *) {
                        timerCard
                            .glassEffect(in: .rect(cornerRadius: 32))
                            .padding(.horizontal, 24)
                    } else {
                        timerCard
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 32))
                            .padding(.horizontal, 24)
                    }
                    
                    // Animated walking figure during tracking
                    if isTracking {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 80))
                            .foregroundStyle(.blue.gradient)
                            .symbolEffect(.bounce.down, options: .repeating, value: animateSteps)
                    }
                    
                    // Steps counter and stats display
                    if #available(iOS 26.0, *) {
                        stepsCard
                            .glassEffect(in: .rect(cornerRadius: 24))
                            .padding(.horizontal, 24)
                    } else {
                        stepsCard
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .padding(.horizontal, 24)
                    }
                    
                    // Start/Stop/Reset controls
                    controlButtons
                        .padding(.horizontal, 24)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Step Tracker")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title3)
                    }
                    .disabled(savedActivities.isEmpty)
                }
            }
            .sheet(isPresented: $showHistory) {
                HistoryView(activities: savedActivities, onDelete: deleteActivity)
            }
            .background(
                LinearGradient(
                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
        }
    }
    
    private var timerCard: some View {
        VStack(spacing: 16) {
            Text("Time")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text(timeString)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
    
    private var stepsCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(stepCount)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                
                Text("steps")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            
            if stepCount > 0 {
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("\(String(format: "%.2f", distance)) km")
                            .font(.title3.bold())
                        Text("Distance")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                        .frame(height: 40)
                    
                    VStack(spacing: 4) {
                        Text("\(calories) cal")
                            .font(.title3.bold())
                        Text("Calories")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var controlButtons: some View {
        if #available(iOS 26.0, *) {
            HStack(spacing: 16) {
                if isTracking {
                    Button {
                        stopTracking()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.red)
                } else {
                    Button {
                        startTracking()
                    } label: {
                        Label("Start", systemImage: "play.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.green)
                    
                    if stepCount > 0 {
                        Button {
                            resetTracking()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.title3.bold())
                                .frame(width: 60)
                                .padding(.vertical, 18)
                        }
                        .buttonStyle(.glass)
                    }
                }
            }
        } else {
            HStack(spacing: 16) {
                if isTracking {
                    Button {
                        stopTracking()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(.red.gradient)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                } else {
                    Button {
                        startTracking()
                    } label: {
                        Label("Start", systemImage: "play.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(.green.gradient)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    
                    if stepCount > 0 {
                        Button {
                            resetTracking()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.title3.bold())
                                .frame(width: 60)
                                .padding(.vertical, 18)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
            }
        }
    }
    
    private var timeString: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    // Calculate distance from steps (average stride length)
    private var distance: Double {
        Double(stepCount) * 0.000762
    }
    
    // Calculate calories burned from steps
    private var calories: Int {
        Int(Double(stepCount) * 0.04)
    }
    
    // Start tracking steps using CoreMotion
    private func startTracking() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        
        isTracking = true
        startTime = Date()
        stepCount = 0
        elapsedTime = 0
        animateSteps = true
        
        pedometer.startUpdates(from: Date()) { data, error in
            guard let data = data, error == nil else { return }
            
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.3)) {
                    stepCount = data.numberOfSteps.intValue
                }
                animateSteps.toggle()
            }
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let start = startTime {
                elapsedTime = Date().timeIntervalSince(start)
            }
        }
    }
    
    // Stop tracking and save the activity
    private func stopTracking() {
        isTracking = false
        pedometer.stopUpdates()
        timer?.invalidate()
        timer = nil
        
        if stepCount > 0, let start = startTime {
            let activity = StepActivity(
                date: start,
                duration: elapsedTime,
                steps: stepCount,
                distance: distance,
                calories: calories
            )
            saveActivity(activity)
        }
    }
    
    // Save activity to persistent storage
    private func saveActivity(_ activity: StepActivity) {
        var activities = savedActivities
        activities.insert(activity, at: 0)
        if let encoded = try? JSONEncoder().encode(activities) {
            savedActivitiesData = encoded
        }
    }
    
    // Delete activity from history
    private func deleteActivity(at offsets: IndexSet) {
        var activities = savedActivities
        activities.remove(atOffsets: offsets)
        if let encoded = try? JSONEncoder().encode(activities) {
            savedActivitiesData = encoded
        }
    }
}

// View displaying the list of past step activities
struct HistoryView: View {
    let activities: [StepActivity]
    let onDelete: (IndexSet) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if activities.isEmpty {
                    ScrollView {
                        VStack(spacing: 16) {
                            Image(systemName: "figure.walk.circle")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                            Text("No activities yet")
                                .font(.title2.bold())
                            Text("Complete a step activity to see it here")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                    }
                } else {
                    List {
                        ForEach(activities) { activity in
                            if #available(iOS 26.0, *) {
                                ActivityCard(activity: activity)
                                    .padding(4)
                                    .glassEffect(in: .rect(cornerRadius: 12))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            } else {
                                ActivityCard(activity: activity)
                                    .padding(4)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            }
                        }
                        .onDelete(perform: onDelete)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Activity History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .background(
                LinearGradient(
                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
        }
    }
}

// Card view displaying a single activity's details
struct ActivityCard: View {
    let activity: StepActivity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(activity.date, style: .date)
                        .font(.headline)
                    Text(activity.date, style: .time)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(durationString)
                    .font(.title3.bold())
                    .foregroundStyle(.blue)
            }
            
            Divider()
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(activity.steps)")
                            .font(.title.bold())
                        Text("steps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .foregroundStyle(.blue)
                        Text(String(format: "%.2f km", activity.distance))
                            .font(.subheadline.bold())
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("\(activity.calories) cal")
                            .font(.subheadline.bold())
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var durationString: String {
        let hours = Int(activity.duration) / 3600
        let minutes = (Int(activity.duration) % 3600) / 60
        let seconds = Int(activity.duration) % 60
        
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %02ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    private func resetTracking() {
        stepCount = 0
        elapsedTime = 0
        startTime = nil
    }
}
