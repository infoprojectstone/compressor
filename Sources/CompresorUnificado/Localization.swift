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

struct SettingsView: View {
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
        .frame(width:520,height:360)
        .navigationTitle(tr("Ajustes", "Settings", language:language))
        .onAppear { loadCustomFolderPath() }
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
