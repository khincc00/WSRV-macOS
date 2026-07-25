//
//  Components.swift
//  Webcam Setting Ruang Visual (macOS)
//

import SwiftUI
import AVFoundation

// MARK: - Preview (AVCaptureVideoPreviewLayer)

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspect
        layer.backgroundColor = NSColor.black.cgColor
        view.layer = layer
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView.layer as? AVCaptureVideoPreviewLayer)?.session = session
    }
}

// MARK: - Slider satu baris (label + slider + nilai + tombol default)

struct ControlSliderRow: View {
    let title: String
    let state: ControlState?
    var disabled: Bool = false
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 110, alignment: .leading)
                .foregroundStyle(available && !disabled ? .primary : .tertiary)

            if let st = state, available {
                Slider(
                    value: Binding(
                        get: { Double(st.value) },
                        set: { onChange(Int($0.rounded())) }
                    ),
                    in: Double(st.range.min)...Double(max(st.range.max, st.range.min + 1))
                )
                .disabled(disabled)

                Text("\(st.value)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .frame(width: 52, alignment: .trailing)
                    .foregroundStyle(disabled ? .tertiary : .secondary)

                Button {
                    onChange(st.range.def)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .help("Kembalikan ke default (\(st.range.def))")
                .disabled(disabled)
            } else {
                Text("Tidak didukung kamera ini")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
    }

    private var available: Bool { state?.supported == true }
}

// MARK: - Panel section

struct PanelBox<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary))
    }
}
