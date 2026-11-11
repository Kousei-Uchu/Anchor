import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import AVFoundation

/// The recovery key as a QR code, to move it to a second device without typing it (Patch SY3, E1, D40).
///
/// The typed key stays the default and always works. The code is made in memory from the key text while the
/// "Your recovery key" sheet is open, which is the only time the key exists on this phone in a readable form, and it
/// is never written to a file, the photo library, the pasteboard or the log. The camera is used only to read a code,
/// only after a tap on Scan a QR code, and nothing it sees is kept. `scripts/check-recovery-qr.mjs` keeps all of
/// that true: the camera and the code maker are used in this file and nowhere else.
enum RecoveryKeyQR {
    /// Written in front of the key so a scan can tell an Anchor code from any other.
    static let prefix = "anchor-recovery-key:"

    /// What goes inside the code, or nil when the text is not a whole recovery key.
    static func payload(for keyText: String) -> String? {
        guard RecoveryKeyText.raw(from: keyText) != nil else { return nil }
        return prefix + keyText
    }

    /// The key text out of what a scan read, or nil when it is not an Anchor recovery key. A bare key is accepted too.
    static func key(fromScanned scanned: String) -> String? {
        var text = scanned.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.lowercased().hasPrefix(prefix) {
            text = String(text.dropFirst(prefix.count))
        }
        guard RecoveryKeyText.raw(from: text) != nil else { return nil }
        return text
    }

    /// True when this device has a camera. Asking does not show a permission question.
    static var cameraAvailable: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }

    /// The code as an image in memory, black on clear, whole pixels so it stays sharp when shown larger. Nil when the
    /// text is not a whole recovery key.
    static func image(for keyText: String, side: CGFloat = 240) -> UIImage? {
        guard let payload = payload(for: keyText), let data = payload.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let width = max(output.extent.width, 1)
        let scale = max(1, (side / width).rounded(.down))
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// Reads the code back to the text it was made from. Used by the launch self-test in test builds.
    static func roundTrips(_ keyText: String) -> Bool {
        guard let payload = payload(for: keyText) else { return false }
        return key(fromScanned: payload).map { RecoveryKeyText.canonical($0) == RecoveryKeyText.canonical(keyText) } ?? false
    }
}

/// What the scanner found.
enum RecoveryKeyScanResult {
    case found(String)
    case denied
    case noCamera
}

/// The camera view. It looks for QR codes only, hands back the first Anchor recovery key it sees and stops. A code
/// that is not an Anchor recovery key is ignored and its contents are never shown or kept.
final class RecoveryKeyScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onResult: ((RecoveryKeyScanResult) -> Void)?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "page.aspens.anchor.recoverykeyscan")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let hint = UILabel()
    private var finished = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        hint.text = "Point the camera at the QR code on your other device."
        hint.textColor = .white
        hint.font = UIFont.preferredFont(forTextStyle: .subheadline)
        hint.adjustsFontForContentSizeCategory = true
        hint.numberOfLines = 0
        hint.textAlignment = .center
        hint.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hint)
        NSLayoutConstraint.activate([
            hint.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor, constant: 8),
            hint.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor, constant: -8),
            hint.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])
        Task { @MainActor in
            await self.start()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }

    private func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted {
                finish(.denied)
                return
            }
        default:
            finish(.denied)
            return
        }
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            finish(.noCamera)
            return
        }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            finish(.noCamera)
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr]
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
        let running = session
        sessionQueue.async {
            running.startRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !finished else { return }
        var sawOther = false
        for object in metadataObjects {
            guard let code = object as? AVMetadataMachineReadableCodeObject,
                  let value = code.stringValue else { continue }
            if let key = RecoveryKeyQR.key(fromScanned: value) {
                finish(.found(key))
                return
            }
            sawOther = true
        }
        if sawOther {
            hint.text = "That code is not an Anchor recovery key. Keep looking for the right one."
        }
    }

    private func stopSession() {
        let running = session
        sessionQueue.async {
            if running.isRunning {
                running.stopRunning()
            }
        }
    }

    private func finish(_ result: RecoveryKeyScanResult) {
        guard !finished else { return }
        finished = true
        stopSession()
        onResult?(result)
    }
}

struct RecoveryKeyScannerView: UIViewControllerRepresentable {
    let onResult: (RecoveryKeyScanResult) -> Void

    func makeUIViewController(context: Context) -> RecoveryKeyScannerController {
        let controller = RecoveryKeyScannerController()
        controller.onResult = onResult
        return controller
    }

    func updateUIViewController(_ uiViewController: RecoveryKeyScannerController, context: Context) {}
}

/// The sheet around the camera. Gives the key text back to the caller and closes, or says why it cannot scan.
struct RecoveryKeyScanSheet: View {
    let onKey: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var problem: String?
    @State private var offerSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if let problem {
                    VStack(spacing: 16) {
                        Text(problem)
                            .font(.system(.body, design: .rounded))
                            .multilineTextAlignment(.center)
                        if offerSettings {
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    RecoveryKeyScannerView { result in
                        switch result {
                        case .found(let key):
                            onKey(key)
                            dismiss()
                        case .denied:
                            problem = "Anchor does not have permission to use the camera. You can allow it in the phone's Settings, or type the recovery key instead."
                            offerSettings = true
                        case .noCamera:
                            problem = "This device cannot scan a code. Type the recovery key instead."
                            offerSettings = false
                        }
                    }
                    .ignoresSafeArea()
                }
            }
            .navigationTitle("Scan the QR code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
