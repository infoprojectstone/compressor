import AppKit
import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import Quartz
import UniformTypeIdentifiers

enum SafePDFCompressor: Sendable {
    nonisolated static func compress(
        _ sourceURL: URL,
        config: CompressionConfig,
        destinationFolder: URL,
        uniqueNamer: (URL, URL, String, String) -> URL,
        control: CompressionControl
    ) throws -> URL {
        guard let doc = PDFDocument(url: sourceURL) else {
            throw NSError(
                domain: "Compressor",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No se pudo abrir el documento PDF."]
            )
        }
        let pageCount = doc.pageCount
        guard pageCount > 0 else { return sourceURL }
        let originalBytes = size(sourceURL)
        guard originalBytes > 1024 else { return sourceURL }

        let targetBytes: Int64 = if config.mode == .targetSize {
            Int64(max(0.05, config.targetSizeMB) * 1_000_000)
        } else {
            switch config.quality {
            case .high: Int64(Double(originalBytes) * 0.85)
            case .balanced: Int64(Double(originalBytes) * 0.65)
            case .small: Int64(Double(originalBytes) * 0.45)
            }
        }

        let tempFolder = FileManager.default.temporaryDirectory.appendingPathComponent("PDFComp_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempFolder) }

        var bestCandidate: URL?
        var bestSize: Int64 = originalBytes

        // NIVEL 1: Optimización vectorial con QuartzFilter (re-comprime fotos sin tocar texto ni vectores)
        let qfCandidate = tempFolder.appendingPathComponent("tier1_vector.pdf")
        let qfSuccess = compressWithQuartzFilter(
            doc: doc,
            config: config,
            originalBytes: originalBytes,
            targetBytes: targetBytes,
            outURL: qfCandidate,
            control: control
        )

        if qfSuccess {
            let qfSize = size(qfCandidate)
            if qfSize > 0 && qfSize < originalBytes {
                bestCandidate = qfCandidate
                bestSize = qfSize

                // Si alcanzó el objetivo de tamaño o es modo calidad con reducción notable, conservamos vector
                if config.mode == .targetSize && qfSize <= targetBytes {
                    return try finalize(bestCandidate!, sourceURL: sourceURL, destinationFolder: destinationFolder, uniqueNamer: uniqueNamer)
                } else if config.mode == .quality && qfSize <= targetBytes {
                    return try finalize(bestCandidate!, sourceURL: sourceURL, destinationFolder: destinationFolder, uniqueNamer: uniqueNamer)
                }
            }
        }

        // NIVEL 2: Rasterización adaptativa inteligente (para escaneos de fotos pesadas o si Nivel 1 no redujo lo suficiente)
        if bestSize > targetBytes || bestSize >= Int64(Double(originalBytes) * 0.95) {
            let rasterCandidate = tempFolder.appendingPathComponent("tier2_raster.pdf")
            let rasterSuccess = compressWithAdaptiveRasterization(
                doc: doc,
                config: config,
                originalBytes: originalBytes,
                targetBytes: targetBytes,
                pageCount: pageCount,
                outURL: rasterCandidate,
                control: control
            )

            if rasterSuccess {
                let rasterSize = size(rasterCandidate)
                if rasterSize > 0 && rasterSize < bestSize {
                    bestCandidate = rasterCandidate
                    bestSize = rasterSize
                }
            }
        }

        // Si tenemos un resultado menor que el original, finalizamos
        if let winner = bestCandidate, bestSize < originalBytes {
            return try finalize(winner, sourceURL: sourceURL, destinationFolder: destinationFolder, uniqueNamer: uniqueNamer)
        }

        // Si por su naturaleza el archivo no admite reducción sin crecer, devolvemos el original
        return sourceURL
    }

    // MARK: - Nivel 1: QuartzFilter

    private static func compressWithQuartzFilter(
        doc: PDFDocument,
        config: CompressionConfig,
        originalBytes: Int64,
        targetBytes: Int64,
        outURL: URL,
        control: CompressionControl
    ) -> Bool {
        let (jpegQuality, dpi, maxDim): (Double, Int, Int)
        if config.mode == .quality {
            switch config.quality {
            case .high: (jpegQuality, dpi, maxDim) = (0.82, 200, 2600)
            case .balanced: (jpegQuality, dpi, maxDim) = (0.70, 144, 1920)
            case .small: (jpegQuality, dpi, maxDim) = (0.50, 96, 1280)
            }
        } else {
            let ratio = Double(targetBytes) / Double(max(1, originalBytes))
            if ratio >= 0.70 {
                (jpegQuality, dpi, maxDim) = (0.80, 180, 2400)
            } else if ratio >= 0.40 {
                (jpegQuality, dpi, maxDim) = (0.65, 144, 1800)
            } else if ratio >= 0.20 {
                (jpegQuality, dpi, maxDim) = (0.50, 100, 1280)
            } else {
                (jpegQuality, dpi, maxDim) = (0.38, 72, 960)
            }
        }

        let filterProps: [String: Any] = [
            "Domains": ["Applications": true, "Printing": true],
            "FilterType": 1,
            "Name": "Compressor PDF Filter",
            "FilterData": [
                "ColorSettings": [
                    "ImageSettings": [
                        "ImageCompression": "ImageJPEGCompress",
                        "Compression Quality": jpegQuality,
                        "ImageScaleSettings": [
                            "ImageResolution": dpi,
                            "ImageScaleInterpolate": true,
                            "ImageSizeMax": maxDim,
                            "ImageSizeMin": 0
                        ]
                    ]
                ]
            ]
        ]

        guard let filter = QuartzFilter(properties: filterProps),
              let consumer = CGDataConsumer(url: outURL as CFURL) else {
            return false
        }

        var firstBox = doc.page(at: 0)?.bounds(for: .mediaBox) ?? CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &firstBox, nil) else {
            return false
        }

        filter.apply(to: ctx)

        for i in 0..<doc.pageCount {
            control.waitIfPaused()
            guard let page = doc.page(at: i) else { continue }
            var pageBox = page.bounds(for: .mediaBox)
            ctx.beginPage(mediaBox: &pageBox)
            page.draw(with: .mediaBox, to: ctx)
            ctx.endPage()
        }

        ctx.closePDF()
        return FileManager.default.fileExists(atPath: outURL.path)
    }

    // MARK: - Nivel 2: Rasterización Adaptativa Inteligente

    private static func compressWithAdaptiveRasterization(
        doc: PDFDocument,
        config: CompressionConfig,
        originalBytes: Int64,
        targetBytes: Int64,
        pageCount: Int,
        outURL: URL,
        control: CompressionControl
    ) -> Bool {
        let budgetTotal = min(targetBytes, Int64(Double(originalBytes) * 0.85))
        let bpp = budgetTotal / Int64(max(1, pageCount))

        var (scale, jpegQuality): (CGFloat, Double) = if config.mode == .quality {
            switch config.quality {
            case .high: (1.5, 0.76)
            case .balanced: (1.2, 0.65)
            case .small: (0.9, 0.48)
            }
        } else {
            if bpp >= 250_000 {
                (1.4, 0.72)
            } else if bpp >= 120_000 {
                (1.15, 0.62)
            } else if bpp >= 60_000 {
                (0.95, 0.48)
            } else if bpp >= 30_000 {
                (0.80, 0.38)
            } else {
                (0.65, 0.28)
            }
        }

        for _ in 0..<2 {
            let success = renderRasterDoc(
                doc: doc,
                scale: scale,
                jpegQuality: jpegQuality,
                outURL: outURL,
                control: control
            )
            guard success else { return false }
            let finalSize = size(outURL)
            if finalSize > 0 && finalSize < originalBytes {
                return true
            }
            scale *= 0.70
            jpegQuality *= 0.75
        }
        return false
    }

    private static func renderRasterDoc(
        doc: PDFDocument,
        scale: CGFloat,
        jpegQuality: Double,
        outURL: URL,
        control: CompressionControl
    ) -> Bool {
        let outputDoc = PDFDocument()
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        for index in 0..<doc.pageCount {
            control.waitIfPaused()
            guard let page = doc.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let pixelWidth = max(80, Int(bounds.width * scale))
            let pixelHeight = max(80, Int(bounds.height * scale))

            autoreleasepool {
                guard let cgContext = CGContext(
                    data: nil,
                    width: pixelWidth,
                    height: pixelHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: 0,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ) else { return }

                cgContext.setFillColor(NSColor.white.cgColor)
                cgContext.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

                cgContext.saveGState()
                cgContext.scaleBy(x: scale, y: scale)
                page.draw(with: .mediaBox, to: cgContext)
                cgContext.restoreGState()

                guard let cgImage = cgContext.makeImage() else { return }

                let jpegData = NSMutableData()
                guard let destination = CGImageDestinationCreateWithData(jpegData, UTType.jpeg.identifier as CFString, 1, nil) else { return }
                let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: jpegQuality]
                CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
                guard CGImageDestinationFinalize(destination) else { return }

                guard let compressedImage = NSImage(data: jpegData as Data),
                      let newPage = PDFPage(image: compressedImage) else { return }
                newPage.setBounds(bounds, for: .mediaBox)
                outputDoc.insert(newPage, at: outputDoc.pageCount)
            }
        }

        guard outputDoc.pageCount > 0 else { return false }
        return outputDoc.write(to: outURL)
    }

    private static func finalize(
        _ tempURL: URL,
        sourceURL: URL,
        destinationFolder: URL,
        uniqueNamer: (URL, URL, String, String) -> URL
    ) throws -> URL {
        let finalURL = uniqueNamer(sourceURL, destinationFolder, "_comprimido", "pdf")
        if FileManager.default.fileExists(atPath: finalURL.path) {
            try? FileManager.default.removeItem(at: finalURL)
        }
        try FileManager.default.copyItem(at: tempURL, to: finalURL)
        return finalURL
    }

    private static func size(_ url: URL) -> Int64 {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
    }
}
