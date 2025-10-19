import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vm: AppViewModel
    private let openAIModels = ["gpt-4o-mini", "gpt-4o", "gpt-4.1"]
    private let geminiModels = ["gemini-2.0-flash", "gemini-2.0-pro"]

    var body: some View {
        Form {
            Picker("Provider", selection: $vm.config.provider) {
                Text("OpenAI").tag(AppConfig.Provider.openAI)
                Text("Gemini").tag(AppConfig.Provider.gemini)
            }
            .pickerStyle(.segmented)

            GroupBox("Models") {
                HStack {
                    Text("OpenAI:")
                    Picker("OpenAI Model", selection: $vm.config.openAIModel) {
                        ForEach(openAIModels, id: \.self) { m in
                            Text(m).tag(m)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    Text("Gemini:")
                    Picker("Gemini Model", selection: $vm.config.geminiModel) {
                        ForEach(geminiModels, id: \.self) { m in
                            Text(m).tag(m)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            GroupBox("API Keys (stored in Keychain)") {
                SecureField("OpenAI API Key", text: Binding(
                    get: { vm.openAIKeyMasked },
                    set: { vm.setOpenAIKey($0) }
                ))
                SecureField("Gemini API Key", text: Binding(
                    get: { vm.geminiKeyMasked },
                    set: { vm.setGeminiKey($0) }
                ))
            }

            Toggle("Auto Copy to Clipboard", isOn: $vm.config.autoCopy)
            Toggle("Show Notification", isOn: $vm.config.showNotification)

            Stepper(value: $vm.config.maxHistory, in: 1...100) { Text("History Limit: \(vm.config.maxHistory)") }
            HStack {
                Text("Max Image Dimension")
                Slider(value: Binding(get: { Double(vm.config.imageMaxDimension) }, set: { vm.config.imageMaxDimension = CGFloat($0) }), in: 800...2400)
                Text("\(Int(vm.config.imageMaxDimension)) px")
            }
            HStack {
                Text("JPEG Quality")
                Slider(value: $vm.config.jpegQuality, in: 0.5...0.95)
                Text(String(format: "%.2f", vm.config.jpegQuality))
            }

            HStack {
                Button("Save Settings") { vm.saveConfig() }
                Button("Clear Last Result") { vm.lastResult = "" }
            }
        }
        .padding()
        .frame(width: 520)
        .onAppear {
            if !openAIModels.contains(vm.config.openAIModel) {
                vm.config.openAIModel = openAIModels.first ?? vm.config.openAIModel
            }
            if !geminiModels.contains(vm.config.geminiModel) {
                vm.config.geminiModel = geminiModels.first ?? vm.config.geminiModel
            }
        }
    }
}
