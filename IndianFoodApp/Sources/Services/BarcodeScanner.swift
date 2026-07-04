import AVFoundation
import SwiftUI

// MARK: - Barcode Scanner View (UIViewControllerRepresentable)

struct BarcodeScannerView: UIViewControllerRepresentable {
    let onScan:   (String) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController,
                                context: Context) {}

    class Coordinator: NSObject, ScannerViewControllerDelegate {
        let onScan:   (String) -> Void
        let onCancel: () -> Void

        init(onScan: @escaping (String) -> Void,
             onCancel: @escaping () -> Void) {
            self.onScan   = onScan
            self.onCancel = onCancel
        }

        func didFind(barcode: String) { onScan(barcode) }
        func didCancel()              { onCancel() }
    }
}

// MARK: - Scanner View Controller

protocol ScannerViewControllerDelegate: AnyObject {
    func didFind(barcode: String)
    func didCancel()
}

class ScannerViewController: UIViewController,
                             AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: ScannerViewControllerDelegate?
    private var captureSession: AVCaptureSession?
    private var previewLayer:   AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupSession()
        setupOverlay()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.global(qos: .background).async {
            self.captureSession?.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }

    // MARK: - Setup

    private func setupSession() {
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video),
              let input  = try? AVCaptureDeviceInput(device: device) else {
            showNoCameraAlert()
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [
            .ean8, .ean13, .upce, .code128, .code39, .qr,
        ]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame        = view.layer.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)

        self.captureSession = session
        self.previewLayer   = preview
    }

    private func setupOverlay() {
        // Cancel button
        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle("Cancel", for: .normal)
        cancelBtn.setTitleColor(.white, for: .normal)
        cancelBtn.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        cancelBtn.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelBtn)

        // Orange scan frame
        let frameView = UIView()
        frameView.layer.borderColor  = UIColor.orange.cgColor
        frameView.layer.borderWidth  = 2
        frameView.layer.cornerRadius = 12
        frameView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(frameView)

        // Corner accent lines inside the frame
        addCornerLines(to: frameView)

        // Instruction label
        let label = UILabel()
        label.text          = "Point camera at barcode"
        label.textColor     = .white
        label.textAlignment = .center
        label.font          = .systemFont(ofSize: 15, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            cancelBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            cancelBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            frameView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            frameView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            frameView.widthAnchor.constraint(equalToConstant: 260),
            frameView.heightAnchor.constraint(equalToConstant: 160),

            label.topAnchor.constraint(equalTo: frameView.bottomAnchor, constant: 20),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    private func addCornerLines(to view: UIView) {
        let len: CGFloat  = 20
        let thick: CGFloat = 3
        let color = UIColor.orange
        let corners: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = [
            (0, 0, len, thick), (0, 0, thick, len),                     // top-left
            (260-len, 0, len, thick), (260-thick, 0, thick, len),       // top-right
            (0, 160-thick, len, thick), (0, 160-len, thick, len),       // bottom-left
            (260-len, 160-thick, len, thick), (260-thick, 160-len, thick, len), // bottom-right
        ]
        for c in corners {
            let l = UIView(frame: CGRect(x: c.x, y: c.y, width: c.w, height: c.h))
            l.backgroundColor = color
            view.addSubview(l)
        }
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        delegate?.didCancel()
    }

    private func showNoCameraAlert() {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "No Camera",
                message: "Camera not available on this device.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                self.delegate?.didCancel()
            })
            self.present(alert, animated: true)
        }
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !hasScanned,
              let obj     = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let barcode = obj.stringValue else { return }
        hasScanned = true
        captureSession?.stopRunning()
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        delegate?.didFind(barcode: barcode)
    }
}
