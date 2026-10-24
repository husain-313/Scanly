import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @AppStorage("searchablePDF") private var searchablePDF = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Security") {
                    Toggle("Lock app with Face ID", isOn: $appLockEnabled)
                }
                Section("Export") {
                    Toggle("Searchable PDF (OCR layer)", isOn: $searchablePDF)
                } footer: {
                    Text("Adds recognized text to PDFs so they can be searched. Slightly slower to export.")
                }
                Section {
                    LabeledContent("Version", value: version)
                } header: {
                    Text("About")
                } footer: {
                    Text("Scanly scans, enhances and recognizes documents fully on-device. No account, no subscription.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }
}
