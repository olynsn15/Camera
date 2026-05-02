//
//  CameraView.swift
//  Camera
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject private var vm = CameraViewModel()
    @State private var showingFullPreview = false
    @State private var shutterAnimation = false
    @State private var gridLabelVisible = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── TOP BAR ──────────────────────────────────────────
                topBar

                // ── VIEWFINDER ────────────────────────────────────────
                viewfinder

                // ── BOTTOM BAR ────────────────────────────────────────
                bottomBar
            }

            // Flash overlay on capture
            if shutterAnimation {
                Color.white
                    .ignoresSafeArea()
                    .opacity(shutterAnimation ? 0.6 : 0)
                    .animation(.easeOut(duration: 0.15), value: shutterAnimation)
            }

            // Full screen photo preview
            if showingFullPreview, let img = vm.capturedImage {
                PhotoPreviewView(image: img, isPresented: $showingFullPreview) {
                    vm.savePhoto(img)
                }
                .zIndex(10)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.2), value: showingFullPreview)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Flash button
            Button {
                vm.cycleFlash()
            } label: {
                Image(systemName: vm.flashMode.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(vm.flashMode == .off ? .white : .yellow)
                    .frame(width: 48, height: 40)
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Spacer()

            // Aspect Ratio button
            Button {
                vm.cycleAspectRatio()
            } label: {
                Text(vm.aspectRatio.rawValue)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black)
    }

    // MARK: - Viewfinder

    private var viewfinder: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = viewfinderHeight(for: width)

            ZStack {
                // Camera preview
                CameraPreviewView(session: vm.session, aspectRatio: vm.aspectRatio)
                    .frame(width: width, height: height)
                    .clipped()

                // Grid overlay
                OverlayGridView(overlay: vm.gridOverlay, aspectRatio: vm.aspectRatio)
                    .frame(width: width, height: height)
                    .allowsHitTesting(false)

                // Grid mode label (appears briefly after cycling)
                if gridLabelVisible && vm.gridOverlay != .none {
                    VStack {
                        Text(vm.gridOverlay.label.uppercased())
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Capsule())
                            .padding(.top, 16)
                        Spacer()
                    }
                }
            }
            .frame(width: width, height: height)
            .background(Color.black)
        }
        .aspectRatio(viewfinderAspectRatio, contentMode: .fit)
    }

    private var viewfinderAspectRatio: CGFloat {
        switch vm.aspectRatio {
        case .ratio16x9: return 9.0 / 16.0
        case .ratio4x3: return 3.0 / 4.0
        }
    }

    private func viewfinderHeight(for width: CGFloat) -> CGFloat {
        switch vm.aspectRatio {
        case .ratio16x9: return width * 16 / 9
        case .ratio4x3: return width * 4 / 3
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            // Zoom selector
            zoomSelector
                .padding(.top, 20)
                .padding(.bottom, 24)

            // Main controls: thumbnail | shutter | grid
            HStack(alignment: .center) {
                // Thumbnail / last photo
                thumbnailButton

                Spacer()

                // Shutter
                shutterButton

                Spacer()

                // Grid toggle
                gridButton
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
        .background(Color.black)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Zoom Selector

    private var zoomSelector: some View {
        HStack(spacing: 6) {
            ForEach(ZoomLevel.allCases, id: \.rawValue) { level in
                let isActive = vm.zoomLevel == level
                let isAvailable: Bool = {
                    switch level {
                    case .ultraWide: return vm.hasUltraWide
                    case .normal: return true
                    case .tele: return vm.hasTele
                    }
                }()

                Button {
                    vm.setZoom(level)
                } label: {
                    Text(level.label)
                        .font(.system(
                            size: isActive ? 16 : 14,
                            weight: isActive ? .bold : .regular,
                            design: .rounded
                        ))
                        .foregroundColor(
                            isActive ? .black : (isAvailable ? .white : .white.opacity(0.3))
                        )
                        .frame(
                            width: isActive ? 44 : 36,
                            height: isActive ? 44 : 36
                        )
                        .background(
                            isActive
                                ? Color.yellow
                                : Color.white.opacity(isAvailable ? 0.18 : 0.08)
                        )
                        .clipShape(Circle())
                }
                .disabled(!isAvailable)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: vm.zoomLevel)
            }
        }
    }

    // MARK: - Thumbnail Button

    private var thumbnailButton: some View {
        Button {
            if vm.capturedImage != nil {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    showingFullPreview = true
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 60, height: 60)

                if let img = vm.capturedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(Color.white, lineWidth: 2)
                        )
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .disabled(vm.capturedImage == nil)
    }

    // MARK: - Shutter Button

    private var shutterButton: some View {
        Button {
            triggerShutter()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 76, height: 76)
                    .shadow(color: .white.opacity(0.3), radius: 8)

                Circle()
                    .stroke(Color.white.opacity(0.4), lineWidth: 3)
                    .frame(width: 88, height: 88)
            }
            .scaleEffect(vm.isCapturing ? 0.92 : 1.0)
            .animation(.spring(response: 0.15, dampingFraction: 0.5), value: vm.isCapturing)
        }
        .disabled(vm.isCapturing)
    }

    // MARK: - Grid Button

    private var gridButton: some View {
        Button {
            vm.cycleGrid()
            withAnimation {
                gridLabelVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    gridLabelVisible = false
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 60, height: 60)

                // Custom grid icon based on current mode
                gridIcon
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
            }
        }
    }

    @ViewBuilder
    private var gridIcon: some View {
        switch vm.gridOverlay {
        case .none:
            Image(systemName: "grid")
                .font(.system(size: 22, weight: .regular))
                .opacity(0.4)
        case .ruleOfThird:
            Image(systemName: "grid")
                .font(.system(size: 22, weight: .medium))
        case .symmetry:
            Image(systemName: "rectangle.split.2x2")
                .font(.system(size: 22, weight: .medium))
        }
    }

    // MARK: - Actions

    private func triggerShutter() {
        // Flash white overlay
        withAnimation(.easeOut(duration: 0.1)) {
            shutterAnimation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeIn(duration: 0.15)) {
                shutterAnimation = false
            }
        }
        vm.capturePhoto()
    }
}

// MARK: - Preview

#Preview {
    CameraView()
}
