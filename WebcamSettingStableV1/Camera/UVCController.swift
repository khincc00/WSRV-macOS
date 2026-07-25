//
//  UVCController.swift
//  Webcam Setting Ruang Visual (macOS)
//
//  Pengganti IAMVideoProcAmp + IAMCameraControl (DirectShow) di macOS.
//  Mengirim UVC class request (GET_CUR/GET_MIN/GET_MAX/SET_CUR) langsung
//  ke Video Control interface webcam via IOKit USB, sehingga perubahan
//  tersimpan di hardware dan terlihat di semua aplikasi (OBS, Zoom, dll).
//
//  Pola: sessionQueue threading + safe range clamping (MacVis pattern).
//

import Foundation
import IOKit
import IOKit.usb
import IOKit.usb.IOUSBLib

// MARK: - IOKit UUID constants
// Macro C (kIOUSBDeviceUserClientTypeID, dll.) TIDAK ter-import ke Swift,
// jadi didefinisikan manual (nilai resmi dari IOUSBLib.h / IOCFPlugIn.h).

private let kIOCFPlugInInterfaceUUID = CFUUIDGetConstantUUIDWithBytes(nil,
    0xC2, 0x44, 0xE8, 0x58, 0x10, 0x9C, 0x11, 0xD4,
    0x91, 0xD4, 0x00, 0x50, 0xE4, 0xC6, 0x42, 0x6F)

private let kIOUSBDeviceUserClientTypeUUID = CFUUIDGetConstantUUIDWithBytes(nil,
    0x9D, 0xC7, 0xB7, 0x80, 0x9E, 0xC0, 0x11, 0xD4,
    0xA5, 0x4F, 0x00, 0x0A, 0x27, 0x05, 0x28, 0x61)

private let kIOUSBDeviceInterfaceUUID = CFUUIDGetConstantUUIDWithBytes(nil,
    0x5C, 0x81, 0x87, 0xD0, 0x9E, 0xF3, 0x11, 0xD4,
    0x8B, 0x45, 0x00, 0x0A, 0x27, 0x05, 0x28, 0x61)

private let kIOUSBInterfaceUserClientTypeUUID = CFUUIDGetConstantUUIDWithBytes(nil,
    0x2D, 0x97, 0x86, 0xC6, 0x9E, 0xF3, 0x11, 0xD4,
    0xAD, 0x51, 0x00, 0x0A, 0x27, 0x05, 0x28, 0x61)

private let kIOUSBInterfaceInterface190UUID = CFUUIDGetConstantUUIDWithBytes(nil,
    0x8F, 0xDB, 0x84, 0x55, 0x74, 0xA6, 0x11, 0xD6,
    0x97, 0xB1, 0x00, 0x30, 0x65, 0xD3, 0x60, 0x8E)

private let kReturnExclusiveAccess: IOReturn = IOReturn(bitPattern: 0xE00002C5)

// MARK: - UVC constants

private let kUVCRequestSetCur: UInt8 = 0x01
private let kUVCRequestGetCur: UInt8 = 0x81
private let kUVCRequestGetMin: UInt8 = 0x82
private let kUVCRequestGetMax: UInt8 = 0x83
private let kUVCRequestGetRes: UInt8 = 0x84
private let kUVCRequestGetDef: UInt8 = 0x87

/// Kontrol yang didukung — 1:1 dengan versi Windows.
enum UVCControlID: String, CaseIterable, Codable {
    // Processing Unit (== IAMVideoProcAmp)
    case brightness, contrast, hue, saturation, sharpness, gamma
    case whiteBalance, whiteBalanceAuto
    case backlightComp, gain, powerLine
    // Camera Terminal (== IAMCameraControl)
    case exposure, exposureAuto, lowLight   // lowLight -> AE Priority
    case focus, focusAuto
    case zoom, pan, tilt

    /// (selector, byte length, isCameraTerminal)
    var spec: (selector: UInt8, length: Int, isCameraTerminal: Bool) {
        switch self {
        case .backlightComp:    return (0x01, 2, false)
        case .brightness:       return (0x02, 2, false)
        case .contrast:         return (0x03, 2, false)
        case .gain:             return (0x04, 2, false)
        case .powerLine:        return (0x05, 1, false)
        case .hue:              return (0x06, 2, false)
        case .saturation:       return (0x07, 2, false)
        case .sharpness:        return (0x08, 2, false)
        case .gamma:            return (0x09, 2, false)
        case .whiteBalance:     return (0x0A, 2, false)
        case .whiteBalanceAuto: return (0x0B, 1, false)

        case .exposureAuto:     return (0x02, 1, true)   // AE Mode (bitmap)
        case .lowLight:         return (0x03, 1, true)   // AE Priority
        case .exposure:         return (0x04, 4, true)   // Exposure Time Absolute
        case .focus:            return (0x06, 2, true)   // Focus Absolute
        case .focusAuto:        return (0x08, 1, true)
        case .zoom:             return (0x0B, 2, true)   // Zoom Absolute
        case .pan:              return (0x0D, 8, true)   // shared Pan/Tilt Absolute
        case .tilt:             return (0x0D, 8, true)
        }
    }

    /// Nilai yang signed (bisa negatif) menurut spesifikasi UVC.
    var isSigned: Bool {
        switch self {
        case .brightness, .hue, .pan, .tilt: return true
        default: return false
        }
    }
}

struct UVCRange {
    var min: Int
    var max: Int
    var step: Int
    var def: Int
}

/// Satu instance per webcam. Thread-safety: semua akses lewat `queue`.
final class UVCController {

    private let queue = DispatchQueue(label: "id.khincc.wsrv.uvc")
    private var interfaceInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBInterfaceInterface190>?>?
    private var deviceInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface>?>?

    private var vcInterfaceNumber: UInt8 = 0
    private var processingUnitID: UInt8 = 0
    private var cameraTerminalID: UInt8 = 0
    private(set) var isReady = false

    /// Cache pan/tilt karena keduanya satu control 8-byte.
    private var cachedPan: Int32 = 0
    private var cachedTilt: Int32 = 0

    // MARK: init / teardown

    init?(vendorID: Int, productID: Int, locationID: UInt32? = nil) {
        guard open(vendorID: vendorID, productID: productID, locationID: locationID) else { return nil }
    }

    deinit { close() }

    private func open(vendorID: Int, productID: Int, locationID: UInt32?) -> Bool {
        let matching = IOServiceMatching("IOUSBDevice") as NSMutableDictionary
        matching["idVendor"] = vendorID
        matching["idProduct"] = productID

        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return false }
        defer { IOObjectRelease(iterator) }

        var service: io_service_t = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service); service = IOIteratorNext(iterator) }

            if let wanted = locationID {
                var propRef = IORegistryEntryCreateCFProperty(service, "locationID" as CFString, kCFAllocatorDefault, 0)
                let loc = (propRef?.takeRetainedValue() as? NSNumber)?.uint32Value
                propRef = nil
                if let loc, loc != wanted { continue }
            }
            if setupDevice(service: service) { return true }
        }
        return false
    }

    private func setupDevice(service: io_service_t) -> Bool {
        var plugin: UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>?
        var score: Int32 = 0
        guard IOCreatePlugInInterfaceForService(service,
                                                kIOUSBDeviceUserClientTypeUUID,
                                                kIOCFPlugInInterfaceUUID,
                                                &plugin, &score) == KERN_SUCCESS,
              let plugin else { return false }
        defer { _ = plugin.pointee?.pointee.Release(plugin) }

        var devRaw: UnsafeMutableRawPointer?
        guard plugin.pointee?.pointee.QueryInterface(plugin,
                CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceUUID), &devRaw) == KERN_SUCCESS,
              let devRaw else { return false }
        deviceInterface = devRaw.assumingMemoryBound(to: UnsafeMutablePointer<IOUSBDeviceInterface>?.self)

        guard parseVideoControlDescriptors(), openVCInterface() else {
            if let dev = deviceInterface, let dd = dev.pointee { _ = dd.pointee.Release(dev) }
            deviceInterface = nil
            return false
        }
        isReady = true
        return true
    }

    /// Baca configuration descriptor -> cari VC interface, Processing Unit ID, Camera Terminal ID.
    private func parseVideoControlDescriptors() -> Bool {
        guard let dev = deviceInterface, let d = dev.pointee else { return false }
        var descPtr: IOUSBConfigurationDescriptorPtr?
        guard d.pointee.GetConfigurationDescriptorPtr(dev, 0, &descPtr) == kIOReturnSuccess,
              let descPtr else { return false }

        let total = Int(UInt16(littleEndian: descPtr.pointee.wTotalLength))
        let bytes = UnsafeRawPointer(descPtr).assumingMemoryBound(to: UInt8.self)

        var i = 0
        var currentInterface: UInt8 = 0
        var inVC = false
        var foundVC = false

        while i + 1 < total {
            let len = Int(bytes[i])
            let type = bytes[i + 1]
            if len == 0 { break }

            if type == 0x04, i + 7 < total { // INTERFACE descriptor
                currentInterface = bytes[i + 2]
                let cls = bytes[i + 5], sub = bytes[i + 6]
                inVC = (cls == 0x0E && sub == 0x01) // Video / VideoControl
                if inVC { vcInterfaceNumber = currentInterface; foundVC = true }
            } else if inVC, type == 0x24, i + 3 < total { // CS_INTERFACE
                let subtype = bytes[i + 2]
                switch subtype {
                case 0x02: // VC_INPUT_TERMINAL
                    if i + 5 < total {
                        let termType = UInt16(bytes[i + 4]) | (UInt16(bytes[i + 5]) << 8)
                        if termType == 0x0201 { cameraTerminalID = bytes[i + 3] } // ITT_CAMERA
                    }
                case 0x05: // VC_PROCESSING_UNIT
                    processingUnitID = bytes[i + 3]
                default: break
                }
            }
            i += len
        }
        return foundVC && (processingUnitID != 0 || cameraTerminalID != 0)
    }

    private func openVCInterface() -> Bool {
        guard let dev = deviceInterface, let d = dev.pointee else { return false }

        var request = IOUSBFindInterfaceRequest(
            bInterfaceClass: 0x0E,          // Video
            bInterfaceSubClass: 0x01,       // VideoControl
            bInterfaceProtocol: UInt16(kIOUSBFindInterfaceDontCare),
            bAlternateSetting: UInt16(kIOUSBFindInterfaceDontCare))

        var iter: io_iterator_t = 0
        guard d.pointee.CreateInterfaceIterator(dev, &request, &iter) == kIOReturnSuccess else { return false }
        defer { IOObjectRelease(iter) }

        let ifService = IOIteratorNext(iter)
        guard ifService != 0 else { return false }
        defer { IOObjectRelease(ifService) }

        var plugin: UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>?
        var score: Int32 = 0
        guard IOCreatePlugInInterfaceForService(ifService,
                                                kIOUSBInterfaceUserClientTypeUUID,
                                                kIOCFPlugInInterfaceUUID,
                                                &plugin, &score) == KERN_SUCCESS,
              let plugin else { return false }
        defer { _ = plugin.pointee?.pointee.Release(plugin) }

        var ifRaw: UnsafeMutableRawPointer?
        guard plugin.pointee?.pointee.QueryInterface(plugin,
                CFUUIDGetUUIDBytes(kIOUSBInterfaceInterface190UUID), &ifRaw) == KERN_SUCCESS,
              let ifRaw else { return false }
        interfaceInterface = ifRaw.assumingMemoryBound(to: UnsafeMutablePointer<IOUSBInterfaceInterface190>?.self)

        // Buka interface. Kalau exclusive (dipakai driver), control request
        // via pipe 0 tetap jalan di banyak device — jadi jangan gagal total.
        if let intf = interfaceInterface, let ii = intf.pointee {
            let r = ii.pointee.USBInterfaceOpen(intf)
            if r != kIOReturnSuccess && r != kReturnExclusiveAccess {
                _ = ii.pointee.USBInterfaceOpenSeize(intf)
            }
        }
        return true
    }

    func close() {
        if let intf = interfaceInterface, let ii = intf.pointee {
            _ = ii.pointee.USBInterfaceClose(intf)
            _ = ii.pointee.Release(intf)
        }
        interfaceInterface = nil
        if let dev = deviceInterface, let d = dev.pointee {
            _ = d.pointee.Release(dev)
        }
        deviceInterface = nil
        isReady = false
    }

    // MARK: - raw request

    private func sendRequest(_ bRequest: UInt8, control: UVCControlID, data: inout [UInt8]) -> Bool {
        guard isReady, let intf = interfaceInterface, let ii = intf.pointee else { return false }
        let spec = control.spec
        let unitID = spec.isCameraTerminal ? cameraTerminalID : processingUnitID
        guard unitID != 0 else { return false }

        var req = IOUSBDevRequest()
        req.bmRequestType = (bRequest == kUVCRequestSetCur) ? 0x21 : 0xA1 // class, interface, out/in
        req.bRequest = bRequest
        req.wValue = UInt16(spec.selector) << 8
        req.wIndex = (UInt16(unitID) << 8) | UInt16(vcInterfaceNumber)
        req.wLength = UInt16(data.count)

        var ok = false
        data.withUnsafeMutableBytes { buf in
            req.pData = buf.baseAddress
            ok = ii.pointee.ControlRequest(intf, 0, &req) == kIOReturnSuccess
        }
        return ok
    }

    private func toInt(_ bytes: [UInt8], signed: Bool) -> Int {
        var v: UInt = 0
        for (i, b) in bytes.enumerated() { v |= UInt(b) << (8 * i) }
        if signed {
            switch bytes.count {
            case 1: return Int(Int8(bitPattern: UInt8(truncatingIfNeeded: v)))
            case 2: return Int(Int16(bitPattern: UInt16(truncatingIfNeeded: v)))
            case 4: return Int(Int32(bitPattern: UInt32(truncatingIfNeeded: v)))
            default: return Int(bitPattern: v)
            }
        }
        return Int(bitPattern: v)
    }

    private func toBytes(_ value: Int, length: Int) -> [UInt8] {
        (0..<length).map { UInt8(truncatingIfNeeded: value >> (8 * $0)) }
    }

    // MARK: - public API (sync, dipanggil dari sessionQueue CameraManager)

    /// Cek apakah kamera mendukung kontrol ini (GET_MIN berhasil).
    func supports(_ control: UVCControlID) -> Bool {
        queue.sync {
            var buf = [UInt8](repeating: 0, count: control.spec.length)
            return sendRequest(kUVCRequestGetMin, control: control, data: &buf)
        }
    }

    func range(for control: UVCControlID) -> UVCRange? {
        queue.sync {
            let len = control.spec.length
            let signed = control.isSigned
            func get(_ req: UInt8) -> Int? {
                var buf = [UInt8](repeating: 0, count: len)
                guard sendRequest(req, control: control, data: &buf) else { return nil }
                if control == .pan { return toInt(Array(buf[0..<4]), signed: true) }
                if control == .tilt { return toInt(Array(buf[4..<8]), signed: true) }
                return toInt(buf, signed: signed)
            }
            guard let mn = get(kUVCRequestGetMin), let mx = get(kUVCRequestGetMax) else { return nil }
            let res = get(kUVCRequestGetRes) ?? 1
            let def = get(kUVCRequestGetDef) ?? mn
            return UVCRange(min: mn, max: mx, step: Swift.max(res, 1), def: def)
        }
    }

    func getValue(_ control: UVCControlID) -> Int? {
        queue.sync {
            var buf = [UInt8](repeating: 0, count: control.spec.length)
            guard sendRequest(kUVCRequestGetCur, control: control, data: &buf) else { return nil }
            switch control {
            case .pan:
                cachedPan = Int32(toInt(Array(buf[0..<4]), signed: true))
                cachedTilt = Int32(toInt(Array(buf[4..<8]), signed: true))
                return Int(cachedPan)
            case .tilt:
                cachedPan = Int32(toInt(Array(buf[0..<4]), signed: true))
                cachedTilt = Int32(toInt(Array(buf[4..<8]), signed: true))
                return Int(cachedTilt)
            case .exposureAuto:
                // AE Mode bitmap: 1=manual, 2=auto, 4=shutter-prio, 8=aperture-prio
                let raw = toInt(buf, signed: false)
                return (raw & 0b1110) != 0 ? 1 : 0
            default:
                return toInt(buf, signed: control.isSigned)
            }
        }
    }

    @discardableResult
    func setValue(_ control: UVCControlID, _ value: Int) -> Bool {
        queue.sync {
            var data: [UInt8]
            switch control {
            case .pan:
                cachedPan = Int32(clamping: value)
                data = toBytes(Int(cachedPan), length: 4) + toBytes(Int(cachedTilt), length: 4)
            case .tilt:
                cachedTilt = Int32(clamping: value)
                data = toBytes(Int(cachedPan), length: 4) + toBytes(Int(cachedTilt), length: 4)
            case .exposureAuto:
                // 1 = aktifkan auto (mode 2/auto, fallback 8/aperture-prio), 0 = manual (1)
                if value != 0 {
                    var auto: [UInt8] = [2]
                    if sendRequest(kUVCRequestSetCur, control: control, data: &auto) { return true }
                    data = [8]
                } else {
                    data = [1]
                }
            default:
                data = toBytes(value, length: control.spec.length)
            }
            return sendRequest(kUVCRequestSetCur, control: control, data: &data)
        }
    }
}
