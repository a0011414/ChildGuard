//
//  QRCodeScannerView.swift
//  ChildGuard
//
//  QRコードをスキャンして URL を取得する。親・子モードの「Cloud Functions の URL」入力で使用。
//  URL を QR で表示するビューも含む。
//

import SwiftUI
import AVFoundation
import CoreImage.CIFilterBuiltins

/// 家族コード（8桁）を QR で表示するシート。子の端末でスキャンするか数字を入力する。
struct FamilyCodeQRSheetView: View {
    let familyCode: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if !familyCode.isEmpty, let image = qrImage(for: familyCode) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 260, maxHeight: 260)
                    Text("家族コード: \(familyCode)")
                        .font(.title2.monospacedDigit())
                } else {
                    Text("家族コードがありません")
                        .foregroundStyle(.secondary)
                }
                Text("子の端末でこのQRをスキャンするか、上記8桁の数字を入力してください")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .navigationTitle("家族コード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func qrImage(for s: String) -> UIImage? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return nil }
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: .init(scaleX: 8, y: 8))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// 文字列を QR コード画像として表示する（親が子に URL を渡すときなど）
struct QRCodeDisplayView: View {
    let urlString: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let image = qrImage {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 260, maxHeight: 260)
                } else {
                    Text("URL が空です")
                        .foregroundStyle(.secondary)
                }
                Text("子の端末で「QRで読み取る」をタップしてこのコードをスキャンしてください")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .navigationTitle("QRコード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private var qrImage: UIImage? {
        let s = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, let data = s.data(using: .utf8) else { return nil }
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: .init(scaleX: 8, y: 8))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

struct QRCodeScannerView: View {
    @Binding var scannedURL: String
    /// true のときは URL に限定せず、スキャンした文字列をそのまま渡す（家族コード用）
    var acceptAnyString: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        QRCodeScannerRepresentable(acceptAnyString: acceptAnyString, onScan: { urlString in
            scannedURL = urlString
            dismiss()
        })
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            Text(acceptAnyString ? "家族コードの QR を読み取ってください" : "Cloud Functions の URL が含まれる QR コードを読み取ってください")
                .font(.caption)
                .foregroundStyle(.white)
                .padding(12)
                .background(.black.opacity(0.6))
                .padding(.top, 8)
        }
    }
}

private struct QRCodeScannerRepresentable: UIViewControllerRepresentable {
    var acceptAnyString: Bool = false
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.acceptAnyString = acceptAnyString
        vc.onScan = onScan
        return vc
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {
        uiViewController.acceptAnyString = acceptAnyString
    }
}

private final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var acceptAnyString: Bool = false
    var onScan: ((String) -> Void)?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        startCapture()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }

    private func startCapture() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        let session = AVCaptureSession()
        let output = AVCaptureMetadataOutput()
        guard session.canAddInput(input), session.canAddOutput(output) else { return }
        session.addInput(input)
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        captureSession = session

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.frame = view.bounds
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        previewLayer = layer

        DispatchQueue.global(qos: .userInitiated).async { [weak session] in
            session?.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              obj.type == .qr,
              let str = obj.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !str.isEmpty else { return }
        captureSession?.stopRunning()
        if acceptAnyString {
            onScan?(str)
            return
        }
        guard let url = URL(string: str), url.scheme == "https" else { return }
        var base = str
        if let host = url.host {
            base = "https://\(host)"
            if let port = url.port, port != 443 { base += ":\(port)" }
        }
        if base.hasSuffix("/") { base = String(base.dropLast()) }
        onScan?(base)
    }
}
