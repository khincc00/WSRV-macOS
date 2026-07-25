//
//  LoginAboutViews.swift
//  Webcam Setting Ruang Visual (macOS)
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.system(size: 28))
                .foregroundStyle(.tint)
            Text("Login Lisensi")
                .font(.title3.bold())
            Text("Masukkan password lisensi untuk membuka Master Lock.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
                .onSubmit { Task { await auth.login(password: password) } }

            if let err = auth.errorMessage {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(width: 260)
            }

            HStack {
                Button("Batal") { dismiss() }
                Button {
                    Task { await auth.login(password: password) }
                } label: {
                    if auth.isBusy { ProgressView().controlSize(.small) }
                    else { Text("Login") }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(auth.isBusy)
            }
        }
        .padding(28)
        .frame(width: 340)
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 34))
                .foregroundStyle(.tint)
            Text("Manual Webcam Stable v.1")
                .font(.title3.bold())
            Text("Version 1.0 (macOS)")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text("Professional Webcam Preset Manager")
                .font(.system(size: 12))

            Link("@khinccofficial",
                 destination: URL(string: "https://www.tiktok.com/@khinccofficial")!)
                .font(.system(size: 12, weight: .semibold))

            Divider().frame(width: 200)

            Text("Port macOS: SwiftUI + AVFoundation + IOKit UVC.\nPerubahan tersimpan di hardware webcam,\njadi terbawa ke OBS, Zoom, dan aplikasi lain.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button("Tutup") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(28)
        .frame(width: 340)
    }
}
