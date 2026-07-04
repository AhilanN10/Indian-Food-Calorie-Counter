import SwiftUI
import SwiftData

// MARK: - App State (scanning flow only)

enum AppState {
    case idle
    case classifying
    case confirming(ClassificationResult)
    case searching(ClassificationResult?)
    case questioning(DishMatch, ClassificationResult)
    case calculating
    case results(String, String, MacroResult)  // dishName, foodCode, result
    case scanningBarcode
    case barcodeResult(BarcodeResult)
    case barcodeNotFound(String)
    case error(String)
}

extension AppState {
    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }
}

// MARK: - ViewModel

@MainActor
class AppViewModel: ObservableObject {
    @Published var state: AppState = .idle
    @Published var capturedImage: UIImage?
    @Published var showCamera       = false
    @Published var showPhotoLibrary = false
    @Published var questionResponses: [String: String] = [:]
    @Published var questions: [QAQuestion] = []
    @Published var backendOnline = false
    @Published var selectedTab: Int = 0

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
        if visionService.needsConfirmation(for: result) {
            state = .confirming(result)
            return
        }
        await resolveAndProceed(className: result.className, result: result)
    }

    func confirmClass(_ className: String, result: ClassificationResult) async {
        await resolveAndProceed(className: className, result: result)
    }

    // MARK: - Barcode

    func openBarcodeScanner() {
        state = .scanningBarcode
    }

    func handleBarcode(_ barcode: String) async {
        state = .classifying   // reuse the scanning spinner
        let result = await OpenFoodFactsService.shared.lookup(barcode: barcode)
        if let result {
            state = .barcodeResult(result)
        } else {
            state = .barcodeNotFound(barcode)
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
            className:     searchResult.foodCode,
            confidence:    1.0,
            topCandidates: [(searchResult.foodCode, 1.0)]
        )
        proceed(with: dish, result: syntheticResult)
    }

    // MARK: - Resolution

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
        questions         = questionEngine.generateQuestions(for: dish, classificationResult: result)
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
            state = .results(dish.foodName, dish.foodCode, macroResult)
        }
    }

    // MARK: - Finish / Reset

    func finishLogging() {
        state       = .idle
        selectedTab = 0   // jump back to dashboard
    }

    func reset() {
        state             = .idle
        capturedImage     = nil
        questionResponses = [:]
        questions         = []
    }
}

// MARK: - Root Tab View

struct ContentView: View {
    @StateObject var vm = AppViewModel()

    var body: some View {
        ZStack {
            TabView(selection: $vm.selectedTab) {
                DashboardView()
                    .tabItem { Label("Dashboard", systemImage: "house.fill") }
                    .tag(0)

                LogView(vm: vm)
                    .tabItem { Label("Log", systemImage: "plus.circle.fill") }
                    .tag(1)

                MealHistoryView()
                    .tabItem { Label("History", systemImage: "calendar") }
                    .tag(2)

                ProfileView()
                    .tabItem { Label("Profile", systemImage: "person.circle") }
                    .tag(3)
            }

            // Scanning flow overlay — covers tabs during an active scan
            if !vm.state.isIdle {
                ScanFlowView(vm: vm)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.state.isIdle)
        // Camera sheet
        .sheet(isPresented: $vm.showCamera, onDismiss: {
            if let img = vm.capturedImage { vm.handleCapturedImage(img) }
        }) {
            CameraView(image: $vm.capturedImage,
                       isPresented: $vm.showCamera,
                       sourceType: .camera)
                .ignoresSafeArea()
        }
        // Photo library sheet
        .sheet(isPresented: $vm.showPhotoLibrary, onDismiss: {
            if let img = vm.capturedImage { vm.handleCapturedImage(img) }
        }) {
            CameraView(image: $vm.capturedImage,
                       isPresented: $vm.showPhotoLibrary,
                       sourceType: .photoLibrary)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Scan Flow Overlay

struct ScanFlowView: View {
    @ObservedObject var vm: AppViewModel

    var body: some View {
        NavigationStack {
            Group {
                switch vm.state {
                case .idle:
                    EmptyView()

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
                        onCancel:      { vm.reset() },
                        onBarcodeScan: { vm.openBarcodeScanner() }
                    )

                case .questioning(let dish, _):
                    QuestionView(
                        questions:    vm.questions,
                        dishName:     dish.foodName,
                        servingSizeG: dish.servingSizeG,
                        responses:    $vm.questionResponses
                    ) {
                        vm.submitAnswers(dish: dish)
                    }

                case .calculating:
                    CalculatingView()

                case .results(let name, let foodCode, let result):
                    ResultsView(
                        dishName: name,
                        foodCode: foodCode,
                        result:   result,
                        onDone:   { vm.finishLogging() }
                    )

                case .scanningBarcode:
                    BarcodeScannerView(
                        onScan:   { barcode in Task { await vm.handleBarcode(barcode) } },
                        onCancel: { vm.reset() }
                    )
                    .ignoresSafeArea()

                case .barcodeResult(let result):
                    BarcodeResultView(result: result) { vm.finishLogging() }

                case .barcodeNotFound(let barcode):
                    ErrorView(
                        message:  "No product found for barcode:\n\(barcode)\n\nTry searching manually.",
                        onRetry:  { vm.reset() }
                    )

                case .error(let msg):
                    ErrorView(message: msg) { vm.reset() }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !vm.state.isIdle {
                        Button("Cancel") { vm.reset() }
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .background(Color(.systemBackground))
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
                ProgressView().scaleEffect(1.4)
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
            ProgressView().scaleEffect(1.4)
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
    let result:    ClassificationResult
    let onConfirm: (String) -> Void
    let onCancel:  () -> Void

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
                    Button { onConfirm(name) } label: {
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

            Button { onConfirm("unknown") } label: {
                Text("None of these — let me search")
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
