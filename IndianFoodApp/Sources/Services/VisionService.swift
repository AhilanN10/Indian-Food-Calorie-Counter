import CoreML
import Vision
import UIKit

class VisionService: ObservableObject {
    private var visionModel: VNCoreMLModel?
    private var classMap: ClassMap?
    private let confidenceThreshold: Float = 0.35

    init() {
        loadModel()
        loadClassMap()
    }

    private func loadModel() {
        guard let modelURL = Bundle.main.url(
            forResource: "IndianFoodClassifier",
            withExtension: "mlmodelc"
        ) else {
            print("VisionService: model not found in bundle")
            return
        }
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndNeuralEngine
            let mlModel = try MLModel(contentsOf: modelURL, configuration: config)
            visionModel = try VNCoreMLModel(for: mlModel)
            print("VisionService: model loaded successfully")
        } catch {
            print("VisionService: model load error: \(error)")
        }
    }

    private func loadClassMap() {
        guard let url = Bundle.main.url(forResource: "class_map", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("VisionService: class_map.json not found")
            return
        }
        classMap = try? JSONDecoder().decode(ClassMap.self, from: data)
        print("VisionService: class map loaded — \(classMap?.numClasses ?? 0) classes")
    }

    func classify(image: UIImage, completion: @escaping (ClassificationResult?) -> Void) {
        guard let visionModel = visionModel,
              let cgImage = image.cgImage else {
            print("VisionService: no model or cgImage")
            completion(nil)
            return
        }

        let request = VNCoreMLRequest(model: visionModel) { request, error in
            if let error = error {
                print("VisionService: request error: \(error)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            guard let results = request.results as? [VNClassificationObservation],
                  !results.isEmpty else {
                print("VisionService: no results")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let logits = results.map { Double($0.confidence) }
            let maxLogit = logits.max() ?? 0
            let expScores = logits.map { exp($0 - maxLogit) }
            let sumExp = expScores.reduce(0, +)
            let probabilities = expScores.map { Float($0 / sumExp) }

            let scored = zip(results, probabilities)
                .map { ($0.identifier, $1) }
                .sorted { $0.1 > $1.1 }

            let topClass = scored[0].0
            let topConf = scored[0].1
            let topCandidates = Array(scored.prefix(3))

            print("VisionService: classified as \(topClass) (\(String(format: "%.3f", topConf)))")

            let result = ClassificationResult(
                className: topClass,
                confidence: topConf,
                topCandidates: topCandidates
            )
            DispatchQueue.main.async { completion(result) }
        }

        request.imageCropAndScaleOption = .centerCrop

        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("VisionService: handler error: \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    func foodCode(for className: String) -> String? {
        return classMap?.classes[className]?.indbFoodCode
    }

    func needsConfirmation(for result: ClassificationResult) -> Bool {
        return result.confidence < confidenceThreshold
    }
}
