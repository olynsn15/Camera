//
//  CameraViewModel.swift
//  Camera
//

import AVFoundation
import SwiftUI
import Photos
import Combine

enum AspectRatio: String, CaseIterable {
    case ratio16x9 = "16 : 9"
    case ratio4x3 = "4 : 3"
}

enum ZoomLevel: CGFloat, CaseIterable {
    case ultraWide = 0.5
    case normal = 1.0
    case tele = 2.0

    var label: String {
        switch self {
        case .ultraWide: return "0.5"
        case .normal: return "1x"
        case .tele: return "2"
        }
    }
}

enum FlashMode {
    case off, on, auto
    var avFlashMode: AVCaptureDevice.FlashMode {
        switch self {
        case .off: return .off
        case .on: return .on
        case .auto: return .auto
        }
    }
    var icon: String {
        switch self {
        case .off: return "bolt.slash.fill"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.automatic.fill"
        }
    }
}

enum GridOverlay: CaseIterable {
    case none, ruleOfThird, symmetry
    var label: String {
        switch self {
        case .none: return "Grid Off"
        case .ruleOfThird: return "Rule of Third"
        case .symmetry: return "Symmetry"
        }
    }
    var icon: String {
        switch self {
        case .none: return "grid"
        case .ruleOfThird: return "grid"
        case .symmetry: return "rectangle.split.2x2"
        }
    }
}

@MainActor
class CameraViewModel: NSObject, ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var flashMode: FlashMode = .off
    @Published var aspectRatio: AspectRatio = .ratio16x9
    @Published var zoomLevel: ZoomLevel = .normal
    @Published var gridOverlay: GridOverlay = .ruleOfThird
    @Published var isCapturing = false
    @Published var showPreview = false
    @Published var permissionGranted = false
    @Published var hasUltraWide = false
    @Published var hasTele = false
    @Published var capturedOrientation: UIDeviceOrientation = .portrait

    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?
    private var captureCompletion: ((UIImage?) -> Void)?

    // Actual zoom factors mapped from virtualDeviceSwitchOverVideoZoomFactors
    // switchFactors[0] = boundary between ultra-wide → wide (= "1x" factor)
    // switchFactors[1] = boundary between wide → tele
    private var wideAngleFactor: CGFloat = 1.0   // factor that gives true 1x (wide)
    private var ultraWideFactor: CGFloat = 1.0   // factor that gives 0.5x (ultra wide)
    private var teleFactor: CGFloat = 2.0        // factor that gives 2x (tele)

    override init() {
        super.init()
        checkPermission()
    }

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted { self?.setupSession() }
                }
            }
        default:
            permissionGranted = false
        }
    }

    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        // Prefer virtual multi-lens devices so we get switchover info
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera
        ]
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .back
        )
        guard let device = discovery.devices.first else {
            session.commitConfiguration()
            return
        }
        currentDevice = device

        // ── Compute correct zoom factors ──────────────────────────────
        // virtualDeviceSwitchOverVideoZoomFactors tells us where lens
        // transitions happen in terms of videoZoomFactor.
        //
        // Example — iPhone 14 Pro (triple):
        //   constituentDevices = [ultra-wide, wide, tele]
        //   switchOverFactors   = [2.0, 6.0]
        //   → factor 1.0 = ultra-wide (raw), 2.0 = wide ("1x"), 6.0 = tele
        //
        // Example — iPhone 13 (dual wide):
        //   constituentDevices = [ultra-wide, wide]
        //   switchOverFactors   = [2.0]
        //   → factor 1.0 = ultra-wide, 2.0 = wide
        //
        // Example — single wide angle only:
        //   switchOverFactors   = []
        //   → factor 1.0 = wide, no ultra-wide
        //
        let switchFactors = device.virtualDeviceSwitchOverVideoZoomFactors
            .map { CGFloat(truncating: $0) }

        if switchFactors.isEmpty {
            // Single lens device — only wide angle available
            wideAngleFactor = 1.0
            ultraWideFactor = 1.0   // same, no ultra-wide
            teleFactor = min(2.0, device.maxAvailableVideoZoomFactor)
            hasUltraWide = false
            hasTele = device.maxAvailableVideoZoomFactor >= 2.0
        } else if switchFactors.count == 1 {
            // Dual wide (ultra-wide + wide), no optical tele
            // "2x" = 2× from wide angle = wideAngleFactor * 2 (digital zoom)
            wideAngleFactor = switchFactors[0]          // e.g. 2.0
            ultraWideFactor = device.minAvailableVideoZoomFactor  // e.g. 1.0
            teleFactor = min(wideAngleFactor * 2, device.maxAvailableVideoZoomFactor) // 4.0
            hasUltraWide = true
            hasTele = device.maxAvailableVideoZoomFactor >= wideAngleFactor * 2
        } else {
            // Triple (ultra-wide + wide + tele)
            wideAngleFactor = switchFactors[0]          // e.g. 2.0
            ultraWideFactor = device.minAvailableVideoZoomFactor  // e.g. 1.0
            teleFactor = switchFactors[1]               // e.g. 6.0 → but we cap at 2x optical
            // Use the tele switchover factor directly — this is the true 2x point
            hasUltraWide = true
            hasTele = true
        }

        print("📷 Device: \(device.localizedName)")
        print("   switchFactors: \(switchFactors)")
        print("   ultraWideFactor: \(ultraWideFactor), wideAngleFactor: \(wideAngleFactor), teleFactor: \(teleFactor)")
        // ─────────────────────────────────────────────────────────────

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }

            photoOutput = AVCapturePhotoOutput()
            photoOutput.isHighResolutionCaptureEnabled = true
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }

            // Start at wide angle (true 1x)
            try device.lockForConfiguration()
            device.videoZoomFactor = wideAngleFactor
            device.unlockForConfiguration()
        } catch {
            print("Camera setup error: \(error)")
        }

        session.commitConfiguration()

        Task.detached { [weak self] in
            self?.session.startRunning()
        }
    }

    func capturePhoto() {
        guard !isCapturing else { return }
        isCapturing = true

        // ✅ ambil orientation saat shutter
        let deviceOrientation = UIDevice.current.orientation
        capturedOrientation = deviceOrientation.isValidInterfaceOrientation
            ? deviceOrientation
            : .portrait

        let settings = AVCapturePhotoSettings()

        // ✅ apply ke camera output
        if let connection = photoOutput.connection(with: .video) {
            connection.videoOrientation = currentVideoOrientation()
        }

        settings.flashMode = flashMode.avFlashMode

        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            let hevc = AVCapturePhotoSettings(format: [
                AVVideoCodecKey: AVVideoCodecType.hevc
            ])
            hevc.flashMode = flashMode.avFlashMode
            photoOutput.capturePhoto(with: hevc, delegate: self)
        } else {
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }


    func setZoom(_ level: ZoomLevel) {
        guard let device = currentDevice else { return }
        do {
            try device.lockForConfiguration()

            let factor: CGFloat
            switch level {
            case .ultraWide:
                factor = ultraWideFactor  // true ultra-wide (e.g. 1.0 on triple cam)
            case .normal:
                factor = wideAngleFactor  // true 1x wide angle (e.g. 2.0 on triple cam)
            case .tele:
                factor = teleFactor       // true 2x tele (e.g. 6.0 on triple cam)
            }

            let clamped = max(device.minAvailableVideoZoomFactor,
                              min(factor, device.maxAvailableVideoZoomFactor))
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
            zoomLevel = level
        } catch {
            print("Zoom error: \(error)")
        }
    }

    func cycleFlash() {
        switch flashMode {
        case .off: flashMode = .on
        case .on: flashMode = .auto
        case .auto: flashMode = .off
        }
    }

    func cycleGrid() {
        let all = GridOverlay.allCases
        let idx = all.firstIndex(of: gridOverlay) ?? 0
        gridOverlay = all[(idx + 1) % all.count]
    }

    func cycleAspectRatio() {
        aspectRatio = aspectRatio == .ratio16x9 ? .ratio4x3 : .ratio16x9
    }

    func savePhoto(_ image: UIImage) {
        // Force re-render to flatten any deferred drawing before saving
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let flattened = renderer.image { _ in
            image.draw(at: .zero)
        }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: flattened)
            }
        }
    }

    // Crops a UIImage to the target aspect ratio, center-cropped
    func cropped(_ image: UIImage, to ratio: AspectRatio) -> UIImage {
        // Use UIGraphicsImageRenderer so orientation is already baked in.
        // image.size respects imageOrientation — portrait photo will have size.height > size.width.
        let imgW = image.size.width
        let imgH = image.size.height

        // Target width:height ratio (portrait)
        // 16:9 portrait → 9/16 ≈ 0.5625
        // 4:3  portrait → 3/4  = 0.75
        let targetRatio: CGFloat = ratio == .ratio16x9 ? 9.0 / 16.0 : 3.0 / 4.0
        let imageRatio = imgW / imgH

        let cropW: CGFloat
        let cropH: CGFloat
        if imageRatio > targetRatio {
            // Image is wider than target → crop left/right
            cropH = imgH
            cropW = imgH * targetRatio
        } else {
            // Image is taller than target → crop top/bottom
            cropW = imgW
            cropH = imgW / targetRatio
        }

        let x = (imgW - cropW) / 2
        let y = (imgH - cropH) / 2
        let cropRect = CGRect(x: x, y: y, width: cropW, height: cropH)

        // Render into a new context — this flattens orientation into pixels
        let renderer = UIGraphicsImageRenderer(size: cropRect.size)
        let result = renderer.image { _ in
            image.draw(at: CGPoint(x: -cropRect.origin.x, y: -cropRect.origin.y))
        }
        return result
    }
    
    private func currentVideoOrientation() -> AVCaptureVideoOrientation {
        switch UIDevice.current.orientation {
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft
        case .portraitUpsideDown: return .portraitUpsideDown
        default: return .portrait
        }
    }
}

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                  didFinishProcessingPhoto photo: AVCapturePhoto,
                                  error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let rawImage = UIImage(data: data) else {
            Task { @MainActor in self.isCapturing = false }
            return
        }
        Task { @MainActor in
            self.capturedImage = rawImage
            self.isCapturing = false
            self.showPreview = true
        }
    }
}
