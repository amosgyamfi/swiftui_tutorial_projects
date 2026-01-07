import SwiftUI
import FoundationModels

@main
struct CalculatorProApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

enum CalculatorMode: String, CaseIterable {
    case basic = "Basic"
    case scientific = "Scientific"
    case mathNotes = "Math Notes"
    case convert = "Convert"
    
    var icon: String {
        switch self {
        case .basic: return "plus.forwardslash.minus"
        case .scientific: return "function"
        case .mathNotes: return "pencil.and.list.clipboard"
        case .convert: return "dollarsign.arrow.circlepath"
        }
    }
}

struct HistoryItem: Identifiable, Codable {
    let id: UUID
    let expression: String
    let result: String
    let mode: String
    let timestamp: Date
    
    init(id: UUID = UUID(), expression: String, result: String, mode: String, timestamp: Date = Date()) {
        self.id = id
        self.expression = expression
        self.result = result
        self.mode = mode
        self.timestamp = timestamp
    }
}

struct ContentView: View {
    @State private var mode: CalculatorMode = .basic
    @State private var showHistory = false
    @AppStorage("calculatorHistory") private var historyData: Data = Data()
    
    private var history: [HistoryItem] {
        (try? JSONDecoder().decode([HistoryItem].self, from: historyData)) ?? []
    }
    
    private func addToHistory(_ item: HistoryItem) {
        var items = history
        items.insert(item, at: 0)
        if let encoded = try? JSONEncoder().encode(items) {
            historyData = encoded
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .basic:
                    BasicCalculatorView(onCalculation: addToHistory)
                case .scientific:
                    ScientificCalculatorView(onCalculation: addToHistory)
                case .mathNotes:
                    MathNotesView(onCalculation: addToHistory)
                case .convert:
                    CurrencyConverterView(onCalculation: addToHistory)
                }
            }
            .navigationTitle(mode.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(CalculatorMode.allCases, id: \.self) { calculatorMode in
                            Button {
                                mode = calculatorMode
                            } label: {
                                Label(calculatorMode.rawValue, systemImage: calculatorMode.icon)
                            }
                        }
                    } label: {
                        Image(systemName: "function")
                            .font(.title3)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "timer.circle")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                HistoryView(historyData: $historyData)
            }
        }
    }
}

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var historyData: Data
    @State private var isEditing = false
    
    private var history: [HistoryItem] {
        (try? JSONDecoder().decode([HistoryItem].self, from: historyData)) ?? []
    }
    
    private func deleteItems(at offsets: IndexSet) {
        var items = history
        items.remove(atOffsets: offsets)
        if let encoded = try? JSONEncoder().encode(items) {
            historyData = encoded
        }
    }
    
    private func clearAll() {
        historyData = Data()
        isEditing = false
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if history.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                            Text("No History")
                                .font(.title2.bold())
                            Text("Your past calculations will appear here")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 100)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(history) { item in
                                HStack {
                                    if isEditing {
                                        Button {
                                            if let index = history.firstIndex(where: { $0.id == item.id }) {
                                                deleteItems(at: IndexSet(integer: index))
                                            }
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundStyle(.red)
                                                .font(.title3)
                                        }
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(item.mode)
                                                .font(.caption.bold())
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            Text(item.timestamp, style: .relative)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        
                                        Text(item.expression)
                                            .font(.body)
                                        
                                        Text(item.result)
                                            .font(.title3.bold())
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding()
                                .if(available: iOS26Available()) { view in
                                    view.glassEffect(in: .rect(cornerRadius: 16))
                                }
                                .if(!available: iOS26Available()) { view in
                                    view.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !history.isEmpty {
                        Button(isEditing ? "Done" : "Edit") {
                            isEditing.toggle()
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if !history.isEmpty {
                        Button("Clear All", role: .destructive) {
                            clearAll()
                        }
                    }
                }
            }
        }
    }
}

struct BasicCalculatorView: View {
    @State private var display = "0"
    @State private var currentValue: Double = 0
    @State private var previousValue: Double = 0
    @State private var operation: String?
    @State private var shouldResetDisplay = false
    @FocusState private var isFocused: Bool
    
    let onCalculation: (HistoryItem) -> Void
    
    let buttons: [[String]] = [
        ["AC", "±", "%", "÷"],
        ["7", "8", "9", "×"],
        ["4", "5", "6", "-"],
        ["1", "2", "3", "+"],
        ["0", ".", "="]
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            Text(display)
                .font(.system(size: 70, weight: .light))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            
            VStack(spacing: 12) {
                ForEach(buttons, id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(row, id: \.self) { button in
                            CalculatorButton(title: button, action: {
                                handleButtonPress(button)
                            })
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = false
        }
    }
    
    private func handleButtonPress(_ button: String) {
        switch button {
        case "AC":
            display = "0"
            currentValue = 0
            previousValue = 0
            operation = nil
            
        case "±":
            if let value = Double(display) {
                currentValue = -value
                display = formatNumber(currentValue)
            }
            
        case "%":
            if let value = Double(display) {
                currentValue = value / 100
                display = formatNumber(currentValue)
            }
            
        case "+", "-", "×", "÷":
            if let value = Double(display) {
                if let op = operation {
                    performCalculation(op)
                } else {
                    previousValue = value
                }
                operation = button
                shouldResetDisplay = true
            }
            
        case "=":
            if let op = operation {
                performCalculation(op)
                operation = nil
            }
            
        case ".":
            if shouldResetDisplay {
                display = "0."
                shouldResetDisplay = false
            } else if !display.contains(".") {
                display += "."
            }
            
        default:
            if shouldResetDisplay {
                display = button
                shouldResetDisplay = false
            } else {
                display = (display == "0") ? button : (display + button)
            }
            currentValue = Double(display) ?? 0
        }
    }
    
    private func performCalculation(_ op: String) {
        guard let value = Double(display) else { return }
        
        let expression = "\(formatNumber(previousValue)) \(op) \(formatNumber(value))"
        
        switch op {
        case "+":
            currentValue = previousValue + value
        case "-":
            currentValue = previousValue - value
        case "×":
            currentValue = previousValue * value
        case "÷":
            currentValue = (value != 0) ? (previousValue / value) : 0
        default:
            break
        }
        
        display = formatNumber(currentValue)
        previousValue = currentValue
        shouldResetDisplay = true
        
        onCalculation(HistoryItem(expression: expression, result: display, mode: "Basic"))
    }
    
    private func formatNumber(_ number: Double) -> String {
        if number.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", number)
        } else {
            return String(number)
        }
    }
}

struct CalculatorButton: View {
    let title: String
    let action: () -> Void
    
    private var backgroundColor: Color {
        if ["÷", "×", "-", "+", "="].contains(title) {
            return .orange
        } else if ["AC", "±", "%"].contains(title) {
            return .gray.opacity(0.3)
        } else {
            return Color(.systemGray5)
        }
    }
    
    private var foregroundColor: Color {
        if ["AC", "±", "%"].contains(title) {
            return .black
        } else {
            return .white
        }
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 32, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: (title == "0") ? 75 : 75)
                .foregroundStyle(foregroundColor)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .if(available: iOS26Available()) { view in
            view.buttonStyle(.glass)
        }
    }
}

struct ScientificCalculatorView: View {
    @State private var display = "0"
    @State private var currentValue: Double = 0
    @State private var previousValue: Double = 0
    @State private var operation: String?
    @State private var shouldResetDisplay = false
    @FocusState private var isFocused: Bool
    
    let onCalculation: (HistoryItem) -> Void
    
    let topButtons: [[String]] = [
        ["sin", "cos", "tan", "ln"],
        ["x²", "√", "xʸ", "log"]
    ]
    
    let mainButtons: [[String]] = [
        ["AC", "(", ")", "÷"],
        ["7", "8", "9", "×"],
        ["4", "5", "6", "-"],
        ["1", "2", "3", "+"],
        ["0", ".", "π", "="]
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            Text(display)
                .font(.system(size: 50, weight: .light))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .lineLimit(1)
                .minimumScaleFactor(0.3)
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(topButtons, id: \.self) { row in
                        HStack(spacing: 12) {
                            ForEach(row, id: \.self) { button in
                                ScientificButton(title: button, type: .function, action: {
                                    handleButtonPress(button)
                                })
                            }
                        }
                    }
                    
                    ForEach(mainButtons, id: \.self) { row in
                        HStack(spacing: 12) {
                            ForEach(row, id: \.self) { button in
                                ScientificButton(title: button, type: buttonType(button), action: {
                                    handleButtonPress(button)
                                })
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = false
        }
    }
    
    private func buttonType(_ button: String) -> ScientificButton.ButtonType {
        if ["÷", "×", "-", "+", "="].contains(button) {
            return .operation
        } else if ["AC", "(", ")"].contains(button) {
            return .function
        } else {
            return .number
        }
    }
    
    private func handleButtonPress(_ button: String) {
        switch button {
        case "AC":
            display = "0"
            currentValue = 0
            previousValue = 0
            operation = nil
            
        case "sin":
            if let value = Double(display) {
                let expression = "sin(\(value))"
                currentValue = sin(value * .pi / 180)
                display = formatNumber(currentValue)
                onCalculation(HistoryItem(expression: expression, result: display, mode: "Scientific"))
            }
            
        case "cos":
            if let value = Double(display) {
                let expression = "cos(\(value))"
                currentValue = cos(value * .pi / 180)
                display = formatNumber(currentValue)
                onCalculation(HistoryItem(expression: expression, result: display, mode: "Scientific"))
            }
            
        case "tan":
            if let value = Double(display) {
                let expression = "tan(\(value))"
                currentValue = tan(value * .pi / 180)
                display = formatNumber(currentValue)
                onCalculation(HistoryItem(expression: expression, result: display, mode: "Scientific"))
            }
            
        case "ln":
            if let value = Double(display), value > 0 {
                let expression = "ln(\(value))"
                currentValue = log(value)
                display = formatNumber(currentValue)
                onCalculation(HistoryItem(expression: expression, result: display, mode: "Scientific"))
            }
            
        case "log":
            if let value = Double(display), value > 0 {
                let expression = "log(\(value))"
                currentValue = log10(value)
                display = formatNumber(currentValue)
                onCalculation(HistoryItem(expression: expression, result: display, mode: "Scientific"))
            }
            
        case "x²":
            if let value = Double(display) {
                let expression = "\(value)²"
                currentValue = pow(value, 2)
                display = formatNumber(currentValue)
                onCalculation(HistoryItem(expression: expression, result: display, mode: "Scientific"))
            }
            
        case "√":
            if let value = Double(display), value >= 0 {
                let expression = "√\(value)"
                currentValue = sqrt(value)
                display = formatNumber(currentValue)
                onCalculation(HistoryItem(expression: expression, result: display, mode: "Scientific"))
            }
            
        case "xʸ":
            if let value = Double(display) {
                previousValue = value
                operation = "xʸ"
                shouldResetDisplay = true
            }
            
        case "π":
            display = formatNumber(Double.pi)
            currentValue = Double.pi
            
        case "+", "-", "×", "÷":
            if let value = Double(display) {
                if let op = operation {
                    performCalculation(op)
                } else {
                    previousValue = value
                }
                operation = button
                shouldResetDisplay = true
            }
            
        case "=":
            if let op = operation {
                performCalculation(op)
                operation = nil
            }
            
        case ".":
            if shouldResetDisplay {
                display = "0."
                shouldResetDisplay = false
            } else if !display.contains(".") {
                display += "."
            }
            
        case "(", ")":
            break
            
        default:
            if shouldResetDisplay {
                display = button
                shouldResetDisplay = false
            } else {
                display = (display == "0") ? button : (display + button)
            }
            currentValue = Double(display) ?? 0
        }
    }
    
    private func performCalculation(_ op: String) {
        guard let value = Double(display) else { return }
        
        let expression: String
        
        switch op {
        case "+":
            expression = "\(formatNumber(previousValue)) + \(formatNumber(value))"
            currentValue = previousValue + value
        case "-":
            expression = "\(formatNumber(previousValue)) - \(formatNumber(value))"
            currentValue = previousValue - value
        case "×":
            expression = "\(formatNumber(previousValue)) × \(formatNumber(value))"
            currentValue = previousValue * value
        case "÷":
            expression = "\(formatNumber(previousValue)) ÷ \(formatNumber(value))"
            currentValue = (value != 0) ? (previousValue / value) : 0
        case "xʸ":
            expression = "\(formatNumber(previousValue))^\(formatNumber(value))"
            currentValue = pow(previousValue, value)
        default:
            return
        }
        
        display = formatNumber(currentValue)
        previousValue = currentValue
        shouldResetDisplay = true
        
        onCalculation(HistoryItem(expression: expression, result: display, mode: "Scientific"))
    }
    
    private func formatNumber(_ number: Double) -> String {
        if number.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", number)
        } else {
            let formatted = String(format: "%.10f", number)
            return formatted.trimmingCharacters(in: CharacterSet(charactersIn: "0")).trimmingCharacters(in: CharacterSet(charactersIn: "."))
        }
    }
}

struct ScientificButton: View {
    enum ButtonType {
        case number, operation, function
    }
    
    let title: String
    let type: ButtonType
    let action: () -> Void
    
    private var backgroundColor: Color {
        switch type {
        case .operation:
            return .orange
        case .function:
            return .gray.opacity(0.3)
        case .number:
            return Color(.systemGray5)
        }
    }
    
    private var foregroundColor: Color {
        switch type {
        case .operation:
            return .white
        case .function:
            return .black
        case .number:
            return .white
        }
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 20, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .foregroundStyle(foregroundColor)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .if(available: iOS26Available()) { view in
            view.buttonStyle(.glass)
        }
    }
}

struct MathNotesView: View {
    @State private var inputText = ""
    @State private var result = ""
    @State private var isProcessing = false
    @State private var variables: [String: Double] = [:]
    @State private var showGraphView = false
    @State private var graphEquation = ""
    @FocusState private var isFocused: Bool
    
    let onCalculation: (HistoryItem) -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Math Notes")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Solve expressions, create variables, or graph equations")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .if(available: iOS26Available()) { view in
                    view.glassEffect(in: .rect(cornerRadius: 16))
                }
                .if(!available: iOS26Available()) { view in
                    view.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Input")
                        .font(.headline)
                    
                    TextField("e.g., 2 + 2, x = 5, graph: y = 2x + 1", text: $inputText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .focused($isFocused)
                        .lineLimit(3...6)
                    
                    HStack(spacing: 12) {
                        Button {
                            isFocused = false
                            processInput()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.right.circle.fill")
                                Text("Calculate")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundStyle(.white)
                            .background(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(inputText.isEmpty || isProcessing)
                        .if(available: iOS26Available()) { view in
                            view.buttonStyle(.glassProminent)
                        }
                        
                        Button {
                            inputText = ""
                            result = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .frame(width: 54, height: 54)
                                .foregroundStyle(.gray)
                                .background(Color(.systemGray5))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .if(available: iOS26Available()) { view in
                            view.buttonStyle(.glass)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .if(available: iOS26Available()) { view in
                    view.glassEffect(in: .rect(cornerRadius: 16))
                }
                .if(!available: iOS26Available()) { view in
                    view.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                
                if !result.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Result")
                            .font(.headline)
                        
                        Text(result)
                            .font(.title3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .if(available: iOS26Available()) { view in
                        view.glassEffect(in: .rect(cornerRadius: 16))
                    }
                    .if(!available: iOS26Available()) { view in
                        view.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                
                if !variables.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Variables")
                            .font(.headline)
                        
                        ForEach(Array(variables.keys.sorted()), id: \.self) { key in
                            HStack {
                                Text("\(key) =")
                                    .font(.body.bold())
                                Spacer()
                                Text("\(variables[key] ?? 0, specifier: "%.4g")")
                                    .font(.body)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .if(available: iOS26Available()) { view in
                        view.glassEffect(in: .rect(cornerRadius: 16))
                    }
                    .if(!available: iOS26Available()) { view in
                        view.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                
                if showGraphView {
                    GraphView(equation: graphEquation)
                        .frame(height: 300)
                        .padding()
                        .if(available: iOS26Available()) { view in
                            view.glassEffect(in: .rect(cornerRadius: 16))
                        }
                        .if(!available: iOS26Available()) { view in
                            view.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        }
                }
            }
            .padding()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = false
        }
    }
    
    private func processInput() {
        let input = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if input.lowercased().hasPrefix("graph:") {
            let equation = input.dropFirst(6).trimmingCharacters(in: .whitespaces)
            graphEquation = equation
            showGraphView = true
            result = "Graph displayed below"
            onCalculation(HistoryItem(expression: input, result: result, mode: "Math Notes"))
            return
        }
        
        if input.contains("=") && !input.contains("==") {
            let parts = input.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let varName = parts[0].trimmingCharacters(in: .whitespaces)
                let expression = String(parts[1].trimmingCharacters(in: .whitespaces))
                
                if let value = evaluateExpression(expression) {
                    variables[varName] = value
                    result = "\(varName) = \(value)"
                    onCalculation(HistoryItem(expression: input, result: result, mode: "Math Notes"))
                } else {
                    result = "Error: Could not evaluate expression"
                }
                return
            }
        }
        
        if let value = evaluateExpression(input) {
            result = "\(value)"
            onCalculation(HistoryItem(expression: input, result: result, mode: "Math Notes"))
        } else {
            result = "Error: Could not evaluate expression"
        }
    }
    
    private func evaluateExpression(_ expr: String) -> Double? {
        var expression = expr
        
        for (key, value) in variables {
            expression = expression.replacingOccurrences(of: key, with: "\(value)")
        }
        
        expression = expression.replacingOccurrences(of: "×", with: "*")
        expression = expression.replacingOccurrences(of: "÷", with: "/")
        expression = expression.replacingOccurrences(of: "π", with: "\(Double.pi)")
        
        let nsExpression = NSExpression(format: expression)
        
        if let value = nsExpression.expressionValue(with: nil, context: nil) as? Double {
            return value
        } else if let value = nsExpression.expressionValue(with: nil, context: nil) as? Int {
            return Double(value)
        }
        
        return nil
    }
}

struct GraphView: View {
    let equation: String
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    
                    path.move(to: CGPoint(x: 0, y: height / 2))
                    path.addLine(to: CGPoint(x: width, y: height / 2))
                    
                    path.move(to: CGPoint(x: width / 2, y: 0))
                    path.addLine(to: CGPoint(x: width / 2, y: height))
                }
                .stroke(.gray.opacity(0.5), lineWidth: 1)
                
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let xRange: ClosedRange<Double> = -10...10
                    let yRange: ClosedRange<Double> = -10...10
                    
                    var points: [CGPoint] = []
                    
                    for i in 0...Int(width) {
                        let x = xRange.lowerBound + ((Double(i) / width) * (xRange.upperBound - xRange.lowerBound))
                        
                        if let y = evaluateY(for: x) {
                            let screenX = CGFloat(i)
                            let normalizedY = (y - yRange.lowerBound) / (yRange.upperBound - yRange.lowerBound)
                            let screenY = height - (CGFloat(normalizedY) * height)
                            
                            if screenY >= 0 && screenY <= height {
                                points.append(CGPoint(x: screenX, y: screenY))
                            }
                        }
                    }
                    
                    if !points.isEmpty {
                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                }
                .stroke(.blue, lineWidth: 2)
            }
        }
        .background(Color(.systemBackground).opacity(0.5))
    }
    
    private func evaluateY(for x: Double) -> Double? {
        var expr = equation.lowercased()
        
        if expr.hasPrefix("y=") || expr.hasPrefix("y =") {
            expr = String(expr.drop(while: { $0 != "=" }).dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        
        expr = expr.replacingOccurrences(of: "x", with: "(\(x))")
        expr = expr.replacingOccurrences(of: "π", with: "\(Double.pi)")
        
        let nsExpression = NSExpression(format: expr)
        
        if let value = nsExpression.expressionValue(with: nil, context: nil) as? Double {
            return value
        } else if let value = nsExpression.expressionValue(with: nil, context: nil) as? Int {
            return Double(value)
        }
        
        return nil
    }
}

struct CurrencyConverterView: View {
    @State private var amount = ""
    @State private var fromCurrency = "USD"
    @State private var toCurrency = "EUR"
    @State private var result = ""
    @State private var isLoading = false
    @State private var exchangeRates: [String: Double] = [:]
    @State private var lastUpdated: Date?
    @FocusState private var isFocused: Bool
    
    let onCalculation: (HistoryItem) -> Void
    
    let currencies = [
        "USD", "EUR", "GBP", "JPY", "CNY", "AUD", "CAD", "CHF", "HKD", "SGD",
        "SEK", "KRW", "NOK", "NZD", "INR", "MXN", "ZAR", "BRL", "TRY", "RUB",
        "AED", "SAR", "THB", "IDR", "MYR", "PHP", "VND", "EGP", "CLP", "ARS",
        "DKK", "PLN", "CZK", "ILS", "HUF", "RON", "BGN", "ISK", "UAH", "PKR"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Currency Converter")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let date = lastUpdated {
                        Text("Last updated: \(date, style: .relative) ago")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .if(available: iOS26Available()) { view in
                    view.glassEffect(in: .rect(cornerRadius: 16))
                }
                .if(!available: iOS26Available()) { view in
                    view.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Amount")
                        .font(.headline)
                    
                    TextField("Enter amount", text: $amount)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .focused($isFocused)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("From")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Picker("From", selection: $fromCurrency) {
                                ForEach(currencies, id: \.self) { currency in
                                    Text(currency).tag(currency)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        Spacer()
                        
                        Button {
                            let temp = fromCurrency
                            fromCurrency = toCurrency
                            toCurrency = temp
                            if !amount.isEmpty && !exchangeRates.isEmpty {
                                convertCurrency()
                            }
                        } label: {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.title3)
                                .foregroundStyle(.blue)
                                .frame(width: 44, height: 44)
                                .background(Color(.systemGray6))
                                .clipShape(Circle())
                        }
                        .if(available: iOS26Available()) { view in
                            view.buttonStyle(.glass)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("To")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Picker("To", selection: $toCurrency) {
                                ForEach(currencies, id: \.self) { currency in
                                    Text(currency).tag(currency)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    
                    Button {
                        isFocused = false
                        convertCurrency()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Convert")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundStyle(.white)
                        .background(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(amount.isEmpty || isLoading)
                    .if(available: iOS26Available()) { view in
                        view.buttonStyle(.glassProminent)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .if(available: iOS26Available()) { view in
                    view.glassEffect(in: .rect(cornerRadius: 16))
                }
                .if(!available: iOS26Available()) { view in
                    view.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                
                if !result.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Result")
                            .font(.headline)
                        
                        Text(result)
                            .font(.system(size: 36, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .if(available: iOS26Available()) { view in
                        view.glassEffect(in: .rect(cornerRadius: 16))
                    }
                    .if(!available: iOS26Available()) { view in
                        view.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = false
        }
        .task {
            if exchangeRates.isEmpty {
                await fetchExchangeRates()
            }
        }
    }
    
    private func convertCurrency() {
        guard let amountValue = Double(amount) else {
            result = "Invalid amount"
            return
        }
        
        if exchangeRates.isEmpty {
            isLoading = true
            Task {
                await fetchExchangeRates()
                isLoading = false
                performConversion(amountValue)
            }
            return
        }
        
        performConversion(amountValue)
    }
    
    private func performConversion(_ amountValue: Double) {
        let fromRate = exchangeRates[fromCurrency] ?? 1.0
        let toRate = exchangeRates[toCurrency] ?? 1.0
        
        let converted = (amountValue / fromRate) * toRate
        
        result = String(format: "%.2f %@", converted, toCurrency)
        
        let expression = "\(amountValue) \(fromCurrency) to \(toCurrency)"
        onCalculation(HistoryItem(expression: expression, result: result, mode: "Convert"))
    }
    
    private func fetchExchangeRates() async {
        guard let url = URL(string: "https://api.exchangerate-api.com/v4/latest/USD") else {
            exchangeRates = getDefaultRates()
            lastUpdated = Date()
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let rates = json["rates"] as? [String: Double] {
                exchangeRates = rates
                lastUpdated = Date()
            }
        } catch {
            exchangeRates = getDefaultRates()
            lastUpdated = Date()
        }
    }
    
    private func getDefaultRates() -> [String: Double] {
        return [
            "USD": 1.0, "EUR": 0.92, "GBP": 0.79, "JPY": 149.5, "CNY": 7.24,
            "AUD": 1.53, "CAD": 1.36, "CHF": 0.88, "HKD": 7.83, "SGD": 1.34,
            "SEK": 10.87, "KRW": 1320.0, "NOK": 10.96, "NZD": 1.66, "INR": 83.12,
            "MXN": 17.08, "ZAR": 18.76, "BRL": 4.97, "TRY": 32.65, "RUB": 92.5,
            "AED": 3.67, "SAR": 3.75, "THB": 35.8, "IDR": 15728.0, "MYR": 4.72,
            "PHP": 56.3, "VND": 24515.0, "EGP": 48.9, "CLP": 973.0, "ARS": 976.0,
            "DKK": 6.86, "PLN": 3.93, "CZK": 23.38, "ILS": 3.64, "HUF": 359.0,
            "RON": 4.57, "BGN": 1.80, "ISK": 137.5, "UAH": 41.3, "PKR": 278.5
        ]
    }
}

func iOS26Available() -> Bool {
    if #available(iOS 26.0, *) {
        return true
    }
    return false
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(available: Bool, transform: (Self) -> Content) -> some View {
        if available {
            if #available(iOS 26.0, *) {
                transform(self)
            } else {
                self
            }
        } else {
            self
        }
    }
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}