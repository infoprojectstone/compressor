import Foundation
import ImageIO
import UniformTypeIdentifiers

enum CompressionQuality: String, CaseIterable, Identifiable, Sendable {
    case high, balanced, small
    var id: String { rawValue }
}

/// Motor derivado del proyecto Image_Compressor: conserva formato, busca la
/// mayor calidad que cumpla el objetivo y jamás guarda un resultado más pesado.
enum SafeImageCompressor {
    static func compress(_ sourceURL: URL, targetMB: Double, control: CompressionControl? = nil) throws -> Data? {
        let original = size(sourceURL)
        let target = Int64(max(0.05, targetMB) * 1_000_000)
        guard original > target else { return nil }
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let p = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = p[kCGImagePropertyPixelWidth] as? Int,
              let height = p[kCGImagePropertyPixelHeight] as? Int else { throw Error.unreadable }
        let outputType = preferredType(sourceURL, hasAlpha: hasAlpha(source))
        let originalMax = max(width, height)
        var scale = 1.0
        var best: Data?
        while true {
            control?.waitIfPaused()
            let maxDimension = max(320, Int(Double(originalMax) * scale))
            let data = bestEncode(source, type: outputType, maxDimension: maxDimension, originalMax: originalMax, target: target, control:control)
            if let candidate = data.smallest, best == nil || candidate.count < best!.count { best = candidate }
            if let fitting = data.fitting, Int64(fitting.count) < original {
                return fitting
            }
            if maxDimension <= 320 { break }
            let estimate = data.smallest.map { sqrt(Double(target) / Double($0.count)) * 0.96 } ?? 0.80
            scale *= min(0.92, max(0.60, estimate))
        }
        // El objetivo puede ser inalcanzable; aun así solo aceptamos una mejora real.
        if let best, Int64(best.count) < original { return best }
        return nil
    }

    static func compress(_ sourceURL: URL, quality: CompressionQuality, control: CompressionControl? = nil) throws -> Data? {
        let original = size(sourceURL)
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { throw Error.unreadable }
        control?.waitIfPaused()
        let type = preferredType(sourceURL, hasAlpha: hasAlpha(source))
        let originalMax = max(width, height)
        let settings: (quality: Double, maxDimension: Int) = switch quality {
        case .high: (0.92, originalMax)
        case .balanced: (0.82, min(originalMax, 3200))
        case .small: (0.58, min(originalMax, 1800))
        }
        guard let data = encode(source, type:type, quality:settings.quality, maxDimension:settings.maxDimension, originalMax:originalMax), Int64(data.count) < original else { return nil }
        return data
    }

    static func outputExtension(for sourceURL: URL) -> String {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else { return "jpg" }
        let type = preferredType(sourceURL, hasAlpha:hasAlpha(source))
        if type == UTType.png.identifier as CFString { return "png" }
        if type == UTType.heic.identifier as CFString { return "heic" }
        if type as String == "org.webmproject.webp" { return "webp" }
        return "jpg"
    }

    private static func bestEncode(_ source: CGImageSource, type: CFString, maxDimension: Int, originalMax: Int, target: Int64, control: CompressionControl?) -> (fitting: Data?, smallest: Data?) {
        if type == UTType.png.identifier as CFString {
            let data = encode(source, type: type, quality: 1, maxDimension: maxDimension, originalMax: originalMax)
            return (data.flatMap { $0.count <= target ? $0 : nil }, data)
        }
        var low = 0.12, high = 0.98; var fitting: Data?; var smallest: Data?
        for _ in 0..<7 { control?.waitIfPaused(); let q = (low + high) / 2; guard let data = encode(source, type: type, quality: q, maxDimension: maxDimension, originalMax: originalMax) else { break }; if smallest == nil || data.count < smallest!.count { smallest = data }; if data.count <= target { fitting = data; low = q } else { high = q } }
        return (fitting, smallest)
    }
    private static func encode(_ source: CGImageSource, type: CFString, quality: Double, maxDimension: Int, originalMax: Int) -> Data? {
        let data = NSMutableData(); guard let destination = CGImageDestinationCreateWithData(data, type, 1, nil) else { return nil }
        let properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        let image: CGImage?
        if maxDimension < originalMax {
            let opts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension
            ]
            image = CGImageSourceCreateThumbnailAtIndex(source, 0, opts as CFDictionary)
        } else {
            image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        }
        guard let validImage = image else { return nil }
        CGImageDestinationAddImage(destination, validImage, properties as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
    private static func preferredType(_ url: URL, hasAlpha: Bool) -> CFString { let available = Set(CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []); let requested: String; switch url.pathExtension.lowercased() { case "jpg", "jpeg": requested = UTType.jpeg.identifier; case "png": requested = UTType.png.identifier; case "heic", "heif": requested = UTType.heic.identifier; case "webp": requested = "org.webmproject.webp"; default: requested = hasAlpha ? UTType.png.identifier : UTType.jpeg.identifier }; return (available.contains(requested) ? requested : (hasAlpha ? UTType.png.identifier : UTType.jpeg.identifier)) as CFString }
    private static func hasAlpha(_ source: CGImageSource) -> Bool { guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return false }; switch image.alphaInfo { case .first,.last,.premultipliedFirst,.premultipliedLast,.alphaOnly: return true; default: return false } }
    private static func size(_ url: URL) -> Int64 { (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0 }
    enum Error: LocalizedError { case unreadable; var errorDescription: String? { "No se pudo leer la imagen." } }
}
