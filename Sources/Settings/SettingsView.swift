import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vm: AppViewModel

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
                    TextField("gpt-4o-mini", text: $vm.config.openAIModel)
                }
                HStack {
                    Text("Gemini:")
                    TextField("gemini-2.0-flash", text: $vm.config.geminiModel)
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
            Toggle("Use macOS native selection capture", isOn: $vm.config.useNativeScreencapture)

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
    }
}
