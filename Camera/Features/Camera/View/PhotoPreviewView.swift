//
//  PhotoPreviewView.swift
//  Camera
//
//  Created by Carolyn Santana on 02/05/26.
//

//lalalalalalala
import SwiftUI

struct PhotoPreviewView: View {
    let image: UIImage
    let orientation: UIDeviceOrientation
    @Binding var isPresented: Bool
    let onSave: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let isLandscapeRotation = abs(rotationAngle) == 90

            ZStack {
                Color.black

                // 📸 IMAGE
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: isLandscapeRotation ? geo.size.height : geo.size.width,
                        height: isLandscapeRotation ? geo.size.width : geo.size.height
                    )
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
                                    lastScale = 1
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
                                }
                        )
                    )

                // 🔝 UI
                VStack {
                    HStack {
                        Button {
                            isPresented = false
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(.black.opacity(0.5))
                                .clipShape(Circle())
                        }

                        Spacer()

                        Button {
                            sharePhoto()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                    .padding()

                    Spacer()

                    Button("Save") {
                        onSave()
                        isPresented = false
                    }
                    .padding(.bottom, 40)
                }
                .frame(
                    width: isLandscapeRotation ? geo.size.height : geo.size.width,
                    height: isLandscapeRotation ? geo.size.width : geo.size.height
                )
            }
            // 🔥 ROTATE TERAKHIR (ini penting)
            .frame(width: geo.size.width, height: geo.size.height)
            .rotationEffect(.degrees(rotationAngle))
            .animation(.easeInOut(duration: 0.25), value: rotationAngle)
        }
        .ignoresSafeArea()
    }

    private var rotationAngle: Double {
        switch orientation {
        case .landscapeLeft: return 90
        case .landscapeRight: return -90
        case .portraitUpsideDown: return 180
        default: return 0
        }
    }

    private func sharePhoto() {
        let av = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        UIApplication.shared.windows.first?.rootViewController?.present(av, animated: true)
    }
}
