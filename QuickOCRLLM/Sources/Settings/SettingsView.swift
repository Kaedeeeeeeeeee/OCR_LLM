import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vm: AppViewModel
    // Observe LocalizationService for updates
    @ObservedObject var loc = LocalizationService.shared

    var body: some View {
        TabView {
            GeneralSettingsView()
                .environmentObject(vm)
                .tabItem {
                    Label("General".localized, systemImage: "gearshape")
                }
            
            // MARK: - 暂时隐藏 AI Model 和 Subscription，之后添加付费功能时恢复
            // AISettingsView()
            //     .environmentObject(vm)
            //     .tabItem {
            //         Label("AI Model".localized, systemImage: "brain")
            //     }
            
            AdvancedSettingsView()
                .environmentObject(vm)
                .tabItem {
                    Label("Advanced".localized, systemImage: "slider.horizontal.3")
                }
            
            // SubscriptionView()
            //     .tabItem {
            //         Label("Subscription".localized, systemImage: "creditcard")
            //     }
        }
        .frame(width: 500, height: 400) // Fixed size for consistency
        .padding()
    }
}

// MARK: - General Tab
struct GeneralSettingsView: View {
    @EnvironmentObject var vm: AppViewModel
    @ObservedObject var loc = LocalizationService.shared
    
    var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { LaunchAtLoginService.isEnabled },
            set: { LaunchAtLoginService.isEnabled = $0 }
        )
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    if let icon = NSApplication.shared.applicationIconImage {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("QuickOCR")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Version 1.0.0") // Ideally dynamically get from Bundle
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 10)
            }
            
            Section {
                Picker("Language".localized, selection: $loc.currentLanguage) {
                    ForEach(Language.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                
                Toggle("Launch at Login".localized, isOn: launchAtLoginBinding)
                
                Toggle("Auto Copy to Clipboard".localized, isOn: $vm.config.autoCopy)
                Toggle("Show Notification".localized, isOn: $vm.config.showNotification)
            } header: {
                Text("Behavior".localized)
            }
            
            Section {
                Button("Clear History & Cache".localized) {
                    vm.lastResult = ""
                    // potentially clear other history
                }
            } header: {
                Text("Data".localized)
            }
        }
        .padding()
        .formStyle(.grouped) // Modern look
    }
}

// MARK: - AI Settings Tab
struct AISettingsView: View {
    @EnvironmentObject var vm: AppViewModel
    
    private let openAIModels = ["gpt-4o-mini", "gpt-4o", "gpt-4.5-preview"]
    private let geminiModels = ["gemini-2.0-flash", "gemini-1.5-pro"]

    var body: some View {
        Form {
            Picker("OCR Engine".localized, selection: $vm.config.provider) {
                Text("Vision (Local)").tag(AppConfig.Provider.vision)
                Text("OpenAI").tag(AppConfig.Provider.openAI)
                Text("Gemini").tag(AppConfig.Provider.gemini)
            }
            .pickerStyle(.segmented)
            .padding(.bottom)

            switch vm.config.provider {
            case .vision:
                Section("Vision OCR".localized) {
                    Text("Local processing - No API key required".localized)
                        .foregroundStyle(.secondary)
                    Text("Supports: English, Chinese, Japanese, Korean".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .openAI:
                Section("OpenAI Configuration".localized) {
                    Picker("Model".localized, selection: $vm.config.openAIModel) {
                        ForEach(openAIModels, id: \.self) { Text($0).tag($0) }
                    }
                    SecureField("API Key".localized, text: Binding(
                        get: { vm.openAIKeyMasked },
                        set: { vm.setOpenAIKey($0) }
                    ))
                    Text("Stored securely in Keychain".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .gemini:
                Section("Gemini Configuration".localized) {
                    Picker("Model".localized, selection: $vm.config.geminiModel) {
                        ForEach(geminiModels, id: \.self) { Text($0).tag($0) }
                    }
                    SecureField("API Key".localized, text: Binding(
                        get: { vm.geminiKeyMasked },
                        set: { vm.setGeminiKey($0) }
                    ))
                    Text("Stored securely in Keychain".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Settings Management".localized) {
                 Button("Save Settings".localized) { vm.saveConfig() }
            }
        }
        .padding()
        .formStyle(.grouped)
    }
}

// MARK: - Advanced Tab
struct AdvancedSettingsView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        Form {
             Section("History".localized) {
                 Stepper("\("History Limit".localized): \(vm.config.maxHistory)", value: $vm.config.maxHistory, in: 1...100)
             }
             
             Section("Image Processing".localized) {
                 VStack(alignment: .leading) {
                     Text("\("Max Dimension".localized): \(Int(vm.config.imageMaxDimension)) px")
                     Slider(value: Binding(
                        get: { Double(vm.config.imageMaxDimension) },
                        set: { vm.config.imageMaxDimension = CGFloat($0) }
                     ), in: 800...3840, step: 100)
                 }
                 
                 VStack(alignment: .leading) {
                     Text("\("JPEG Quality".localized): \(Int(vm.config.jpegQuality * 100))%")
                     Slider(value: $vm.config.jpegQuality, in: 0.1...1.0)
                 }
             }
        }
        .padding()
        .formStyle(.grouped)
    }
}
