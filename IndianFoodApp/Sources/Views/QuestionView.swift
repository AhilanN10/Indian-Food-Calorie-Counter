import SwiftUI

struct QuestionView: View {
    let questions: [QAQuestion]
    let dishName: String
    let servingSizeG: Double?
    @Binding var responses: [String: String]
    let onComplete: () -> Void

    @EnvironmentObject private var profileStore: ProfileStore
    @State private var currentIndex = 0

    // Manual weight entry
    @State private var manualEntryActive     = false
    @State private var weightInput           = ""
    @State private var showLargePortionAlert = false

    private let ozToGrams = 28.3495

    var currentQuestion: QAQuestion { questions[currentIndex] }
    var progress: Double { Double(currentIndex + 1) / Double(questions.count) }

    private var usesImperial: Bool {
        (profileStore.profile?.unitSystem ?? .metric) == .imperial
    }
    private var unitLabel: String { usesImperial ? "oz" : "g" }

    /// Entered value converted to canonical grams (nil if not a valid number)
    private var enteredGrams: Double? {
        let normalised = weightInput.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalised), value > 0 else { return nil }
        return usesImperial ? value * ozToGrams : value
    }

    private var belowMinimum: Bool {
        guard let grams = enteredGrams else { return false }
        return grams < 5
    }

    /// Manual entry offered only when the dish has a usable standard serving weight
    private var manualWeightAvailable: Bool {
        currentQuestion.allowsManualWeight && (servingSizeG ?? 0) > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text(dishName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                ProgressView(value: progress)
                    .tint(.orange)
                    .animation(.easeInOut, value: progress)
                Text("Question \(currentIndex + 1) of \(questions.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // Question
                    Text(currentQuestion.question)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 24)

                    if manualEntryActive {
                        manualWeightEntry
                            .padding(.horizontal)
                            .padding(.bottom, 32)
                    } else {
                        // Options
                        VStack(spacing: 10) {
                            ForEach(currentQuestion.options) { option in
                                OptionButton(
                                    option: option,
                                    isSelected: responses[currentQuestion.id] == option.value
                                ) {
                                    responses[currentQuestion.id] = option.value
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                        advance()
                                    }
                                }
                            }

                            if manualWeightAvailable {
                                Button {
                                    withAnimation { activateManualEntry() }
                                } label: {
                                    Label("Enter exact weight instead?", systemImage: "scalemass")
                                        .font(.callout)
                                        .foregroundColor(.orange)
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                    }
                }
            }

            Divider()

            // Navigation row
            HStack {
                if currentIndex > 0 {
                    Button {
                        withAnimation { currentIndex -= 1 }
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(.callout)
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                if !currentQuestion.required {
                    Button("Skip") {
                        advance()
                    }
                    .font(.callout)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .navigationTitle("About Your Food")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { syncManualState() }
        .onChange(of: currentIndex) { _, _ in syncManualState() }
        .alert("Large portion", isPresented: $showLargePortionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Confirm") { saveManualWeight() }
        } message: {
            Text("That's more than 5x the standard serving (\(standardServingText)). Log it anyway?")
        }
    }

    // MARK: - Manual weight entry

    private var manualWeightEntry: some View {
        VStack(spacing: 14) {
            HStack {
                TextField("Weight", text: $weightInput)
                    .keyboardType(.decimalPad)
                    .font(.title3)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(belowMinimum ? Color.red : Color.orange, lineWidth: 1.5)
                    )
                Text(unitLabel)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            if belowMinimum {
                Text("Minimum is 5g\(usesImperial ? " (about 0.2 oz)" : "")")
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let ssg = servingSizeG, ssg > 0 {
                Text("Standard serving: \(standardServingText)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                commitManualWeight()
            } label: {
                Text("Use This Weight")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(enteredGrams != nil && !belowMinimum ? Color.orange : Color(.systemGray4))
                    .cornerRadius(12)
            }
            .disabled(enteredGrams == nil || belowMinimum)

            Button {
                withAnimation { deactivateManualEntry() }
            } label: {
                Text("Choose a portion size instead")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var standardServingText: String {
        guard let ssg = servingSizeG, ssg > 0 else { return "" }
        if usesImperial {
            return String(format: "%.1f oz (%.0fg)", ssg / ozToGrams, ssg)
        }
        return String(format: "%.0fg", ssg)
    }

    private func activateManualEntry() {
        // A previously selected bucket no longer applies
        responses.removeValue(forKey: currentQuestion.id)
        weightInput = ""
        manualEntryActive = true
    }

    private func deactivateManualEntry() {
        if let resp = responses[currentQuestion.id],
           resp.hasPrefix(QuestionEngine.manualWeightPrefix) {
            responses.removeValue(forKey: currentQuestion.id)
        }
        weightInput = ""
        manualEntryActive = false
    }

    private func commitManualWeight() {
        guard let grams = enteredGrams, grams >= 5 else { return }
        if let ssg = servingSizeG, ssg > 0, grams > ssg * 5 {
            showLargePortionAlert = true
            return
        }
        saveManualWeight()
    }

    private func saveManualWeight() {
        guard let grams = enteredGrams else { return }
        responses[currentQuestion.id] = "\(QuestionEngine.manualWeightPrefix)\(grams)"
        advance()
    }

    /// Restore manual-entry state when landing on a question (e.g. via Back)
    private func syncManualState() {
        let prefix = QuestionEngine.manualWeightPrefix
        if let resp = responses[currentQuestion.id],
           resp.hasPrefix(prefix),
           let grams = Double(resp.dropFirst(prefix.count)) {
            manualEntryActive = true
            let display = usesImperial ? grams / ozToGrams : grams
            weightInput = display == display.rounded()
                ? String(format: "%.0f", display)
                : String(format: "%.1f", display)
        } else {
            manualEntryActive = false
            weightInput = ""
        }
    }

    private func advance() {
        withAnimation {
            if currentIndex + 1 < questions.count {
                currentIndex += 1
            } else {
                onComplete()
            }
        }
    }
}

// MARK: - Option Button

private struct OptionButton: View {
    let option: QAOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.label)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    if !option.hint.isEmpty {
                        Text(option.hint)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.orange : Color(.systemGray4), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 13, height: 13)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.orange.opacity(0.10) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
