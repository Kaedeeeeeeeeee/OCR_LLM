import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vm: AppViewModel
    // Observe LocalizationService for updates
    @ObservedObject var loc = LocalizationService.shared

    var body: some View {
        GeneralSettingsView()
            .environmentObject(vm)
            .frame(width: 500, height: 400)
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

    var mascotBinding: Binding<MascotChoice> {
        Binding(
            get: { MascotChoice(rawValue: vm.config.mascotStyle ?? "") ?? .random },
            set: { vm.config.mascotStyle = ($0 == .random) ? nil : $0.rawValue }
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
                        Text("Cheese! OCR")
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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mascot Style".localized)
                    MascotPickerGrid(selection: mascotBinding)
                }
                .padding(.vertical, 4)

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
                Stepper("\("History Limit".localized): \(vm.config.maxHistory)", value: $vm.config.maxHistory, in: 1...100)
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

// MARK: - Mascot picker grid

struct MascotPickerGrid: View {
    @Binding var selection: MascotChoice

    var body: some View {
        HStack(spacing: 6) {
            ForEach(MascotChoice.allCases) { choice in
                MascotPickerCell(
                    choice: choice,
                    isSelected: selection == choice,
                    onSelect: { selection = choice }
                )
            }
        }
    }
}

struct MascotPickerCell: View {
    let choice: MascotChoice
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.gray.opacity(0.12))
                        .frame(width: 54, height: 50)
                    MascotIcon(choice: choice)
                        .scaleEffect(1.15)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                Text(choice.displayName)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .frame(width: 58)
            }
        }
        .buttonStyle(.plain)
    }
}
