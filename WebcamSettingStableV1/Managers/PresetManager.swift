//
//  PresetManager.swift
//  Webcam Setting Ruang Visual (macOS)
//
//  Preset .json: Save / Update / Load / Delete / Lock — sama seperti versi Windows.
//  Lokasi: ~/Library/Application Support/WebcamSettingRuangVisual/Presets/
//

import Foundation

struct WebcamPreset: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var cameraModel: String          // "Semua Webcam" atau model spesifik
    var locked: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var values: [String: Int]        // UVCControlID.rawValue -> nilai
}

enum PresetError: LocalizedError {
    case emptyName, duplicate, locked, notFound

    var errorDescription: String? {
        switch self {
        case .emptyName: return "Isi nama preset baru dulu ya 😊"
        case .duplicate: return "Preset dengan nama ini sudah ada."
        case .locked:    return "Preset ini TERKUNCI. Buka Master Lock dulu untuk mengubah/menghapus."
        case .notFound:  return "Pilih preset dulu dari daftar."
        }
    }
}

final class PresetManager: ObservableObject {

    @Published private(set) var presets: [WebcamPreset] = []
    @Published var masterUnlocked = false

    private let folder: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        folder = appSupport.appendingPathComponent("WebcamSettingRuangVisual/Presets", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        loadAll()
    }

    private func url(for preset: WebcamPreset) -> URL {
        folder.appendingPathComponent("\(preset.id.uuidString).json")
    }

    func loadAll() {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        presets = files
            .filter { $0.pathExtension.lowercased() == "json" }
            .compactMap { try? decoder.decode(WebcamPreset.self, from: Data(contentsOf: $0)) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func write(_ preset: WebcamPreset) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(preset).write(to: url(for: preset), options: .atomic)
    }

    // MARK: CRUD

    @discardableResult
    func save(name: String, cameraModel: String, values: [String: Int], locked: Bool = false) throws -> WebcamPreset {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PresetError.emptyName }
        guard !presets.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            throw PresetError.duplicate
        }
        let preset = WebcamPreset(name: trimmed, cameraModel: cameraModel, locked: locked, values: values)
        try write(preset)
        loadAll()
        return preset
    }

    func update(_ preset: WebcamPreset, values: [String: Int]) throws {
        guard !preset.locked || masterUnlocked else { throw PresetError.locked }
        var p = preset
        p.values = values
        p.updatedAt = Date()
        try write(p)
        loadAll()
    }

    func toggleLock(_ preset: WebcamPreset) throws {
        guard masterUnlocked || !preset.locked else { throw PresetError.locked }
        var p = preset
        p.locked.toggle()
        p.updatedAt = Date()
        try write(p)
        loadAll()
    }

    func delete(_ preset: WebcamPreset) throws {
        guard !preset.locked || masterUnlocked else { throw PresetError.locked }
        try FileManager.default.removeItem(at: url(for: preset))
        loadAll()
    }

    // MARK: Import / Export (.json — kompatibel tukar file antar user)

    func export(_ preset: WebcamPreset, to destination: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(preset).write(to: destination, options: .atomic)
    }

    func importPreset(from source: URL) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var preset = try decoder.decode(WebcamPreset.self, from: Data(contentsOf: source))
        preset.id = UUID() // hindari bentrok id
        if presets.contains(where: { $0.name.caseInsensitiveCompare(preset.name) == .orderedSame }) {
            preset.name += " (import)"
        }
        try write(preset)
        loadAll()
    }
}
