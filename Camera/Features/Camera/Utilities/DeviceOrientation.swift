//
//  DeviceOrientation.swift
//  Camera
//
//  Created by Carolyn Santana on 03/05/26.
//


import SwiftUI
import Combine

final class DeviceOrientation: ObservableObject {
    @Published var angle: Double = 0

    private var cancellable: AnyCancellable?

    init() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()

        cancellable = NotificationCenter.default.publisher(
            for: UIDevice.orientationDidChangeNotification
        )
        .sink { _ in
            self.updateOrientation()
        }

        updateOrientation()
    }

    private func updateOrientation() {
        switch UIDevice.current.orientation {
        case .landscapeLeft:
            angle = 90
        case .landscapeRight:
            angle = -90
        case .portraitUpsideDown:
            angle = 180
        default:
            angle = 0
        }
    }
}