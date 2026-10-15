//
//  CameraManager.swift
//  Webcam Setting Ruang Visual (macOS)
//
//  Discovery webcam (AVFoundation) + preview session + jembatan ke UVCController.
//  Pola sessionQueue: semua operasi session & UVC di background queue,
//  publish state ke main thread.
//

import Foundation
import AVFoundation
import Combine

struct ControlState: Identifiable {
    let id: UVCControlID
    var range: UVCRange
    var value: Int
    var supported: Bool
}

/// Preset nuansa warna cepat — diterapkan lewat white balance (temperatur) + hue.
enum ColorTone: String, CaseIterable, Identifiable {
    case red = "Red"
    case yellow = "Yellow"
    case blue = "Blue"
    var id: String { rawValue }
}

final class CameraManager: NSObject, ObservableObject {

    static let allWebcamsLabel = "Semua Webcam"

    @Published var devices: [AVCaptureDevice] = []
    @Published var selectedDeviceID: String? {
        didSet { if oldValue != selectedDeviceID { attachSelectedDevice() } }
    }
    @Published var controls: [UVCControlID: ControlState] = [:]
    @Published var isSessionRunning = false
    @Published var statusMessage: String?
    @Published var hardwareControlAvailable = false

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "id.khincc.wsrv.session")
    private var currentInput: AVCaptureDeviceInput?
    private var uvc: UVCController?

    override init() {
        super.init()
        refreshDevices()
    }

    // MARK: - Devices

    func refreshDevices() {
        let types: [AVCaptureDevice.DeviceType]
        if #available(macOS 14.0, *) {
            types = [.external, .builtInWideAngleCamera]
        } else {
            types = [.externalUnknown, .builtInWideAngleCamera]
        }
        let discovered = AVCaptureDevice.DiscoverySession(
            deviceTypes: types, mediaType: .video, position: .unspecified).devices

        DispatchQueue.main.async {
            self.devices = discovered
            if self.selectedDeviceID == nil || !discovered.contains(where: { $0.uniqueID == self.selectedDeviceID }) {
                self.selectedDeviceID = discovered.first?.uniqueID
            } else {
                self.attachSelectedDevice()
            }
        }
    }

    var selectedDevice: AVCaptureDevice? {
        devices.first { $0.uniqueID == selectedDeviceID }
    }

    private func attachSelectedDevice() {
        guard let device = selectedDevice else { return }
        sessionQueue.async { [weak self] in
            guard let self else { return }

            self.session.beginConfiguration()
            if let input = self.currentInput { self.session.removeInput(input) }
            if let input = try? AVCaptureDeviceInput(device: device),
               self.session.canAddInput(input) {
                self.session.addInput(input)
                self.currentInput = input
            }
            // Batasi resolusi preview ke 720p (fallback .medium) supaya buffer frame tidak membengkak.
            // Kontrol UVC tetap bekerja karena dikirim langsung ke hardware, bukan lewat session.
            if self.session.canSetSessionPreset(.hd1280x720) {
                self.session.sessionPreset = .hd1280x720
            } else if self.session.canSetSessionPreset(.medium) {
                self.session.sessionPreset = .medium
            }
            self.session.commitConfiguration()

            self.uvc?.close()
            self.uvc = Self.makeUVC(for: device)
            let hw = self.uvc?.isReady ?? false
            self.reloadControls()

            DispatchQueue.main.async {
                self.hardwareControlAvailable = hw
                self.statusMessage = hw
                    ? nil
                    : "Kontrol hardware UVC tidak tersedia untuk kamera ini (kamera internal / non-UVC)."
            }
        }
    }

    /// Ambil VID/PID (+locationID kalau ada) dari AVCaptureDevice untuk matching IOKit.
    private static func makeUVC(for device: AVCaptureDevice) -> UVCController? {
        // modelID contoh: "UVC Camera VendorID_1133 ProductID_2093"
        var vid: Int?; var pid: Int?
        for token in device.modelID.split(separator: " ") {
            if token.hasPrefix("VendorID_") { vid = Int(token.dropFirst("VendorID_".count)) }
            if token.hasPrefix("ProductID_") { pid = Int(token.dropFirst("ProductID_".count)) }
        }
        // uniqueID untuk USB cam biasanya diawali locationID hex (8 digit)
        var location: UInt32?
        let uid = device.uniqueID
        if uid.count >= 8, let loc = UInt32(uid.prefix(8), radix: 16), loc != 0 {
            location = loc
        }
        guard let vid, let pid else { return nil }
        return UVCController(vendorID: vid, productID: pid, locationID: location)
            ?? UVCController(vendorID: vid, productID: pid, locationID: nil)
    }

    // MARK: - Session

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async { self.isSessionRunning = self.session.isRunning }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async { self.isSessionRunning = false }
        }
    }

    // MARK: - Controls

    func reloadControls() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            var result: [UVCControlID: ControlState] = [:]
            if let uvc = self.uvc, uvc.isReady {
                for id in UVCControlID.allCases {
                    if let range = uvc.range(for: id) {
                        let value = uvc.getValue(id) ?? range.def
                        if Self.isAutoToggle(id) {
                            // AE Mode dkk. berupa bitmap di hardware (mis. min=1 max=8);
                            // untuk UI toggle selalu dinormalisasi jadi 0/1.
                            let defOn = id == .exposureAuto ? (range.def & 0b1110) != 0 : range.def != 0
                            result[id] = ControlState(id: id,
                                                      range: UVCRange(min: 0, max: 1, step: 1, def: defOn ? 1 : 0),
                                                      value: value != 0 ? 1 : 0, supported: true)
                        } else {
                            result[id] = ControlState(id: id, range: range, value: value, supported: true)
                        }
                    } else if let value = uvc.getValue(id) {
                        // boolean controls (auto flags) kadang tidak punya GET_MIN
                        result[id] = ControlState(id: id,
                                                  range: UVCRange(min: 0, max: 1, step: 1, def: 0),
                                                  value: value, supported: true)
                    }
                }
            }
            DispatchQueue.main.async { self.controls = result }
        }
    }

    /// Toggle auto (nilai 0/1) tidak boleh di-clamp ke range bitmap hardware.
    private static func isAutoToggle(_ id: UVCControlID) -> Bool {
        id == .exposureAuto || id == .focusAuto || id == .whiteBalanceAuto || id == .lowLight
    }

    /// Kontrol manual yang nilainya berubah di hardware saat mode auto di-toggle.
    private static func manualPair(of id: UVCControlID) -> UVCControlID? {
        switch id {
        case .exposureAuto: return .exposure
        case .focusAuto: return .focus
        case .whiteBalanceAuto: return .whiteBalance
        default: return nil
        }
    }

    /// Set nilai dengan clamping aman ke range hardware (MacVis safe-clamp pattern).
    func setControl(_ id: UVCControlID, to raw: Int) {
        sessionQueue.async { [weak self] in
            guard let self, let uvc = self.uvc else { return }
            var value = raw
            if Self.isAutoToggle(id) {
                value = raw != 0 ? 1 : 0
            } else if let st = self.controls[id] {
                value = min(max(raw, st.range.min), st.range.max)
                if st.range.step > 1 {
                    value = st.range.min + ((value - st.range.min) / st.range.step) * st.range.step
                }
            }
            let ok = uvc.setValue(id, value)

            // Konfirmasi state auto dari hardware + re-read nilai manual pasangannya,
            // karena kamera bisa mengubah nilai manual saat keluar/masuk mode auto.
            var confirmed = value
            var pairValue: (UVCControlID, Int)?
            if ok, Self.isAutoToggle(id) {
                confirmed = uvc.getValue(id) ?? value
                if let pair = Self.manualPair(of: id), let cur = uvc.getValue(pair) {
                    pairValue = (pair, cur)
                }
            }
            DispatchQueue.main.async {
                if ok {
                    self.controls[id]?.value = confirmed
                    if let (pair, cur) = pairValue { self.controls[pair]?.value = cur }
                } else {
                    self.statusMessage = "Gagal set \(id.rawValue) (\(value)) — kamera menolak request."
                }
            }
        }
    }

    /// Terapkan nuansa warna: Red/Yellow lewat temperatur white balance rendah (warm),
    /// Blue lewat temperatur tinggi (cool); Red diberi dorongan hue tambahan.
    func applyColorTone(_ tone: ColorTone) {
        if controls[.whiteBalanceAuto]?.supported == true {
            setControl(.whiteBalanceAuto, to: 0) // wajib manual agar nilai WB dipakai kamera
        }
        if let wb = controls[.whiteBalance], wb.supported {
            let span = wb.range.max - wb.range.min
            switch tone {
            case .red:    setControl(.whiteBalance, to: wb.range.min)
            case .yellow: setControl(.whiteBalance, to: wb.range.min + span / 4)
            case .blue:   setControl(.whiteBalance, to: wb.range.max)
            }
        }
        if let hue = controls[.hue], hue.supported {
            let shift = max((hue.range.max - hue.range.def) / 4, hue.range.step)
            setControl(.hue, to: tone == .red ? min(hue.range.def + shift, hue.range.max) : hue.range.def)
        }
    }

    /// Reset semua kontrol ke default hardware.
    func resetAllToDefault() {
        let snapshot = controls
        for (id, st) in snapshot where st.supported {
            setControl(id, to: st.range.def)
        }
        // refresh nilai sesudahnya
        sessionQueue.async { [weak self] in self?.reloadControls() }
    }

    // MARK: - Preset apply / capture

    func captureCurrentValues() -> [String: Int] {
        var out: [String: Int] = [:]
        for (id, st) in controls where st.supported { out[id.rawValue] = st.value }
        return out
    }

    func apply(values: [String: Int]) {
        var missing: [String] = []
        for (key, value) in values {
            guard let id = UVCControlID(rawValue: key) else { continue }
            if controls[id]?.supported == true {
                // urutan penting: auto dulu dimatikan sebelum nilai manual
                if id == .exposureAuto || id == .focusAuto || id == .whiteBalanceAuto {
                    setControl(id, to: value)
                }
            } else {
                missing.append(key)
            }
        }
        // pass kedua: nilai manual
        for (key, value) in values {
            guard let id = UVCControlID(rawValue: key),
                  id != .exposureAuto, id != .focusAuto, id != .whiteBalanceAuto,
                  controls[id]?.supported == true else { continue }
            setControl(id, to: value)
        }
        if !missing.isEmpty {
            DispatchQueue.main.async {
                self.statusMessage = "Sebagian kontrol tidak didukung kamera ini: \(missing.joined(separator: ", "))"
            }
        }
    }
}
