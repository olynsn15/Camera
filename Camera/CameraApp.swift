//
//  CameraApp.swift
//  Camera
//
//  Created by Carolyn Santana on 01/05/26.
//

import SwiftUI

@main
struct CameraAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        CameraView()
    }
}
