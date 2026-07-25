//
//  ContentView.swift
//  Webcam Setting Ruang Visual (macOS)
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var camera: CameraManager
    @EnvironmentObject var presets: PresetManager
    @EnvironmentObject var auth: AuthManager

    @State private var presetName = ""
    @State private var selectedPresetID: UUID?
    @State private var showPreview = true
    @State private var dirty = false
    @State private var alertMessage: String?
    @State private var confirmDelete: WebcamPreset?
    @State private var showLogin = false
    @State private var showAbout = false

    var body: some View {
        HSplitView {
            leftColumn
                .frame(minWidth: 420, idealWidth: 460)
            rightColumn
                .frame(minWidth: 360)
        }
        .frame(minWidth: 860, minHeight: 640)
        .onAppear {
            requestCameraAccessThenStart()
        }
        .alert("Informasi", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: { Text(alertMessage ?? "") }
        .confirmationDialog("Konfirmasi Hapus Preset", isPresented: Binding(
            get: { confirmDelete != nil },
            set: { if !$0 { confirmDelete = nil } })
        ) {
            Button("Hapus", role: .destructive) {
                if let p = confirmDelete { doDelete(p) }
            }
            Button("Batal", role: .cancel) { confirmDelete = nil }
        } message: {
            Text("Yakin mau menghapus preset: \(confirmDelete?.name ?? "")?\nPreset tidak akan bisa dikembalikan.")
        }
        .sheet(isPresented: $showLogin) { LoginView() }
        .sheet(isPresented: $showAbout) { AboutView() }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    if auth.isAuthenticated {
                        presets.masterUnlocked.toggle()
                    } else {
                        showLogin = true
                    }
                } label: {
                    Label(presets.masterUnlocked ? "Master Unlock" : "Master Lock",
                          systemImage: presets.masterUnlocked ? "lock.open.fill" : "lock.fill")
                }
                .help("Buka kunci preset yang TERKUNCI (butuh login)")

                Button { showAbout = true } label: {
                    Label("Info", systemImage: "info.circle")
                }
            }
        }
        .onChange(of: auth.isAuthenticated) { ok in
            if ok { presets.masterUnlocked = true; showLogin = false }
        }
    }

    // MARK: kolom kiri — preview + sumber webcam

    private var leftColumn: some View {
        VStack(spacing: 12) {
            PanelBox(title: "Webcam Source") {
                HStack {
                    Picker("", selection: Binding(
                        get: { camera.selectedDeviceID ?? "" },
                        set: { camera.selectedDeviceID = $0.isEmpty ? nil : $0 })
                    ) {
                        ForEach(camera.devices, id: \.uniqueID) { dev in
                            Text(dev.localizedName).tag(dev.uniqueID)
                        }
                    }
                    .labelsHidden()

                    Button {
                        camera.refreshDevices()
                    } label: { Image(systemName: "arrow.clockwise") }
                    .help("Refresh daftar webcam")

                    Toggle("Preview", isOn: $showPreview)
                        .toggleStyle(.switch)
                }
            }

            if showPreview {
                CameraPreviewView(session: camera.session)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary))
                    .frame(minHeight: 260)
            }

            if let msg = camera.statusMessage {
                Label(msg, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            presetPanel
            Spacer(minLength: 0)
        }
        .padding(12)
    }

    // MARK: kolom kanan — Color & Lens

    private var rightColumn: some View {
        ScrollView {
            VStack(spacing: 12) {
                colorPanel
                lensPanel
                HStack {
                    Button {
                        camera.resetAllToDefault()
                        dirty = true
                    } label: {
                        Label("Reset Semua ke Default", systemImage: "arrow.counterclockwise.circle")
                    }
                    Spacer()
                }
            }
            .padding(12)
        }
    }

    private var colorPanel: some View {
        PanelBox(title: "Color") {
            slider("Brightness", .brightness)
            slider("Contrast", .contrast)
            slider("Hue", .hue)
            slider("Saturation", .saturation)
            slider("Sharpness", .sharpness)
            slider("Gamma", .gamma)
            slider("Backlight Comp", .backlightComp)
            slider("ISO/Gain", .gain)

            Divider()

            autoToggle("White Balance Auto", .whiteBalanceAuto)
            slider("White Balance", .whiteBalance,
                   disabled: (camera.controls[.whiteBalanceAuto]?.value ?? 0) != 0)

            HStack {
                Text("PowerLine")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 110, alignment: .leading)
                Picker("", selection: Binding(
                    get: { camera.controls[.powerLine]?.value ?? 1 },
                    set: { camera.setControl(.powerLine, to: $0); dirty = true })
                ) {
                    Text("Disabled").tag(0)
                    Text("50 Hz").tag(1)
                    Text("60 Hz").tag(2)
                }
                .labelsHidden()
                .frame(width: 120)
                .disabled(camera.controls[.powerLine]?.supported != true)
                Spacer()
            }

            Divider()

            HStack(spacing: 8) {
                Text("Color Tone")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 110, alignment: .leading)
                ForEach(ColorTone.allCases) { tone in
                    Button {
                        camera.applyColorTone(tone)
                        dirty = true
                    } label: {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(toneColor(tone))
                                .frame(width: 9, height: 9)
                            Text(tone.rawValue)
                        }
                    }
                }
                Spacer()
            }
            .controlSize(.small)
            .disabled(camera.controls[.whiteBalance]?.supported != true
                      && camera.controls[.hue]?.supported != true)
        }
    }

    private func toneColor(_ tone: ColorTone) -> Color {
        switch tone {
        case .red: return .red
        case .yellow: return .yellow
        case .blue: return .blue
        }
    }

    private var lensPanel: some View {
        PanelBox(title: "Lens") {
            autoToggle("Auto Exposure", .exposureAuto)
            slider("Exposure", .exposure,
                   disabled: (camera.controls[.exposureAuto]?.value ?? 0) != 0)
            autoToggle("Low Light Comp", .lowLight)

            Divider()

            autoToggle("Auto Focus", .focusAuto)
            slider("Focus", .focus,
                   disabled: (camera.controls[.focusAuto]?.value ?? 0) != 0)

            Divider()

            slider("Zoom", .zoom)
            Text("Zoom works for 4K webcams")
                .font(.system(size: 10)).foregroundStyle(.tertiary)
            slider("Pan", .pan)
            slider("Tilt", .tilt)
            Text("Tilt, Pan for PTZ Webcam.")
                .font(.system(size: 10)).foregroundStyle(.tertiary)
        }
    }

    private func slider(_ title: String, _ id: UVCControlID, disabled: Bool = false) -> some View {
        ControlSliderRow(title: title, state: camera.controls[id], disabled: disabled) { newValue in
            camera.setControl(id, to: newValue)
            dirty = true
        }
    }

    private func autoToggle(_ title: String, _ id: UVCControlID) -> some View {
        HStack {
            Toggle(title, isOn: Binding(
                get: { (camera.controls[id]?.value ?? 0) != 0 },
                set: { camera.setControl(id, to: $0 ? 1 : 0); dirty = true })
            )
            .toggleStyle(.checkbox)
            .disabled(camera.controls[id]?.supported != true)
            Spacer()
        }
    }

    // MARK: Preset panel

    private var presetPanel: some View {
        PanelBox(title: "Presets — Professional Webcam Preset Manager") {
            HStack {
                TextField("Preset Name", text: $presetName)
                    .textFieldStyle(.roundedBorder)
                Button("Save Preset") { doSave() }
                    .help("Buat menyimpan setelan sekarang jadi preset baru")
            }

            List(selection: $selectedPresetID) {
                ForEach(presets.presets) { p in
                    HStack {
                        Image(systemName: p.locked ? "lock.fill" : "slider.horizontal.3")
                            .foregroundStyle(p.locked ? .orange : .secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.name).font(.system(size: 12, weight: .semibold))
                            Text(p.cameraModel).font(.system(size: 10)).foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    .tag(p.id)
                    .contextMenu {
                        Button(p.locked ? "Buka Kunci" : "Kunci Preset") { doToggleLock(p) }
                        Button("Export .json…") { doExport(p) }
                    }
                }
            }
            .frame(minHeight: 120, maxHeight: 180)

            HStack(spacing: 8) {
                Button("Load Preset") { doLoad() }
                    .help("Buat buka preset yang dipilih ke webcam aktif")
                Button("Update Preset") { doUpdate() }
                    .help("Buat update preset kamu dengan setelan sekarang")
                Button("Delete Preset", role: .destructive) {
                    guard let p = selectedPreset else { alertMessage = PresetError.notFound.errorDescription; return }
                    if p.locked && !presets.masterUnlocked { alertMessage = PresetError.locked.errorDescription; return }
                    confirmDelete = p
                }
                Spacer()
                Button("Import…") { doImport() }
            }
            .controlSize(.small)

            if dirty {
                Label("Masih ada perubahan yang BELUM disimpan nih. Kalau belum disimpan, perubahan akan hilang.",
                      systemImage: "exclamationmark.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            }
        }
    }

    private var selectedPreset: WebcamPreset? {
        presets.presets.first { $0.id == selectedPresetID }
    }

    // MARK: actions

    private func requestCameraAccessThenStart() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted { camera.startSession() }
                else { alertMessage = "Izin kamera ditolak. Aktifkan di System Settings → Privacy & Security → Camera." }
            }
        }
    }

    private func doSave() {
        do {
            let model = camera.selectedDevice?.localizedName ?? CameraManager.allWebcamsLabel
            let p = try presets.save(name: presetName,
                                     cameraModel: model,
                                     values: camera.captureCurrentValues())
            selectedPresetID = p.id
            presetName = ""
            dirty = false
            alertMessage = "Preset '\(p.name)' berhasil disimpan ✅"
        } catch { alertMessage = error.localizedDescription }
    }

    private func doUpdate() {
        guard let p = selectedPreset else { alertMessage = PresetError.notFound.errorDescription; return }
        do {
            try presets.update(p, values: camera.captureCurrentValues())
            dirty = false
            alertMessage = "Preset berhasil di-update ✅"
        } catch { alertMessage = error.localizedDescription }
    }

    private func doLoad() {
        guard let p = selectedPreset else { alertMessage = PresetError.notFound.errorDescription; return }
        camera.apply(values: p.values)
        dirty = false
    }

    private func doDelete(_ p: WebcamPreset) {
        do { try presets.delete(p); selectedPresetID = nil }
        catch { alertMessage = error.localizedDescription }
        confirmDelete = nil
    }

    private func doToggleLock(_ p: WebcamPreset) {
        if p.locked && !auth.isAuthenticated { showLogin = true; return }
        do { try presets.toggleLock(p) }
        catch { alertMessage = error.localizedDescription }
    }

    private func doExport(_ p: WebcamPreset) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(p.name).json"
        if panel.runModal() == .OK, let url = panel.url {
            do { try presets.export(p, to: url) }
            catch { alertMessage = error.localizedDescription }
        }
    }

    private func doImport() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do { try presets.importPreset(from: url) }
            catch { alertMessage = "File preset tidak valid: \(error.localizedDescription)" }
        }
    }
}
