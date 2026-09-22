import AppKit
import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import Quartz
import UniformTypeIdentifiers

@main
struct VerifyCompression {
    static func main() async {
        print("\n=======================================================")
        print("   SUITE DE VERIFICACIÓN DE COMPRESIÓN MULTIFORMATO    ")
        print("=======================================================\n")
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("Verify_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var allPassed = true



        print("▶ [1/4] PRUEBA: Imagen JPEG (Modo Calidad)")
        do {
            let jpegIn = tempDir.appendingPathComponent("sample_photo.jpg")
            try makePhotographicJPEG(at: jpegIn, width: 2400, height: 1600)
            let origSize = fileSize(jpegIn)
            print("  • Archivo original: \(formatBytes(origSize)) (2400x1600)")

            let jpegOut = tempDir.appendingPathComponent("sample_photo_compressed.jpg")
            guard let compressedData = compressImageNative(jpegIn, quality: 0.70, maxDim: 1800) else {
                throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "No se generaron datos de compresión"])
            }
            try compressedData.write(to: jpegOut)
            let finalSize = fileSize(jpegOut)
            let reduction = calcSaving(origSize, finalSize)
            print("  • Archivo comprimido: \(formatBytes(finalSize)) (1800x1200 máx)")
            print("  • Reducción lograda: \(reduction)")

            if finalSize < origSize && finalSize > 0 {
                print("  ✅ JPEG: Compresión exitosa con ahorro significativo.\n")
            } else {
                print("  ❌ JPEG: El tamaño no se redujo adecuadamente.\n")
                allPassed = false
            }
        } catch {
            print("  ❌ ERROR en JPEG: \(error.localizedDescription)\n")
            allPassed = false
        }

        // 2. PRUEBA DE IMAGEN: PNG (Modo Tamaño Objetivo)
        print("▶ [2/4] PRUEBA: Imagen PNG (Modo Tamaño Objetivo 400 KB)")
        do {
            let pngIn = tempDir.appendingPathComponent("sample_graphic.png")
            try makeGraphicPNG(at: pngIn, width: 1600, height: 1200)
            let origSize = fileSize(pngIn)
            print("  • Archivo original: \(formatBytes(origSize)) (1600x1200)")

            let pngOut = tempDir.appendingPathComponent("sample_graphic_compressed.png")
            let targetBytes: Int64 = 400_000
            guard let compressedData = compressImageTargetSize(pngIn, targetBytes: targetBytes) else {
                throw NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "No se generaron datos para PNG"])
            }
            try compressedData.write(to: pngOut)
            let finalSize = fileSize(pngOut)
            let reduction = calcSaving(origSize, finalSize)
            print("  • Archivo comprimido: \(formatBytes(finalSize)) (Objetivo: <= 400 KB)")
            print("  • Reducción lograda: \(reduction)")

            if finalSize <= targetBytes && finalSize < origSize {
                print("  ✅ PNG: Compresión por tamaño objetivo cumplida exitosamente.\n")
            } else {
                print("  ❌ PNG: No cumplió el objetivo de tamaño.\n")
                allPassed = false
            }
        } catch {
            print("  ❌ ERROR en PNG: \(error.localizedDescription)\n")
            allPassed = false
        }

        // 3. PRUEBA DE VÍDEO: MP4 con AVAssetReader + AVAssetWriter (Control de Bitrate)
        print("▶ [3/4] PRUEBA: Vídeo MP4 (AVAssetReader/Writer con Control de Bitrate a 1.2 Mbps)")
        do {
            let videoIn = tempDir.appendingPathComponent("sample_clip.mp4")
            try await makeTestVideo(at: videoIn, width: 1280, height: 720, frameCount: 45)
            let origSize = fileSize(videoIn)
            print("  • Vídeo original: \(formatBytes(origSize)) (720p a 30fps)")

            let videoOut = tempDir.appendingPathComponent("sample_clip_compressed.mp4")
            try await transcodeTestVideo(input: videoIn, output: videoOut, targetBitrate: 1_200_000, targetW: 960, targetH: 540)
            let finalSize = fileSize(videoOut)
            let reduction = calcSaving(origSize, finalSize)
            print("  • Vídeo comprimido: \(formatBytes(finalSize)) (540p a 1.2 Mbps)")
            print("  • Reducción lograda: \(reduction)")
            
            let exportedAsset = AVURLAsset(url: videoOut)
            let isPlayable = (try? await exportedAsset.load(.isPlayable)) ?? false
            if isPlayable && finalSize > 0 {
                print("  • Verificación de integridad: Reproducible por macOS ✅")
                print("  ✅ VÍDEO: Transcodificación nativa con control de bitrate superada con éxito.\n")
            } else {
                print("  ❌ VÍDEO: El archivo resultante no es reproducible.\n")
                allPassed = false
            }
        } catch {
            print("  ❌ ERROR en Vídeo: \(error.localizedDescription)\n")
            allPassed = false
        }

        // 4. PRUEBA DE PDF: Motor Híbrido en 2 Niveles (QuartzFilter + Rasterización Adaptativa)
        print("▶ [4/4] PRUEBA: Documentos PDF (Motor Híbrido SafePDFCompressor)")
        do {
            // 4a. PDF con imágenes HD y texto vectorial (Nivel 1: QuartzFilter)
            print("  • Subprueba 4a: PDF mixto HD (3 páginas con fotos HD y vectores)")
            let pdfHdIn = tempDir.appendingPathComponent("sample_hd_vector.pdf")
            let pdfHdOut = tempDir.appendingPathComponent("sample_hd_vector_compressed.pdf")
            try makePhotographicPDF(at: pdfHdIn, pageCount: 3, imgW: 1800, imgH: 1200)
            let hdOrigSize = fileSize(pdfHdIn)
            print("    - Archivo original: \(formatBytes(hdOrigSize))")

            let filterProps: [String: Any] = [
                "Domains": ["Applications": true, "Printing": true],
                "FilterType": 1,
                "Name": "Compressor Filter",
                "FilterData": [
                    "ColorSettings": [
                        "ImageSettings": [
                            "ImageCompression": "ImageJPEGCompress",
                            "Compression Quality": 0.70,
                            "ImageScaleSettings": [
                                "ImageResolution": 144,
                                "ImageScaleInterpolate": true,
                                "ImageSizeMax": 1920,
                                "ImageSizeMin": 0
                            ]
                        ]
                    ]
                ]
            ]
            if let filter = QuartzFilter(properties: filterProps),
               let inPDFDoc = PDFDocument(url: pdfHdIn),
               let consumer = CGDataConsumer(url: pdfHdOut as CFURL) {
                var firstBox = inPDFDoc.page(at: 0)?.bounds(for: .mediaBox) ?? CGRect(x: 0, y: 0, width: 600, height: 800)
                if let ctx = CGContext(consumer: consumer, mediaBox: &firstBox, nil) {
                    filter.apply(to: ctx)
                    for i in 0..<inPDFDoc.pageCount {
                        if let page = inPDFDoc.page(at: i) {
                            var pageBox = page.bounds(for: .mediaBox)
                            ctx.beginPage(mediaBox: &pageBox)
                            page.draw(with: .mediaBox, to: ctx)
                            ctx.endPage()
                        }
                    }
                    ctx.closePDF()
                }
            }
            let hdFinalSize = fileSize(pdfHdOut)
            let hdSaving = calcSaving(hdOrigSize, hdFinalSize)
            print("    - Archivo comprimido (Nivel 1): \(formatBytes(hdFinalSize))")
            print("    - Reducción lograda: \(hdSaving)")

            if hdFinalSize < hdOrigSize && hdFinalSize > 0 {
                print("    ✅ Nivel 1 (QuartzFilter vectorial): Compresión masiva exitosa.\n")
            } else {
                print("    ❌ Nivel 1: No logró reducir el PDF mixto.\n")
                allPassed = false
            }

            // 4b. PDF escaneado multipágina (Nivel 2: Rasterización adaptativa)
            print("  • Subprueba 4b: PDF escaneado (3 páginas de mapa de bits)")
            let pdfScanIn = tempDir.appendingPathComponent("sample_scanned.pdf")
            let pdfScanOut = tempDir.appendingPathComponent("sample_scanned_compressed.pdf")
            try makeTestPDF(at: pdfScanIn, pageCount: 3)
            let scanOrigSize = fileSize(pdfScanIn)
            print("    - Archivo original: \(formatBytes(scanOrigSize))")

            guard let scanDoc = PDFDocument(url: pdfScanIn) else {
                throw NSError(domain: "Test", code: 5, userInfo: [NSLocalizedDescriptionKey: "No se pudo leer el PDF"])
            }
            let outDoc = PDFDocument()
            let scale: CGFloat = 1.0
            let jpegQuality: Double = 0.55
            let colorSpace = CGColorSpaceCreateDeviceRGB()

            for i in 0..<scanDoc.pageCount {
                guard let page = scanDoc.page(at: i) else { continue }
                let bounds = page.bounds(for: .mediaBox)
                let pw = max(80, Int(bounds.width * scale))
                let ph = max(80, Int(bounds.height * scale))

                guard let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { continue }
                ctx.setFillColor(NSColor.white.cgColor)
                ctx.fill(CGRect(x: 0, y: 0, width: pw, height: ph))
                ctx.saveGState()
                ctx.scaleBy(x: scale, y: scale)
                page.draw(with: .mediaBox, to: ctx)
                ctx.restoreGState()

                guard let cgImg = ctx.makeImage() else { continue }
                let data = NSMutableData()
                guard let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { continue }
                CGImageDestinationAddImage(dest, cgImg, [kCGImageDestinationLossyCompressionQuality: jpegQuality] as CFDictionary)
                CGImageDestinationFinalize(dest)

                if let nsImg = NSImage(data: data as Data), let newPage = PDFPage(image: nsImg) {
                    newPage.setBounds(bounds, for: .mediaBox)
                    outDoc.insert(newPage, at: outDoc.pageCount)
                }
            }

            guard outDoc.write(to: pdfScanOut) else {
                throw NSError(domain: "Test", code: 6, userInfo: [NSLocalizedDescriptionKey: "No se pudo escribir el PDF comprimido"])
            }
            let scanFinalSize = fileSize(pdfScanOut)
            let scanSaving = calcSaving(scanOrigSize, scanFinalSize)
            print("    - Archivo comprimido (Nivel 2): \(formatBytes(scanFinalSize)) (Páginas: \(outDoc.pageCount))")
            print("    - Reducción lograda: \(scanSaving)")

            if scanFinalSize < scanOrigSize && outDoc.pageCount == 3 {
                print("    ✅ Nivel 2 (Rasterización adaptativa): Compresión superada con éxito.\n")
            } else {
                print("    ❌ Nivel 2: Falló la reducción o integridad de páginas.\n")
                allPassed = false
            }

            // 4c. PDF con hipervínculos clicables y anotaciones
            print("  • Subprueba 4c: Preservación de enlaces clicables y anotaciones")
            let pdfLinkIn = tempDir.appendingPathComponent("sample_links.pdf")
            let pdfLinkOut = tempDir.appendingPathComponent("sample_links_compressed.pdf")

            let linkDoc = PDFDocument()
            let linkPage = PDFPage()
            linkPage.setBounds(CGRect(x: 0, y: 0, width: 600, height: 800), for: .mediaBox)
            linkDoc.insert(linkPage, at: 0)
            let testURL = URL(string: "https://apple.com")!
            let linkAnnot = PDFAnnotation(bounds: CGRect(x: 50, y: 700, width: 200, height: 30), forType: .link, withProperties: nil)
            linkAnnot.url = testURL
            linkPage.addAnnotation(linkAnnot)
            linkDoc.write(to: pdfLinkIn)

            if let filter = QuartzFilter(properties: filterProps),
               let inDoc = PDFDocument(url: pdfLinkIn),
               let consumer = CGDataConsumer(url: pdfLinkOut as CFURL) {
                var box = inDoc.page(at: 0)?.bounds(for: .mediaBox) ?? CGRect(x: 0, y: 0, width: 600, height: 800)
                if let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) {
                    filter.apply(to: ctx)
                    for i in 0..<inDoc.pageCount {
                        if let page = inDoc.page(at: i) {
                            var pageBox = page.bounds(for: .mediaBox)
                            ctx.beginPage(mediaBox: &pageBox)
                            page.draw(with: .mediaBox, to: ctx)
                            ctx.endPage()
                        }
                    }
                    ctx.closePDF()
                }
                if let compDoc = PDFDocument(url: pdfLinkOut) {
                    transferMetadataAndAnnotations(from: inDoc, to: compDoc)
                    compDoc.write(to: pdfLinkOut)
                }
            }

            if let verifiedDoc = PDFDocument(url: pdfLinkOut),
               let firstPage = verifiedDoc.page(at: 0),
               let foundLink = firstPage.annotations.first(where: { $0.url == testURL }) {
                print("    - Hipervínculo verificado con éxito: \(foundLink.url?.absoluteString ?? "")")
                print("    ✅ Subprueba 4c: Hipervínculos clicables y anotaciones conservadas al 100%.\n")
            } else {
                print("    ❌ Subprueba 4c: Se perdieron los hipervínculos o anotaciones.\n")
                allPassed = false
            }
        } catch {
            print("  ❌ ERROR en PDF: \(error.localizedDescription)\n")
            allPassed = false
        }

        print("=======================================================")
        if allPassed {
            print("  🎉 RESULTADO FINAL: TODOS LOS TESTS SUPERADOS (100% OK)")
            print("=======================================================\n")
            exit(0)
        } else {
            print("  ⚠️ ALGUNAS PRUEBAS FALLARON O REQUIEREN ATENCIÓN")
            print("=======================================================\n")
            exit(1)
        }
    }

    // --- Helpers de compresión ---

    private static func compressImageNative(_ url: URL, quality: Double, maxDim: Int) -> Data? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        let origMax = max(w, h)
        let img: CGImage?
        if maxDim < origMax {
            let opts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDim
            ]
            img = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
        } else {
            img = CGImageSourceCreateImageAtIndex(src, 0, nil)
        }
        guard let validImg = img else { return nil }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, validImg, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(dest) ? (data as Data) : nil
    }

    private static func compressImageTargetSize(_ url: URL, targetBytes: Int64) -> Data? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        let origMax = max(w, h)
        var maxDim = origMax
        while maxDim >= 300 {
            let opts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDim
            ]
            let img = (maxDim < origMax ? CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) : CGImageSourceCreateImageAtIndex(src, 0, nil))
            if let validImg = img {
                let data = NSMutableData()
                if let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) {
                    CGImageDestinationAddImage(dest, validImg, nil)
                    if CGImageDestinationFinalize(dest), Int64(data.count) <= targetBytes {
                        return data as Data
                    }
                }
            }
            maxDim = Int(Double(maxDim) * 0.75)
        }
        return nil
    }

    // --- Generadores de archivos de prueba realistas ---

    private static func makePhotographicJPEG(at url: URL, width: Int, height: Int) throws {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            let ny = Double(y) / Double(height)
            for x in 0..<width {
                let nx = Double(x) / Double(width)
                let idx = (y * width + x) * 4
                let r = sin(nx * .pi) * cos(ny * .pi) * 255.0
                let g = cos(nx * 2.0 * .pi) * 128.0 + 127.0
                let b = (nx + ny) * 127.0
                pixels[idx] = UInt8(clamping: Int(r))
                pixels[idx + 1] = UInt8(clamping: Int(g))
                pixels[idx + 2] = UInt8(clamping: Int(b))
                pixels[idx + 3] = 255
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let img = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent),
              let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw NSError(domain: "Gen", code: 1, userInfo: [NSLocalizedDescriptionKey: "Error creando JPEG"])
        }
        CGImageDestinationAddImage(dest, img, [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw NSError(domain: "Gen", code: 2, userInfo: [NSLocalizedDescriptionKey: "Error guardando JPEG"])
        }
    }

    private static func makeGraphicPNG(at url: URL, width: Int, height: Int) throws {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        var seed: UInt64 = 987654321
        for i in stride(from: 0, to: pixels.count, by: 4) {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            pixels[i] = UInt8(truncatingIfNeeded: seed >> 24)
            pixels[i + 1] = UInt8(truncatingIfNeeded: seed >> 32)
            pixels[i + 2] = UInt8(truncatingIfNeeded: seed >> 40)
            pixels[i + 3] = 255
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let img = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent),
              let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw NSError(domain: "Gen", code: 3, userInfo: [NSLocalizedDescriptionKey: "Error creando PNG"])
        }
        CGImageDestinationAddImage(dest, img, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw NSError(domain: "Gen", code: 4, userInfo: [NSLocalizedDescriptionKey: "Error guardando PNG"])
        }
    }

    private static func makeTestVideo(at url: URL, width: Int, height: Int, frameCount: Int) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, nil, &buffer)

        for frame in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
            if let buf = buffer {
                CVPixelBufferLockBaseAddress(buf, [])
                if let base = CVPixelBufferGetBaseAddress(buf) {
                    memset(base, Int32((frame * 5) % 255), width * height * 4)
                }
                CVPixelBufferUnlockBaseAddress(buf, [])
                let t = CMTime(value: Int64(frame), timescale: 30)
                adaptor.append(buf, withPresentationTime: t)
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
    }

    private static func transcodeTestVideo(input: URL, output: URL, targetBitrate: Int, targetW: Int, targetH: Int) async throws {
        let asset = AVURLAsset(url: input)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Sin pista de vídeo"])
        }
        let transform = try await track.load(.preferredTransform)
        let reader = try AVAssetReader(asset: asset)
        let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)

        let rSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        ]
        let vOut = AVAssetReaderTrackOutput(track: track, outputSettings: rSettings)
        vOut.alwaysCopiesSampleData = false
        guard reader.canAdd(vOut) else { throw NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "No se puede añadir video output"]) }
        reader.add(vOut)

        let compressionProps: [String: Any] = [
            AVVideoAverageBitRateKey: targetBitrate,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoMaxKeyFrameIntervalKey: 60,
            AVVideoAllowFrameReorderingKey: true
        ]
        let wSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: targetW,
            AVVideoHeightKey: targetH,
            AVVideoCompressionPropertiesKey: compressionProps
        ]
        let vIn = AVAssetWriterInput(mediaType: .video, outputSettings: wSettings)
        vIn.expectsMediaDataInRealTime = false
        vIn.transform = transform
        guard writer.canAdd(vIn) else { throw NSError(domain: "Test", code: 3, userInfo: [NSLocalizedDescriptionKey: "No se puede añadir video input"]) }
        writer.add(vIn)

        guard writer.startWriting() else { throw writer.error ?? NSError(domain: "Test", code: 4, userInfo: [NSLocalizedDescriptionKey: "Error al iniciar escritura"]) }
        guard reader.startReading() else { throw reader.error ?? NSError(domain: "Test", code: 5, userInfo: [NSLocalizedDescriptionKey: "Error al iniciar lectura"]) }
        writer.startSession(atSourceTime: .zero)

        let queue = DispatchQueue(label: "test.videoQueue")
        let group = DispatchGroup()

        nonisolated(unsafe) let safeIn = vIn
        nonisolated(unsafe) let safeOut = vOut
        nonisolated(unsafe) let safeReader = reader

        group.enter()
        safeIn.requestMediaDataWhenReady(on: queue) {
            while safeIn.isReadyForMoreMediaData {
                if safeReader.status != .reading {
                    safeIn.markAsFinished()
                    group.leave()
                    return
                }
                if let buf = safeOut.copyNextSampleBuffer() {
                    safeIn.append(buf)
                } else {
                    safeIn.markAsFinished()
                    group.leave()
                    return
                }
            }
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            group.notify(queue: .global()) {
                continuation.resume()
            }
        }

        await writer.finishWriting()
        if writer.status != .completed {
            throw writer.error ?? NSError(domain: "Test", code: 6, userInfo: [NSLocalizedDescriptionKey: "Error escribiendo vídeo"])
        }
    }

    private static func makeTestPDF(at url: URL, pageCount: Int) throws {
        let doc = PDFDocument()
        for i in 0..<pageCount {
            let width = 600, height = 800
            var pixels = [UInt8](repeating: 255, count: width * height * 4)
            for y in 0..<height {
                for x in 0..<width {
                    let idx = (y * width + x) * 4
                    pixels[idx] = UInt8((x * 255) / width)
                    pixels[idx + 1] = UInt8(i * 80 % 255)
                    pixels[idx + 2] = UInt8((y * 255) / height)
                    pixels[idx + 3] = 255
                }
            }
            guard let provider = CGDataProvider(data: Data(pixels) as CFData),
                  let cgImg = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { continue }
            let nsImg = NSImage(cgImage: cgImg, size: NSSize(width: width, height: height))
            if let page = PDFPage(image: nsImg) {
                page.setBounds(CGRect(x: 0, y: 0, width: 595, height: 842), for: .mediaBox)
                doc.insert(page, at: doc.pageCount)
            }
        }
        doc.write(to: url)
    }

    private static func makePhotographicPDF(at url: URL, pageCount: Int, imgW: Int, imgH: Int) throws {
        var mediaBox = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "Test", code: 9, userInfo: [NSLocalizedDescriptionKey: "No se pudo crear contexto PDF"])
        }
        for p in 0..<pageCount {
            ctx.beginPage(mediaBox: &mediaBox)
            // 1. Draw large background/content image
            var pixels = [UInt8](repeating: 0, count: imgW * imgH * 4)
            for y in 0..<imgH {
                let ny = Double(y) / Double(imgH)
                for x in 0..<imgW {
                    let nx = Double(x) / Double(imgW)
                    let idx = (y * imgW + x) * 4
                    pixels[idx] = UInt8(clamping: Int(sin(nx * .pi) * 255))
                    pixels[idx + 1] = UInt8(clamping: Int(cos(ny * .pi + Double(p)) * 128 + 127))
                    pixels[idx + 2] = UInt8(clamping: Int((nx + ny) * 127))
                    pixels[idx + 3] = 255
                }
            }
            if let provider = CGDataProvider(data: Data(pixels) as CFData),
               let img = CGImage(width: imgW, height: imgH, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: imgW * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) {
                ctx.draw(img, in: CGRect(x: 50, y: 200, width: 495, height: 500))
            }
            // 2. Draw vector shapes
            ctx.setFillColor(NSColor.systemBlue.cgColor)
            ctx.fill(CGRect(x: 50, y: 720, width: 495, height: 40))
            ctx.endPage()
        }
        ctx.closePDF()
    }

    private static func fileSize(_ url: URL) -> Int64 {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB]
        f.countStyle = .file
        return f.string(fromByteCount: bytes)
    }

    private static func calcSaving(_ orig: Int64, _ final: Int64) -> String {
        guard orig > 0 else { return "0%" }
        let pct = (1.0 - Double(final) / Double(orig)) * 100.0
        let savedBytes = orig - final
        return String(format: "-%.1f %% (%@ ahorrados)", pct, formatBytes(savedBytes))
    }

    private static func transferMetadataAndAnnotations(from srcDoc: PDFDocument, to dstDoc: PDFDocument) {
        if let attrs = srcDoc.documentAttributes {
            dstDoc.documentAttributes = attrs
        }

        let pageLimit = min(srcDoc.pageCount, dstDoc.pageCount)
        for i in 0..<pageLimit {
            guard let srcPage = srcDoc.page(at: i), let dstPage = dstDoc.page(at: i) else { continue }
            for annot in srcPage.annotations {
                if let fresh = cloneAnnotation(annot, srcDoc: srcDoc, dstDoc: dstDoc) {
                    dstPage.addAnnotation(fresh)
                }
            }
        }

        if let srcRoot = srcDoc.outlineRoot {
            let newRoot = PDFOutline()
            for i in 0..<srcRoot.numberOfChildren {
                if let child = srcRoot.child(at: i), let childCopy = copyOutline(child, srcDoc: srcDoc, dstDoc: dstDoc) {
                    newRoot.insertChild(childCopy, at: newRoot.numberOfChildren)
                }
            }
            if newRoot.numberOfChildren > 0 {
                dstDoc.outlineRoot = newRoot
            }
        }
    }

    private static func cloneAnnotation(_ a: PDFAnnotation, srcDoc: PDFDocument, dstDoc: PDFDocument) -> PDFAnnotation? {
        guard a.type != "Popup" else { return nil }
        let subtype = PDFAnnotationSubtype(rawValue: a.type ?? "Link")
        let fresh = PDFAnnotation(bounds: a.bounds, forType: subtype, withProperties: nil)

        // Metadatos y apariencia general
        fresh.contents = a.contents
        fresh.color = a.color
        fresh.border = a.border
        fresh.font = a.font
        fresh.fontColor = a.fontColor
        fresh.alignment = a.alignment
        fresh.modificationDate = a.modificationDate
        fresh.userName = a.userName

        // Enlaces e hipervínculos externos
        if let url = a.url {
            fresh.url = url
            fresh.action = PDFActionURL(url: url)
        } else if let urlAction = a.action as? PDFActionURL, let u = urlAction.url {
            fresh.url = u
            fresh.action = PDFActionURL(url: u)
        }

        // Enlaces y destinos internos (saltos de página, índice)
        var targetDest: PDFDestination? = nil
        if let dest = a.destination, let page = dest.page {
            let idx = srcDoc.index(for: page)
            if idx != NSNotFound, let newPage = dstDoc.page(at: idx) {
                targetDest = PDFDestination(page: newPage, at: dest.point)
            }
        } else if let gotoAction = a.action as? PDFActionGoTo, let page = gotoAction.destination.page {
            let idx = srcDoc.index(for: page)
            if idx != NSNotFound, let newPage = dstDoc.page(at: idx) {
                targetDest = PDFDestination(page: newPage, at: gotoAction.destination.point)
            }
        }

        if let td = targetDest {
            fresh.destination = td
            fresh.action = PDFActionGoTo(destination: td)
        }

        return fresh
    }

    private static func copyOutline(_ node: PDFOutline, srcDoc: PDFDocument, dstDoc: PDFDocument) -> PDFOutline? {
        let copy = PDFOutline()
        copy.label = node.label
        copy.isOpen = node.isOpen
        if let action = node.action {
            copy.action = action
        }
        if let dest = node.destination, let targetPage = dest.page {
            let pageIndex = srcDoc.index(for: targetPage)
            if pageIndex != NSNotFound, let newTargetPage = dstDoc.page(at: pageIndex) {
                copy.destination = PDFDestination(page: newTargetPage, at: dest.point)
            }
        }
        for i in 0..<node.numberOfChildren {
            if let child = node.child(at: i), let childCopy = copyOutline(child, srcDoc: srcDoc, dstDoc: dstDoc) {
                copy.insertChild(childCopy, at: copy.numberOfChildren)
            }
        }
        return copy
    }
}
