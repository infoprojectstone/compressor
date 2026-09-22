import AppKit
import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import Quartz
import SwiftUI
import UniformTypeIdentifiers

enum ContentKind: String, CaseIterable, Identifiable, Sendable {
    case image, video, pdf
    var id: String { rawValue }
    var title: String { switch self { case .image: "Imágenes"; case .video: "Vídeos"; case .pdf: "PDF" } }
    var icon: String { switch self { case .image: "photo"; case .video: "film"; case .pdf: "doc.richtext" } }
    var extensions: Set<String> {
        switch self {
        case .image: ["jpg", "jpeg", "png", "webp", "heic", "heif"]
        case .video: ["mp4", "mov", "m4v"]
        case .pdf: ["pdf"]
        }
    }
    var accent: Color { switch self { case .image: .purple; case .video: .pink; case .pdf: .orange } }
}

enum JobStatus: Equatable { case waiting, processing, done, skipped, failed(String)
    var label: String { switch self { case .waiting: "Pendiente"; case .processing: "Procesando…"; case .done: "Comprimido"; case .skipped: "Sin mejora"; case .failed: "Error" } }
    var icon: String { switch self { case .waiting: "clock"; case .processing: "arrow.triangle.2.circlepath"; case .done: "checkmark.circle.fill"; case .skipped: "forward.fill"; case .failed: "exclamationmark.triangle.fill" } }
}

enum CompressionMode: String, CaseIterable, Identifiable, Sendable {
    case quality, targetSize
    var id: String { rawValue }
}

enum OutputDestination: String, CaseIterable, Identifiable, Sendable {
    case subfolder, besideOriginal, customFolder
    var id: String { rawValue }
}

struct Job: Identifiable { let id = UUID(); let url: URL; let originalBytes: Int64; var finalBytes: Int64?; var result: URL?; var status: JobStatus = .waiting }
struct CompressionConfig: Sendable {
    let kind: ContentKind
    let mode: CompressionMode
    let quality: CompressionQuality
    let targetSizeMB: Double
    let videoFormat: String
    let videoResolution: String
    let outputDestination: OutputDestination
    let customOutputFolder: URL?
}

enum Format { static func bytes(_ n: Int64?) -> String { guard let n else { return "—" }; let f = ByteCountFormatter(); f.allowedUnits = [.useKB,.useMB,.useGB]; f.countStyle = .file; return f.string(fromByteCount: n) } }

@MainActor final class CompressorModel: ObservableObject {
    static let shared = CompressorModel()

    @Published var kind: ContentKind = .image { didSet { clear() } }
    @Published var jobs: [Job] = []
    @Published var isWorking = false
    @Published var progress = 0.0
    @Published var dropTargeted = false
    @Published var message: String?
    @Published var compressionMode: CompressionMode = .quality
    @Published var compressionQuality: CompressionQuality = .balanced
    @Published var targetSizeMB = 5.0
    @Published var videoFormat = "mp4"
    @Published var videoResolution = "Auto (máx. 1080p)"
    @Published var elapsedText = "0:00"
    @Published var isPaused = false
    @Published var showTimer = false
    private var accumulatedSeconds: TimeInterval = 0
    private var lastResumeDate: Date?
    private var timer: Timer?
    private var compressionControl: CompressionControl?

    func chooseFiles() {
        let type = Self.localizedKind(kind).lowercased()
        let panel = NSOpenPanel(); panel.title = tr("Selecciona \(type)", "Select \(type)"); panel.prompt = tr("Añadir", "Add"); panel.allowsMultipleSelection = true; panel.canChooseFiles = true; panel.canChooseDirectories = false
        if panel.runModal() == .OK { add(panel.urls) }
    }
    func chooseFolder() { let panel = NSOpenPanel(); panel.title = tr("Selecciona una carpeta", "Select a folder"); panel.prompt = tr("Añadir", "Add"); panel.canChooseFiles = false; panel.canChooseDirectories = true; if panel.runModal() == .OK { add(panel.urls) } }
    func clear() {
        guard !isWorking else { return }
        jobs = []
        progress = 0
        message = nil
        showTimer = false
        elapsedText = "0:00"
        accumulatedSeconds = 0
        lastResumeDate = nil
    }
    func add(_ urls: [URL]) {
        guard !isWorking else { return }
        showTimer = false
        elapsedText = "0:00"
        accumulatedSeconds = 0
        lastResumeDate = nil
        let existing = Set(jobs.map { $0.url.standardizedFileURL })
        let files = discover(urls).filter { !existing.contains($0.standardizedFileURL) }
        jobs += files.map { Job(url: $0, originalBytes: Self.size($0)) }
        message = files.isEmpty ? tr("No se encontraron archivos compatibles nuevos.", "No new compatible files were found.") : nil
    }
    func handleIncoming(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        var imageCount = 0
        var videoCount = 0
        var pdfCount = 0
        let fm = FileManager.default

        for url in urls {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: url.path, isDirectory: &isDir) {
                if !isDir.boolValue {
                    let ext = url.pathExtension.lowercased()
                    if ContentKind.image.extensions.contains(ext) { imageCount += 1 }
                    else if ContentKind.video.extensions.contains(ext) { videoCount += 1 }
                    else if ContentKind.pdf.extensions.contains(ext) { pdfCount += 1 }
                } else if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                    for case let fileURL as URL in enumerator {
                        let ext = fileURL.pathExtension.lowercased()
                        if ContentKind.image.extensions.contains(ext) { imageCount += 1 }
                        else if ContentKind.video.extensions.contains(ext) { videoCount += 1 }
                        else if ContentKind.pdf.extensions.contains(ext) { pdfCount += 1 }
                    }
                }
            }
        }

        if videoCount > imageCount && videoCount > pdfCount {
            self.kind = .video
        } else if pdfCount > imageCount && pdfCount > videoCount {
            self.kind = .pdf
        } else if imageCount > 0 {
            self.kind = .image
        }

        self.add(urls)
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) ?? NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
    func reveal() { let output = jobs.compactMap(\.result); guard !output.isEmpty else { return }; NSWorkspace.shared.activateFileViewerSelecting(output) }
    func togglePause() {
        guard isWorking else { return }
        isPaused.toggle()
        compressionControl?.setPaused(isPaused)
        if isPaused {
            pauseTimer()
            message = tr("Compresión pausada.", "Compression paused.")
        } else {
            resumeTimer()
            message = tr("Compresión reanudada.", "Compression resumed.")
        }
    }
    func process() {
        guard !jobs.isEmpty, !isWorking else { return }
        if compressionMode == .targetSize && targetSizeMB < 0.05 { message = tr("Indica un tamaño objetivo válido.", "Enter a valid target size."); return }
        let outputDestination = OutputDestination(rawValue:UserDefaults.standard.string(forKey:"outputDestination") ?? "subfolder") ?? .subfolder
        let customFolder = Self.customOutputFolder()
        if outputDestination == .customFolder && customFolder == nil { message = tr("Elige una carpeta personalizada en Ajustes.", "Choose a custom folder in Settings."); return }
        isWorking=true; isPaused=false; progress=0; message=nil
        let control = CompressionControl(); compressionControl = control
        startTimer(); DockProgress.update(0)
        for i in jobs.indices { jobs[i].status = .waiting; jobs[i].finalBytes=nil; jobs[i].result=nil }
        let config = CompressionConfig(kind:kind, mode:compressionMode, quality:compressionQuality, targetSizeMB:targetSizeMB, videoFormat:videoFormat, videoResolution:videoResolution, outputDestination:outputDestination, customOutputFolder:customFolder)
        Task { @MainActor in
            let accessedCustomFolder = customFolder?.startAccessingSecurityScopedResource() ?? false
            defer { if accessedCustomFolder { customFolder?.stopAccessingSecurityScopedResource() } }
            for index in jobs.indices {
                jobs[index].status = .processing
                let input = jobs[index].url; let original = jobs[index].originalBytes
                do {
                    let videoDuration: Double?
                    if config.kind == .video && config.mode == .targetSize {
                        videoDuration = CMTimeGetSeconds(try await AVURLAsset(url:input).load(.duration))
                    } else {
                        videoDuration = nil
                    }
                    let output = try await Task.detached(priority: .userInitiated) {
                        try await Self.compress(input, config:config, videoDuration:videoDuration, control:control)
                    }.value
                    let finalBytes = Self.size(output)
                    jobs[index].finalBytes = finalBytes
                    jobs[index].result = output == input ? nil : output
                    jobs[index].status = finalBytes < original ? .done : .skipped
                } catch { jobs[index].status = .failed(error.localizedDescription) }
                progress = Double(index + 1) / Double(jobs.count); DockProgress.update(progress)
            }
            control.setPaused(false); compressionControl=nil; isPaused=false
            stopTimer()
            isWorking=false; DockProgress.clear(); message = tr("Terminado. Los originales no se han modificado.", "Finished. The original files were not modified.")
        }
    }
    private func discover(_ urls: [URL]) -> [URL] {
        let fm = FileManager.default; var result = Set<URL>()
        for url in urls { var dir: ObjCBool=false; guard fm.fileExists(atPath:url.path,isDirectory:&dir) else { continue }
            if dir.boolValue, let e=fm.enumerator(at:url, includingPropertiesForKeys:[.isDirectoryKey,.isRegularFileKey,.isSymbolicLinkKey], options:[.skipsHiddenFiles,.skipsPackageDescendants]) {
                while let f = e.nextObject() as? URL {
                    let values = try? f.resourceValues(forKeys:[.isDirectoryKey,.isRegularFileKey,.isSymbolicLinkKey])
                    if values?.isDirectory == true {
                        if ["Imágenes comprimidas", "Comprimidos", "comprimidos", "Compressed", "compressed"].contains(f.lastPathComponent) { e.skipDescendants() }
                        continue
                    }
                    guard values?.isRegularFile == true, values?.isSymbolicLink != true else { continue }
                    if kind.extensions.contains(f.pathExtension.lowercased()) { result.insert(f.standardizedFileURL) }
                }
            }
            else if kind.extensions.contains(url.pathExtension.lowercased()) { result.insert(url.standardizedFileURL) }
        }; return result.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }
    nonisolated private static func size(_ url: URL) -> Int64 { (try? url.resourceValues(forKeys:[.fileSizeKey]).fileSize).map(Int64.init) ?? 0 }
    nonisolated private static func localizedKind(_ kind:ContentKind) -> String { switch kind { case .image:tr("Imágenes","Images"); case .video:tr("Vídeos","Videos"); case .pdf:"PDF" } }
    private func startTimer() {
        accumulatedSeconds = 0
        lastResumeDate = Date()
        elapsedText = "0:00"
        showTimer = true
        scheduleTimer()
    }
    private func pauseTimer() {
        if let last = lastResumeDate {
            accumulatedSeconds += Date().timeIntervalSince(last)
            lastResumeDate = nil
        }
        timer?.invalidate()
        timer = nil
        updateElapsedText()
    }
    private func resumeTimer() {
        lastResumeDate = Date()
        scheduleTimer()
    }
    private func stopTimer() {
        if let last = lastResumeDate {
            accumulatedSeconds += Date().timeIntervalSince(last)
            lastResumeDate = nil
        }
        timer?.invalidate()
        timer = nil
        updateElapsedText()
    }
    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateElapsedText()
            }
        }
    }
    private func updateElapsedText() {
        var total = accumulatedSeconds
        if let last = lastResumeDate {
            total += Date().timeIntervalSince(last)
        }
        let seconds = Int(total)
        elapsedText = String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
    private static func customOutputFolder() -> URL? {
        guard let data = UserDefaults.standard.data(forKey:"customOutputFolderBookmark") else { return nil }
        var stale = false
        return try? URL(resolvingBookmarkData:data, options:.withSecurityScope, relativeTo:nil, bookmarkDataIsStale:&stale)
    }
    nonisolated private static func unique(_ url: URL, directory: URL, suffix: String, ext: String) -> URL { var number=0; var output: URL; repeat { let tail = number == 0 ? suffix : "\(suffix)_\(number)"; output=directory.appendingPathComponent(url.deletingPathExtension().lastPathComponent + tail).appendingPathExtension(ext); number += 1 } while FileManager.default.fileExists(atPath:output.path); return output }
    nonisolated private static func outputDirectory(for url: URL, config: CompressionConfig) throws -> URL {
        let directory: URL
        switch config.outputDestination {
        case .subfolder: directory = url.deletingLastPathComponent().appendingPathComponent(tr("Comprimidos", "Compressed"), isDirectory:true)
        case .besideOriginal: directory = url.deletingLastPathComponent()
        case .customFolder:
            guard let custom = config.customOutputFolder else { throw NSError(domain:"Compressor",code:3,userInfo:[NSLocalizedDescriptionKey:tr("No se puede acceder a la carpeta personalizada.", "The custom folder is not accessible.")]) }
            directory = custom
        }
        try FileManager.default.createDirectory(at:directory, withIntermediateDirectories:true)
        return directory
    }
    nonisolated static func compress(_ url: URL, config: CompressionConfig, videoDuration: Double?, control: CompressionControl) async throws -> URL {
        let output: URL
        switch config.kind {
        case .image: output = try compressImage(url, config:config, control:control)
        case .video: output = try await compressVideo(url, config:config, duration:videoDuration, control:control)
        case .pdf: output = try compressPDF(url, config:config, control:control)
        }
        guard output == url || size(output) > 0 else {
            try? FileManager.default.removeItem(at: output)
            throw NSError(domain:"Compressor", code:2, userInfo:[NSLocalizedDescriptionKey:tr("El compresor no generó un archivo válido.", "The compressor did not produce a valid file.")])
        }
        if output != url && size(output) >= size(url) {
            try? FileManager.default.removeItem(at: output)
            return url
        }
        return output
    }
    nonisolated private static func compressImage(_ url: URL, config: CompressionConfig, control: CompressionControl) throws -> URL {
        let data = try config.mode == .targetSize
            ? SafeImageCompressor.compress(url, targetMB:config.targetSizeMB, control:control)
            : SafeImageCompressor.compress(url, quality:config.quality, control:control)
        guard let data else { return url }
        let folder = try outputDirectory(for:url, config:config)
        let out = unique(url, directory:folder, suffix:"_comprimido", ext:SafeImageCompressor.outputExtension(for:url))
        try data.write(to:out, options:.atomic)
        return out
    }
    nonisolated private static func compressVideo(_ url: URL, config: CompressionConfig, duration: Double?, control: CompressionControl) async throws -> URL {
        let folder = try outputDirectory(for:url, config:config)
        let format = config.videoFormat.lowercased() == "mov" ? "mov" : "mp4"
        let out = unique(url, directory:folder, suffix:"_comprimido", ext:format)
        let asset = AVURLAsset(url:url)
        let outputFileType: AVFileType = format == "mov" ? .mov : .mp4

        let durationSeconds: Double = if let d = duration, d > 0 { d } else {
            (try? CMTimeGetSeconds(await asset.load(.duration))) ?? 10.0
        }

        do {
            return try await transcodeVideoWithWriter(asset: asset, out: out, format: format, outputFileType: outputFileType, config: config, durationSeconds: durationSeconds, control: control)
        } catch {
            return try await exportFallback(asset: asset, out: out, format: format, outputFileType: outputFileType, config: config)
        }
    }

    nonisolated private static func transcodeVideoWithWriter(asset: AVURLAsset, out: URL, format: String, outputFileType: AVFileType, config: CompressionConfig, durationSeconds: Double, control: CompressionControl) async throws -> URL {
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain:"Compressor", code:1, userInfo:[NSLocalizedDescriptionKey:tr("El archivo no contiene una pista de vídeo.", "File has no video track.")])
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let transform = try await videoTrack.load(.preferredTransform)
        let origW = max(16, Int(naturalSize.width))
        let origH = max(16, Int(naturalSize.height))

        var maxDim = 1920
        if config.videoResolution.contains("720") {
            maxDim = 1280
        } else if config.videoResolution.contains("1080") {
            maxDim = 1920
        } else if config.videoResolution.contains("540") {
            maxDim = 960
        } else if config.videoResolution == "Original" {
            maxDim = max(origW, origH)
        } else {
            switch config.quality {
            case .high: maxDim = max(origW, origH)
            case .balanced: maxDim = max(origW, origH) > 1920 ? 1920 : max(origW, origH)
            case .small: maxDim = 1280
            }
        }

        var targetW = origW
        var targetH = origH
        let curMax = max(origW, origH)
        if curMax > maxDim {
            let scale = Double(maxDim) / Double(curMax)
            targetW = Int(Double(origW) * scale)
            targetH = Int(Double(origH) * scale)
        }
        targetW = max(16, targetW & ~1)
        targetH = max(16, targetH & ~1)

        let targetBitrate: Int
        let audioBitrate: Int = config.mode == .targetSize && config.targetSizeMB < 5.0 ? 64_000 : 128_000

        switch config.mode {
        case .quality:
            let pixels = targetW * targetH
            if pixels >= 3840 * 1800 {
                switch config.quality {
                case .high: targetBitrate = 16_000_000
                case .balanced: targetBitrate = 9_500_000
                case .small: targetBitrate = 4_500_000
                }
            } else if pixels >= 1920 * 900 {
                switch config.quality {
                case .high: targetBitrate = 6_500_000
                case .balanced: targetBitrate = 3_800_000
                case .small: targetBitrate = 1_800_000
                }
            } else if pixels >= 1280 * 650 {
                switch config.quality {
                case .high: targetBitrate = 3_800_000
                case .balanced: targetBitrate = 2_400_000
                case .small: targetBitrate = 1_100_000
                }
            } else {
                switch config.quality {
                case .high: targetBitrate = 2_000_000
                case .balanced: targetBitrate = 1_400_000
                case .small: targetBitrate = 700_000
                }
            }
        case .targetSize:
            let totalBits = Double(config.targetSizeMB) * 8_000_000.0
            let rawVideoBits = (totalBits * 0.90 / max(1.0, durationSeconds)) - Double(audioBitrate)
            targetBitrate = max(200_000, Int(rawVideoBits))
            if targetBitrate < 700_000 && max(targetW, targetH) > 1280 {
                targetW = max(16, Int(Double(targetW) * 0.67) & ~1)
                targetH = max(16, Int(Double(targetH) * 0.67) & ~1)
            }
        }

        let reader = try AVAssetReader(asset: asset)
        let writer = try AVAssetWriter(outputURL: out, fileType: outputFileType)

        let videoReaderSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        ]
        let videoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: videoReaderSettings)
        videoOutput.alwaysCopiesSampleData = false
        guard reader.canAdd(videoOutput) else { throw NSError(domain:"Compressor", code:2, userInfo:[NSLocalizedDescriptionKey:tr("No se pudo leer el vídeo.", "Could not read video.")]) }
        reader.add(videoOutput)

        let videoCompressionProps: [String: Any] = [
            AVVideoAverageBitRateKey: targetBitrate,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoMaxKeyFrameIntervalKey: 60,
            AVVideoAllowFrameReorderingKey: true
        ]
        let videoWriterSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: targetW,
            AVVideoHeightKey: targetH,
            AVVideoCompressionPropertiesKey: videoCompressionProps
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoWriterSettings)
        videoInput.expectsMediaDataInRealTime = false
        videoInput.transform = transform
        guard writer.canAdd(videoInput) else { throw NSError(domain:"Compressor", code:3, userInfo:[NSLocalizedDescriptionKey:tr("No se pudo iniciar el codificador de vídeo.", "Could not start video encoder.")]) }
        writer.add(videoInput)

        var audioOutput: AVAssetReaderTrackOutput?
        var audioInput: AVAssetWriterInput?
        if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first {
            let audioReaderSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM
            ]
            let aOut = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: audioReaderSettings)
            aOut.alwaysCopiesSampleData = false
            if reader.canAdd(aOut) {
                reader.add(aOut)
                audioOutput = aOut

                let audioWriterSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVNumberOfChannelsKey: 2,
                    AVSampleRateKey: 44100.0,
                    AVEncoderBitRateKey: audioBitrate
                ]
                let aIn = AVAssetWriterInput(mediaType: .audio, outputSettings: audioWriterSettings)
                aIn.expectsMediaDataInRealTime = false
                if writer.canAdd(aIn) {
                    writer.add(aIn)
                    audioInput = aIn
                }
            }
        }

        guard writer.startWriting() else {
            throw writer.error ?? NSError(domain:"Compressor", code:4, userInfo:[NSLocalizedDescriptionKey:tr("Error iniciando el archivo de vídeo.", "Error starting video file.")])
        }
        guard reader.startReading() else {
            throw reader.error ?? NSError(domain:"Compressor", code:5, userInfo:[NSLocalizedDescriptionKey:tr("Error leyendo el vídeo original.", "Error reading source video.")])
        }
        writer.startSession(atSourceTime: .zero)

        let videoQueue = DispatchQueue(label: "compresor.videoQueue")
        let group = DispatchGroup()

        nonisolated(unsafe) let safeVideoInput = videoInput
        nonisolated(unsafe) let safeVideoOutput = videoOutput
        nonisolated(unsafe) let safeReader = reader
        let safeControl = control

        group.enter()
        safeVideoInput.requestMediaDataWhenReady(on: videoQueue) {
            while safeVideoInput.isReadyForMoreMediaData {
                safeControl.waitIfPaused()
                if safeReader.status != .reading {
                    safeVideoInput.markAsFinished()
                    group.leave()
                    return
                }
                if let buffer = safeVideoOutput.copyNextSampleBuffer() {
                    safeVideoInput.append(buffer)
                } else {
                    safeVideoInput.markAsFinished()
                    group.leave()
                    return
                }
            }
        }

        if let audioInput, let audioOutput {
            let audioQueue = DispatchQueue(label: "compresor.audioQueue")
            nonisolated(unsafe) let safeAudioInput = audioInput
            nonisolated(unsafe) let safeAudioOutput = audioOutput

            group.enter()
            safeAudioInput.requestMediaDataWhenReady(on: audioQueue) {
                while safeAudioInput.isReadyForMoreMediaData {
                    safeControl.waitIfPaused()
                    if safeReader.status != .reading {
                        safeAudioInput.markAsFinished()
                        group.leave()
                        return
                    }
                    if let buffer = safeAudioOutput.copyNextSampleBuffer() {
                        safeAudioInput.append(buffer)
                    } else {
                        safeAudioInput.markAsFinished()
                        group.leave()
                        return
                    }
                }
            }
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            group.notify(queue: .global()) {
                continuation.resume()
            }
        }

        if reader.status == .failed {
            writer.cancelWriting()
            throw reader.error ?? NSError(domain:"Compressor", code:6, userInfo:[NSLocalizedDescriptionKey:tr("Error durante la lectura del vídeo.", "Error during video reading.")])
        }

        await writer.finishWriting()
        if writer.status == .failed {
            throw writer.error ?? NSError(domain:"Compressor", code:7, userInfo:[NSLocalizedDescriptionKey:tr("Error durante la compresión del vídeo.", "Error during video compression.")])
        }

        return out
    }

    nonisolated private static func exportFallback(asset: AVURLAsset, out: URL, format: String, outputFileType: AVFileType, config: CompressionConfig) async throws -> URL {
        let preset = switch config.quality {
        case .high: AVAssetExportPreset1920x1080
        case .balanced: AVAssetExportPreset1280x720
        case .small: AVAssetExportPresetLowQuality
        }
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw NSError(domain:"Compressor", code:8, userInfo:[NSLocalizedDescriptionKey:tr("Formato de vídeo no compatible.", "Unsupported video format.")])
        }
        session.outputURL = out
        session.outputFileType = outputFileType
        session.shouldOptimizeForNetworkUse = true
        nonisolated(unsafe) let exportSession = session
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed: continuation.resume()
                case .failed: continuation.resume(throwing: exportSession.error ?? NSError(domain:"Compressor", code:9, userInfo:[NSLocalizedDescriptionKey:tr("Error durante la exportación.", "Error during export.")]))
                case .cancelled: continuation.resume(throwing: CancellationError())
                default: continuation.resume(throwing: NSError(domain:"Compressor", code:10, userInfo:[NSLocalizedDescriptionKey:tr("Exportación no completada.", "Export not completed.")]))
                }
            }
        }
        return out
    }
    nonisolated private static func compressPDF(_ url: URL, config: CompressionConfig, control: CompressionControl) throws -> URL {
        let folder = try outputDirectory(for: url, config: config)
        return try SafePDFCompressor.compress(url, config: config, destinationFolder: folder, uniqueNamer: unique, control: control)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Enforce single instance: if another instance is already running, activate it and terminate self
        if let bundleID = Bundle.main.bundleIdentifier {
            let instances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            if let existing = instances.first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
                existing.activate(options: [.activateIgnoringOtherApps])
                NSApp.terminate(nil)
                return
            }
        }

        if let url = Bundle.main.url(forResource:"AppIconSource", withExtension:"png"),
           let icon = NSImage(contentsOf:url) {
            NSApp.applicationIconImage = icon
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        Task { @MainActor in
            CompressorModel.shared.handleIncoming(urls)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            if let window = sender.windows.first(where: { $0.canBecomeMain }) ?? sender.windows.first {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main struct CompresorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        Window("Compressor", id: "main") { ContentView().frame(minWidth:850,minHeight:620) }
            .windowStyle(.hiddenTitleBar)
            .defaultSize(width:1020,height:720)
            .commands {
                CommandGroup(replacing: .newItem) { }
            }
        Settings { SettingsView() }
    }
}
