//
//  AuthManager.swift
//  Webcam Setting Ruang Visual (macOS)
//
//  Login password -> endpoint yang sama dengan versi Windows:
//  https://webcam-auth.dailylife-ami.workers.dev/
//
//  Catatan: sesuaikan `makeRequest` kalau format request worker kamu berbeda
//  (versi Windows mengirim record { password = ... }; di sini dikirim sebagai
//  JSON {"password": "..."} — ubah di satu tempat ini saja bila perlu).
//

import Foundation

@MainActor
final class AuthManager: ObservableObject {

    static let endpoint = URL(string: "https://webcam-auth.dailylife-ami.workers.dev/")!

    @Published var isAuthenticated: Bool = UserDefaults.standard.bool(forKey: "wsrv.auth.ok")
    @Published var isBusy = false
    @Published var errorMessage: String?

    private func makeRequest(password: String) -> URLRequest {
        var req = URLRequest(url: Self.endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["password": password])
        req.timeoutInterval = 15
        return req
    }

    func login(password: String) async {
        errorMessage = nil
        let trimmed = password.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Password kamu kosong! wajib diisi Cuy 😅"
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            let (data, response) = try await URLSession.shared.data(for: makeRequest(password: trimmed))
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8)?.lowercased() ?? ""
            let ok = (200..<300).contains(status)
                && !body.contains("invalid") && !body.contains("salah") && !body.contains("false")
            if ok {
                isAuthenticated = true
                UserDefaults.standard.set(true, forKey: "wsrv.auth.ok")
            } else {
                errorMessage = "Password salah atau lisensi belum aktif."
            }
        } catch {
            errorMessage = "Gagal terhubung ke server lisensi: \(error.localizedDescription)"
        }
    }

    func logout() {
        isAuthenticated = false
        UserDefaults.standard.set(false, forKey: "wsrv.auth.ok")
    }
}
