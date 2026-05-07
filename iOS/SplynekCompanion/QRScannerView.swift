// Copyright © 2026 Splynek. MIT.
//
// QRScannerView — UIViewControllerRepresentable wrapper around an
// AVCaptureSession + AVCaptureMetadataOutput for scanning the
// `splynek://pair?...` QR code that the Mac generates in
// Settings → Sharing.
//
// On a successful scan that decodes via `SplynekPairURL.decode(...)`,
// the view stops the capture session, beeps, and calls `onPaired`
// with the decoded fields.  PairingSheet pre-fills its form from
// those fields.
//
// Sandboxing: the host app's Info.plist needs NSCameraUsageDescription
// (already added in the host Info.plist).  We never persist the
// scanned image; the AVCaptureSession runs only while the view is
// on screen.

#if canImport(SwiftUI) && canImport(AVFoundation) && canImport(UIKit)
import SwiftUI
import AVFoundation
import UIKit
import AudioToolbox

struct QRScannerView: UIViewControllerRepresentable {
    var onPaired: (SplynekPairURL.Components) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> QRScannerController {
        let vc = QRScannerController()
        vc.onPaired = onPaired
        vc.onCancel = onCancel
        return vc
    }

    func updateUIViewController(_ uiViewController: QRScannerController, context: Context) {}
}

final class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onPaired: ((SplynekPairURL.Components) -> Void)?
    var onCancel: (() -> Void)?

    private let session = AVCaptureSession()
    private var preview: AVCaptureVideoPreviewLayer?
    private var didEmit = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
        configurePreview()
        configureChrome()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else {
            // No back camera or permission denied — surface
            // gracefully via cancel; PairingSheet's manual flow
            // remains available.
            DispatchQueue.main.async { [weak self] in self?.onCancel?() }
            return
        }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            DispatchQueue.main.async { [weak self] in self?.onCancel?() }
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
    }

    private func configurePreview() {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        self.preview = layer
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    private func configureChrome() {
        // A subtle reticle so the user knows where to aim.  Apple's
        // own Wallet uses a similar dimmed-corners design.
        let reticle = UIView(frame: .zero)
        reticle.layer.borderColor = UIColor.white.cgColor
        reticle.layer.borderWidth = 2
        reticle.layer.cornerRadius = 12
        reticle.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(reticle)
        NSLayoutConstraint.activate([
            reticle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            reticle.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            reticle.widthAnchor.constraint(equalToConstant: 220),
            reticle.heightAnchor.constraint(equalToConstant: 220),
        ])

        let label = UILabel()
        label.text = "Point at the QR in Splynek → Settings → Web dashboard"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .white
        label.font = .preferredFont(forTextStyle: .footnote)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            label.topAnchor.constraint(equalTo: reticle.bottomAnchor, constant: 16),
        ])

        let cancel = UIButton(type: .system)
        cancel.setTitle("Cancel", for: .normal)
        cancel.tintColor = .white
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancel)
        NSLayoutConstraint.activate([
            cancel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            cancel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    @objc private func cancelTapped() { onCancel?() }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !didEmit else { return }
        guard let raw = metadataObjects
                .compactMap({ ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue })
                .first
        else { return }
        guard let comps = SplynekPairURL.decode(from: raw) else {
            // Wrong-shape QR — keep scanning rather than emitting.
            return
        }
        didEmit = true
        // Standard Wallet-style success beep.
        AudioServicesPlaySystemSound(SystemSoundID(1004))
        session.stopRunning()
        onPaired?(comps)
    }
}
#endif
