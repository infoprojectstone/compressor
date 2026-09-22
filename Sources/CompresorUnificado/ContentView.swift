import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject private var model = CompressorModel.shared
    @AppStorage("appLanguage") private var languageRaw = AppLanguage.spanish.rawValue
    private var language: AppLanguage { AppLanguage(rawValue:languageRaw) ?? .spanish }
    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 210)
            Divider()
            VStack(spacing: 0) { header; Divider(); if model.jobs.isEmpty { empty } else { queue }; Divider(); footer }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onDrop(of: [.fileURL], isTargeted: $model.dropTargeted) { items in load(items); return true }
        .onOpenURL { url in model.handleIncoming([url]) }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) { AppMark(size: 38); Text("Compressor").font(.title3.bold()) }.padding(.bottom,28)
            Text(t("COMPRIMIR","COMPRESS")).font(.caption2.weight(.bold)).foregroundStyle(.secondary).padding(.horizontal,12)
            ForEach(ContentKind.allCases) { item in Button { model.kind=item } label: { Label(kindTitle(item),systemImage:item.icon).frame(maxWidth:.infinity,alignment:.leading).padding(.horizontal,12).padding(.vertical,11).contentShape(RoundedRectangle(cornerRadius:10)).background(model.kind == item ? item.accent.opacity(0.16) : .clear,in:RoundedRectangle(cornerRadius:10)).foregroundStyle(model.kind == item ? item.accent : .primary) }.buttonStyle(.plain).contentShape(RoundedRectangle(cornerRadius:10)).disabled(model.isWorking) }
            Spacer()
            VStack(alignment:.leading,spacing:6) { Label(t("Privado y local","Private and local"),systemImage:"lock.fill").font(.caption.weight(.semibold)); Text(t("Tus archivos nunca salen de tu Mac.","Your files never leave your Mac.")).font(.caption2).foregroundStyle(.secondary) }.padding(13).frame(maxWidth:.infinity,alignment:.leading).background(.quaternary.opacity(0.6),in:RoundedRectangle(cornerRadius:12))
        }.padding(18).background(.thinMaterial)
    }
    private var header: some View {
        HStack(alignment:.top) { VStack(alignment:.leading,spacing:5) { Text(t("Comprimir \(kindTitle(model.kind).lowercased())","Compress \(kindTitle(model.kind).lowercased())")).font(.title.bold()); Text(subtitle).foregroundStyle(.secondary) }; Spacer(); Button(t("Añadir archivos","Add files"),systemImage:"plus") { model.chooseFiles() }.buttonStyle(.borderedProminent).disabled(model.isWorking); Button(t("Carpeta","Folder"),systemImage:"folder.badge.plus") { model.chooseFolder() }.disabled(model.isWorking) }.padding(.horizontal,28).padding(.vertical,24)
    }
    private var subtitle: String { switch model.kind { case .image: t("Optimiza imágenes sin subirlas a Internet.","Optimize images without uploading them."); case .video: t("Reduce el peso con calidad a tu medida.","Reduce file size with the quality you choose."); case .pdf: t("Prepara documentos más ligeros para compartir.","Make documents lighter and easier to share.") } }
    private var empty: some View {
        VStack(spacing:16) { Spacer(); Image(systemName:model.dropTargeted ? "arrow.down.circle.fill" : model.kind.icon).font(.system(size:68,weight:.light)).foregroundStyle(model.dropTargeted ? model.kind.accent : .secondary); Text(model.dropTargeted ? t("Suelta los archivos aquí","Drop files here") : t("Arrastra \(kindTitle(model.kind).lowercased()) aquí","Drag \(kindTitle(model.kind).lowercased()) here")).font(.title2.weight(.semibold)); Text(emptyHelp).multilineTextAlignment(.center).foregroundStyle(.secondary); HStack { Button(t("Seleccionar archivos…","Select files…")) { model.chooseFiles() }.buttonStyle(.borderedProminent); Button(t("Seleccionar carpeta…","Select folder…")) { model.chooseFolder() } }; Spacer() }.frame(maxWidth:.infinity).background(model.dropTargeted ? model.kind.accent.opacity(0.07) : .clear)
    }
    private var emptyHelp: String { switch model.kind { case .image: t("JPG, PNG, WebP, HEIC y HEIF\nSolo se conserva el resultado si ocupa menos.","JPG, PNG, WebP, HEIC and HEIF\nThe result is kept only when it is smaller."); case .video: t("MP4, MOV y M4V\nProcesamiento nativo con aceleración por hardware.","MP4, MOV and M4V\nNative processing with hardware acceleration."); case .pdf: t("PDF individuales o carpetas completas\nOptimización nativa 100% local.","Individual PDFs or entire folders\n100% local native optimization.") } }
    private var queue: some View {
        VStack(spacing:0) { if model.isWorking { VStack(alignment:.leading,spacing:7) { HStack { Text(t("Comprimiendo \(Int(model.progress * Double(model.jobs.count))) de \(model.jobs.count)","Compressing \(Int(model.progress * Double(model.jobs.count))) of \(model.jobs.count)")).fontWeight(.medium); Spacer(); Text("\(Int(model.progress * 100)) %").monospacedDigit().foregroundStyle(.secondary) }; ProgressView(value:model.progress).tint(model.kind.accent) }.padding(20) }; Table(model.jobs) { TableColumn(t("Archivo","File")) { job in HStack(spacing:8) { Image(systemName:job.kind.icon).foregroundStyle(job.kind.accent); VStack(alignment:.leading,spacing:3) { Text(job.url.lastPathComponent).lineLimit(1); if case .failed(let e) = job.status { Text(e).font(.caption).foregroundStyle(.red).lineLimit(1) } } } }.width(min:250,ideal:360); TableColumn(t("Original","Original")) { Text(Format.bytes($0.originalBytes)).monospacedDigit() }.width(min:95,ideal:110); TableColumn(t("Final","Final")) { Text(Format.bytes($0.finalBytes)).monospacedDigit() }.width(min:95,ideal:110); TableColumn(t("Ahorro","Savings")) { job in Text(saving(job)).monospacedDigit().foregroundStyle(savingColor(job)) }.width(min:85,ideal:100); TableColumn(t("Estado","Status")) { job in Label(statusLabel(job.status),systemImage:job.status.icon).foregroundStyle(statusColor(job.status)) }.width(min:125,ideal:140) } }
    }
    private var footer: some View {
        VStack(spacing: 16) {
            settings
            HStack {
                if let msg = model.message {
                    Text(msg).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                }
                if model.showTimer {
                    Label(model.elapsedText, systemImage: "timer")
                        .font(.callout.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(model.isPaused ? Color.orange : Color.secondary)
                }
                Spacer()
                Button(t("Limpiar", "Clear")) { model.clear() }.disabled(model.isWorking || model.jobs.isEmpty)
                Button(t("Mostrar resultados", "Show results"), systemImage: "folder") { model.reveal() }.disabled(model.jobs.allSatisfy { $0.result == nil })
                if model.isWorking {
                    Button(model.isPaused ? t("Reanudar", "Resume") : t("Pausa", "Pause"), systemImage: model.isPaused ? "play.fill" : "pause.fill") { model.togglePause() }.controlSize(.large)
                }
                Button(model.isWorking ? t("Comprimiendo…", "Compressing…") : t("Comprimir", "Compress"), systemImage: "arrow.down.to.line.compact") {
                    model.process()
                }
                .buttonStyle(.borderedProminent)
                .tint(model.kind.accent)
                .disabled(model.isWorking || model.jobs.isEmpty)
            }
            .padding(.horizontal, 22)
        }
        .padding(.vertical, 16)
    }

    @ViewBuilder private var settings: some View {
        VStack(spacing: 12) {
            // Modo arriba (sin etiqueta "Modo")
            Picker("", selection: $model.compressionMode) {
                Text(t("Calidad", "Quality")).tag(CompressionMode.quality)
                Text(t("Tamaño objetivo", "Target size")).tag(CompressionMode.targetSize)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 250)

            // Calidad / Tamaño objetivo en medio con altura fija para evitar saltos
            Group {
                if model.compressionMode == .quality {
                    Picker("", selection: $model.compressionQuality) {
                        Text(t("Alta calidad", "High quality")).tag(CompressionQuality.high)
                        Text(t("Equilibrado", "Balanced")).tag(CompressionQuality.balanced)
                        Text(t("Tamaño pequeño", "Small size")).tag(CompressionQuality.small)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 360)
                } else {
                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            TextField("5", value: $model.targetSizeMB, format: .number.precision(.fractionLength(0...2)))
                                .frame(width: 65)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.center)
                            Text("MB " + t("aprox.", "approx."))
                                .foregroundStyle(.secondary)
                        }
                        Text(t("El tamaño final es orientativo y puede variar según el contenido y el formato.", "The final size is approximate and may vary depending on the content and format."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 48)

            // Opciones de vídeo
            if model.kind == .video || model.jobs.contains(where: { $0.kind == .video }) {
                HStack(spacing: 18) {
                    Picker(t("Formato", "Format"), selection: $model.videoFormat) {
                        Text("MP4").tag("mp4")
                        Text("MOV").tag("mov")
                    }
                    .frame(width: 120)

                    Picker(t("Resolución", "Resolution"), selection: $model.videoResolution) {
                        Text(t("Auto (máx. 1080p)", "Auto (max. 1080p)")).tag("Auto (máx. 1080p)")
                        Text("720p").tag("720p")
                        Text("1080p").tag("1080p")
                        Text(t("Original", "Original")).tag("Original")
                    }
                    .frame(width: 230)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 22)
    }
    private func saving(_ job: Job) -> String { guard let final=job.finalBytes, job.originalBytes > 0 else { return "—" }; return String(format:"%.0f %%",(1-Double(final)/Double(job.originalBytes))*100) }
    private func savingColor(_ job: Job) -> Color { guard let final=job.finalBytes else{return .secondary}; return final < job.originalBytes ? .green : .secondary }
    private func statusColor(_ s: JobStatus) -> Color { switch s { case .done: .green; case .failed: .red; case .processing: model.kind.accent; default:.secondary } }
    private func t(_ es:String,_ en:String) -> String { tr(es,en,language:language) }
    private func kindTitle(_ kind:ContentKind) -> String { switch kind { case .image:t("Imágenes","Images"); case .video:t("Vídeos","Videos"); case .pdf:"PDF" } }
    private func statusLabel(_ status:JobStatus) -> String { switch status { case .waiting:t("Pendiente","Waiting"); case .processing:t("Procesando…","Processing…"); case .done:t("Comprimido","Compressed"); case .skipped:t("Sin mejora","No improvement"); case .failed:t("Error","Error") } }
    private func load(_ providers:[NSItemProvider]) { for p in providers { p.loadItem(forTypeIdentifier:UTType.fileURL.identifier,options:nil) { v,_ in let url=(v as? Data).flatMap { URL(dataRepresentation:$0,relativeTo:nil) } ?? (v as? URL); if let url { DispatchQueue.main.async { model.add([url], allowMixed: true) } } } } }
}

struct AppMark: View {
    let size: CGFloat
    var body: some View {
        Image(systemName:"arrow.down.to.line.compact")
            .font(.system(size:size * 0.55,weight:.bold))
            .foregroundStyle(.white)
        .frame(width:size,height:size)
        .background(
            LinearGradient(
                colors:[Color(red:0.03,green:0.20,blue:0.52),Color(red:0.05,green:0.43,blue:0.87)],
                startPoint:.topLeading,
                endPoint:.bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius:size * 0.30,style:.continuous))
        .shadow(color:.blue.opacity(0.25),radius:5,y:2)
    }
}
