import SwiftUI

// MARK: - App State

enum AppState {
    case home
    case classifying
    case confirming(ClassificationResult)          // low-confidence → show top picks
    case searching(ClassificationResult?)          // manual search / unknown dish
    case questioning(DishMatch, ClassificationResult)
    case calculating
    case results(String, MacroResult)
    case error(String)
}

// MARK: - ViewModel

@MainActor
class AppViewModel: ObservableObject {
    @Published var state: AppState = .home
    @Published var capturedImage: UIImage?
    @Published var showCamera       = false
    @Published var showPhotoLibrary = false
    @Published var questionResponses: [String: String] = [:]
    @Published var questions: [QAQuestion] = []
    @Published var backendOnline = false

    let visionService  = VisionService()
    let apiService     = APIService()
    let questionEngine = QuestionEngine()

    init() {
        Task { backendOnline = await apiService.healthCheck() }
    }

    // MARK: - Image handling

    func handleCapturedImage(_ image: UIImage) {
        capturedImage = image
        state = .classifying
        classifyImage(image)
    }

    func classifyImage(_ image: UIImage) {
        visionService.classify(image: image) { [weak self] result in
            guard let self else { return }
            guard let result else {
                self.state = .error("Could not classify the image.\nPlease try again with a clearer photo.")
                return
            }
            Task { await self.handleClassificationResult(result) }
        }
    }

    func handleClassificationResult(_ result: ClassificationResult) async {
        // Low confidence → ask user to confirm
        if visionService.needsConfirmation(for: result) {
            state = .confirming(result)
            return
        }
        await resolveAndProceed(className: result.className, result: result)
    }

    func confirmClass(_ className: String, result: ClassificationResult) async {
        await resolveAndProceed(className: className, result: result)
    }

    private func resolveAndProceed(className: String,
                                   result: ClassificationResult) async {
        if className == "unknown" {
            state = .searching(result)
            return
        }
        guard let foodCode = visionService.foodCode(for: className),
              let dish     = try? await apiService.getDish(foodCode: foodCode) else {
            let readable = className.replacingOccurrences(of: "_", with: " ")
            if let dish = try? await apiService.searchDish(query: readable) {
                proceed(with: dish, result: result)
            } else {
                state = .error("'\(readable.capitalized)' not found in the database.")
            }
            return
        }
        proceed(with: dish, result: result)
    }

    private func proceed(with dish: DishMatch, result: ClassificationResult) {
        questions        = questionEngine.generateQuestions(for: dish, classificationResult: result)
        questionResponses = [:]
        state = .questioning(dish, result)
    }

    // MARK: - Calculation

    func submitAnswers(dish: DishMatch) {
        state = .calculating
        let answers = questionEngine.buildQAAnswers(from: questionResponses, questions: questions)
        Task {
            guard let macroResult = try? await apiService.calculateMacros(
                foodCode: dish.foodCode, qaAnswers: answers
            ) else {
                state = .error("Could not calculate macros.\nIs the backend running?")
                return
            }
            state = .results(dish.foodName, macroResult)
        }
    }

    // MARK: - Search

    func openSearch(from classResult: ClassificationResult? = nil) {
        state = .searching(classResult)
    }

    func handleSearchSelection(_ searchResult: SearchResult,
                               classResult: ClassificationResult?) async {
        guard let dish = try? await apiService.getDish(foodCode: searchResult.foodCode) else {
            state = .error("Could not load '\(searchResult.foodName)'")
            return
        }
        let syntheticResult = classResult ?? ClassificationResult(
            className:      searchResult.foodCode,
            confidence:     1.0,
            topCandidates:  [(searchResult.foodCode, 1.0)]
        )
        proceed(with: dish, result: syntheticResult)
    }

    // MARK: - Reset

    func reset() {
        state             = .home
        capturedImage     = nil
        questionResponses = [:]
        questions         = []
        Task { backendOnline = await apiService.healthCheck() }
    }
}

// MARK: - ContentView

struct ContentView: View {
    @StateObject var vm = AppViewModel()

    var body: some View {
        NavigationStack {
            Group {
                switch vm.state {
                case .home:
                    HomeView(vm: vm)

                case .classifying:
                    ClassifyingView(image: vm.capturedImage)

                case .confirming(let result):
                    ConfirmDishView(result: result) { className in
                        Task { await vm.confirmClass(className, result: result) }
                    } onCancel: {
                        vm.reset()
                    }

                case .searching(let classResult):
                    SearchView(
                        onSelect: { result in
                            Task { await vm.handleSearchSelection(result, classResult: classResult) }
                        },
                        onCancel: { vm.reset() }
                    )

                case .questioning(let dish, let classResult):
                    QuestionView(
                        questions: vm.questions,
                        dishName: dish.foodName,
                        responses: $vm.questionResponses
                    ) {
                        vm.submitAnswers(dish: dish)
                    }

                case .calculating:
                    CalculatingView()

                case .results(let name, let result):
                    ResultsView(dishName: name, result: result) { vm.reset() }

                case .error(let msg):
                    ErrorView(message: msg) { vm.reset() }
                }
            }
        }
        // Camera sheet
        .sheet(isPresented: $vm.showCamera, onDismiss: {
            if let img = vm.capturedImage { vm.handleCapturedImage(img) }
        }) {
            CameraView(image: $vm.capturedImage, isPresented: $vm.showCamera, sourceType: .camera)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $vm.showPhotoLibrary, onDismiss: {
            if let img = vm.capturedImage { vm.handleCapturedImage(img) }
        }) {
            CameraView(image: $vm.capturedImage, isPresented: $vm.showPhotoLibrary, sourceType: .photoLibrary)
                .ignoresSafeArea()
        }
    }
}

// MARK: - HomeView

struct HomeView: View {
    @ObservedObject var vm: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo + headline
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 120, height: 120)
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.orange)
                }

                VStack(spacing: 6) {
                    Text("CalorieScan")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Scan any Indian dish to get\ncalories and macros instantly")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            // Backend status indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(vm.backendOnline ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(vm.backendOnline ? "Backend connected" : "Backend offline")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 8)

            // CTA buttons
            VStack(spacing: 12) {
                Button {
                    vm.capturedImage = nil
                    vm.showCamera    = true
                } label: {
                    Label("Take a Photo", systemImage: "camera.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(14)
                }

                Button {
                    vm.capturedImage    = nil
                    vm.showPhotoLibrary = true
                } label: {
                    Label("Choose from Library", systemImage: "photo.fill")
                        .font(.headline)
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(14)
                }

                Button {
                    vm.openSearch()
                } label: {
                    Label("Search Dishes", systemImage: "magnifyingglass")
                        .font(.headline)
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(14)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .navigationTitle("CalorieScan")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - ClassifyingView

struct ClassifyingView: View {
    let image: UIImage?

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 260, height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(radius: 8)
            }
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.4)
                Text("Identifying your dish…")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .navigationTitle("Scanning")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - CalculatingView

struct CalculatingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.4)
            Text("Calculating macros…")
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .navigationTitle("Calculating")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - ConfirmDishView

struct ConfirmDishView: View {
    let result: ClassificationResult
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Which dish is this?")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 32)

            Text("We're not 100% sure. Please confirm:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                ForEach(result.topCandidates, id: \.0) { name, score in
                    Button {
                        onConfirm(name)
                    } label: {
                        HStack {
                            Text(name.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(Int(score * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            Button {
                onConfirm("unknown")
            } label: {
                Text("None of these — let me type it")
                    .font(.callout)
                    .foregroundColor(.orange)
            }
            .padding(.top, 4)

            Button("Cancel", action: onCancel)
                .font(.callout)
                .foregroundColor(.secondary)
                .padding(.top, 4)

            Spacer()
        }
        .navigationTitle("Confirm Dish")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - ErrorView

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try Again", action: onRetry)
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            Spacer()
        }
        .navigationTitle("Error")
        .navigationBarTitleDisplayMode(.inline)
    }
}
