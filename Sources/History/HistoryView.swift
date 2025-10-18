import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var copiedId: UUID? = nil

    var items: [OCRRecord] {
        let limit = max(1, vm.config.maxHistory)
        return Array(vm.history.items.prefix(limit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent OCR Results")
                    .font(.headline)
                Spacer()
                Button("Close") { NSApp.keyWindow?.close() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.bottom, 4)

            if items.isEmpty {
                Text("No history yet.")
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(items) { rec in
                            let isCopied = copiedId == rec.id
                            Button(action: {
                                Clipboard.copy(rec.text)
                                copiedId = rec.id
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { copiedId = nil }
                            }) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(rec.timestamp.formatted(date: .abbreviated, time: .standard))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        if isCopied { Text("Copied").font(.caption).foregroundColor(.green) }
                                    }
                                    Text(rec.text)
                                        .font(.body)
                                        .lineLimit(nil)
                                }
                                .padding(10)
                                .background(Color.gray.opacity(0.08))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 420)
    }
}
