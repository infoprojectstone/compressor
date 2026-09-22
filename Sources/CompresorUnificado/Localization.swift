import AppKit
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case spanish = "es"
    case english = "en"
    var id: String { rawValue }
    var name: String { switch self { case .spanish: "Español"; case .english: "English" } }
    static var current: AppLanguage {
        let value = UserDefaults.standard.string(forKey:"appLanguage") ?? "es"
        return AppLanguage(rawValue:value) ?? .spanish
    }
}

func tr(_ spanish: String, _ english: String, language: AppLanguage = .current) -> String {
    language == .spanish ? spanish : english
}

@MainActor
final class SettingsModel: ObservableObject {
    @Published var quickActionInstalled: Bool = false

    var userServicesWorkflowURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Services/Comprimir con Compresor.workflow")
    }

    func checkStatus() {
        quickActionInstalled = FileManager.default.fileExists(atPath: userServicesWorkflowURL.path)
    }

    func installQuickAction() {
        let fm = FileManager.default
        let servicesDir = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Services")
        try? fm.createDirectory(at: servicesDir, withIntermediateDirectories: true)
        let target = userServicesWorkflowURL
        try? fm.removeItem(at: target)

        var sourceURL: URL?
        if let direct = Bundle.main.url(forResource: "Comprimir con Compresor", withExtension: "workflow") {
            sourceURL = direct
        } else if let nested = Bundle.main.resourceURL?.appendingPathComponent("QuickAction/Comprimir con Compresor.workflow"), fm.fileExists(atPath: nested.path) {
            sourceURL = nested
        }

        if let sourceURL {
            try? fm.copyItem(at: sourceURL, to: target)
        }
        NSUpdateDynamicServices()
        checkStatus()
    }

    func uninstallQuickAction() {
        try? FileManager.default.removeItem(at: userServicesWorkflowURL)
        NSUpdateDynamicServices()
        checkStatus()
    }
}

@MainActor
struct SettingsView: View {
    @StateObject private var model = SettingsModel()
    @AppStorage("appLanguage") private var languageRaw = AppLanguage.spanish.rawValue
    @AppStorage("outputDestination") private var outputDestinationRaw = OutputDestination.subfolder.rawValue
    @AppStorage("customOutputFolderPath") private var customFolderPath = ""
    private var language: AppLanguage { AppLanguage(rawValue:languageRaw) ?? .spanish }
    private var outputDestination: Binding<OutputDestination> {
        Binding(get:{ OutputDestination(rawValue:outputDestinationRaw) ?? .subfolder }, set:{ outputDestinationRaw=$0.rawValue })
    }

    var body: some View {
        Form {
            Section(tr("General", "General", language:language)) {
                Picker(tr("Idioma", "Language", language:language), selection:$languageRaw) {
                    ForEach(AppLanguage.allCases) { option in Text(option.name).tag(option.rawValue) }
                }
                .pickerStyle(.segmented)
            }
            Section(tr("Integración con Finder", "Finder Integration", language:language)) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: model.quickActionInstalled ? "checkmark.circle.fill" : "wand.and.stars")
                        .font(.title2)
                        .foregroundStyle(model.quickActionInstalled ? .green : .blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.quickActionInstalled ? tr("Acción Rápida instalada en Finder", "Quick Action installed in Finder", language:language) : tr("Acción Rápida no instalada", "Quick Action not installed", language:language))
                            .fontWeight(.medium)
                        Text(model.quickActionInstalled ? tr("Haz clic derecho sobre cualquier archivo o carpeta en Finder > Acciones rápidas > Comprimir con Compresor.", "Right click any file or folder in Finder > Quick Actions > Compress with Compressor.", language:language) : tr("Añade la opción 'Comprimir con Compresor' al menú de clic derecho (Acciones rápidas) de Finder.", "Adds 'Compress with Compressor' to the Finder right-click menu (Quick Actions).", language:language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if model.quickActionInstalled {
                        Button(tr("Desinstalar", "Uninstall", language:language), role: .destructive) {
                            model.uninstallQuickAction()
                        }
                    } else {
                        Button(tr("Instalar", "Install", language:language)) {
                            model.installQuickAction()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.vertical, 4)
            }
            Section(tr("Guardar archivos", "Save files", language:language)) {
                Picker(tr("Ubicación", "Location", language:language), selection:outputDestination) {
                    Text(tr("Subcarpeta junto al original", "Subfolder beside original", language:language)).tag(OutputDestination.subfolder)
                    Text(tr("Junto al archivo original", "Beside original file", language:language)).tag(OutputDestination.besideOriginal)
                    Text(tr("Carpeta personalizada", "Custom folder", language:language)).tag(OutputDestination.customFolder)
                }
                .pickerStyle(.radioGroup)
                if outputDestination.wrappedValue == .customFolder {
                    HStack {
                        Text(customFolderPath.isEmpty ? tr("Ninguna carpeta seleccionada", "No folder selected", language:language) : customFolderPath)
                            .foregroundStyle(customFolderPath.isEmpty ? .secondary : .primary).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button(tr("Elegir…", "Choose…", language:language)) { chooseCustomFolder() }
                    }
                }
                Text(tr("Los originales nunca se sobrescriben. Si un nombre ya existe, se crea uno único.", "Originals are never overwritten. If a name already exists, a unique one is created.", language:language))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(12)
        .frame(width:540,height:460)
        .navigationTitle(tr("Ajustes", "Settings", language:language))
        .onAppear {
            loadCustomFolderPath()
            model.checkStatus()
        }
    }

    private func chooseCustomFolder() {
        let panel=NSOpenPanel()
        panel.canChooseFiles=false; panel.canChooseDirectories=true; panel.allowsMultipleSelection=false
        panel.prompt=tr("Elegir", "Choose", language:language)
        guard panel.runModal() == .OK, let url=panel.url else { return }
        do {
            let data=try url.bookmarkData(options:.withSecurityScope, includingResourceValuesForKeys:nil, relativeTo:nil)
            UserDefaults.standard.set(data,forKey:"customOutputFolderBookmark")
            customFolderPath=url.path
            outputDestinationRaw=OutputDestination.customFolder.rawValue
        } catch {
            customFolderPath=""
        }
    }

    private func loadCustomFolderPath() {
        guard let data=UserDefaults.standard.data(forKey:"customOutputFolderBookmark") else { customFolderPath=""; return }
        var stale=false
        customFolderPath=(try? URL(resolvingBookmarkData:data,options:.withSecurityScope,relativeTo:nil,bookmarkDataIsStale:&stale).path) ?? ""
    }
}
