import SwiftUI

struct QuestionView: View {
    let questions: [QAQuestion]
    let dishName: String
    @Binding var responses: [String: String]
    let onComplete: () -> Void

    @State private var currentIndex = 0

    var currentQuestion: QAQuestion { questions[currentIndex] }
    var progress: Double { Double(currentIndex + 1) / Double(questions.count) }

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
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
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
