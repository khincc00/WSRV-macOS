//
//  WebcamSettingStableV1App.swift
//  Webcam Setting Ruang Visual (macOS)
//

import SwiftUI

@main
struct WebcamSettingStableV1App: App {
    @StateObject private var camera = CameraManager()
    @StateObject private var presets = PresetManager()
    @StateObject private var auth = AuthManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(camera)
                .environmentObject(presets)
                .environmentObject(auth)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
