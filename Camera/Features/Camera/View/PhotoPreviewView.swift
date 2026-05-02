//
//  PhotoPreviewView.swift
//  Camera
//
//  Created by Carolyn Santana on 02/05/26.
//


import SwiftUI

struct PhotoPreviewView: View {
    let image: UIImage
    @Binding var isPresented: Bool
    let onSave: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showSavedBadge = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Photo
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale = min(max(scale * delta, 1), 5)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                if scale < 1 {
                                    withAnimation(.spring()) { scale = 1 }
                                }
                            },
                        DragGesture()
                            .onChanged { value in
                                if scale > 1 {
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                            }
                            .onEnded { _ in
                                lastOffset = offset
                                if scale <= 1 {
                                    withAnimation(.spring()) { offset = .zero }
                                }
                            }
                    )
                )
                .ignoresSafeArea()

            // Top bar
            VStack {
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isPresented = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }

                    Spacer()

                    // Share button
                    Button {
                        sharePhoto()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // Bottom bar
                HStack(spacing: 40) {
                    // Retake
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isPresented = false
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 22, weight: .medium))
                            Text("Retake")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(width: 80, height: 64)
                        .background(Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    // Save
                    Button {
                        onSave()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            showSavedBadge = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                showSavedBadge = false
                                isPresented = false
                            }
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: showSavedBadge ? "checkmark.circle.fill" : "square.and.arrow.down")
                                .font(.system(size: 22, weight: .medium))
                            Text(showSavedBadge ? "Saved!" : "Save")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(showSavedBadge ? .black : .white)
                        .frame(width: 80, height: 64)
                        .background(showSavedBadge ? Color.green : Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .animation(.spring(response: 0.3), value: showSavedBadge)
                    }
                }
                .padding(.bottom, 48)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private func sharePhoto() {
        let av = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }
}