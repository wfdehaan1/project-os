import SwiftUI

struct SourceListView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Source material").font(.headline)
                Spacer()
                Button("Paste Source", systemImage: "doc.on.clipboard") { environment.showAddSource = true }
            }
            if environment.sources.isEmpty {
                Text("No sources yet. Paste labelled text to make it selectable context.").foregroundStyle(.secondary)
            } else {
                ForEach(environment.sources) { source in
                    DisclosureGroup {
                        Text(source.text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
                    } label: {
                        HStack {
                            Toggle("", isOn: Binding(get: { environment.contextSelection.sourceIDs.contains(source.id) }, set: { included in
                                if included { environment.contextSelection.sourceIDs.insert(source.id) } else { environment.contextSelection.sourceIDs.remove(source.id) }
                            })).labelsHidden()
                            Text(source.label).fontWeight(.medium)
                            Spacer()
                            Text("v\(source.version) · \(source.text.count) chars").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

struct AddSourceSheet: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Paste Source Material").font(.title2.bold())
            TextField("Label, e.g. Garden office notes", text: $label)
            TextEditor(text: $text).font(.body).frame(minHeight: 260).overlay { RoundedRectangle(cornerRadius: 6).stroke(.separator) }
            HStack {
                Text("Exact Unicode text is retained · \(text.count) / 250,000").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { environment.addSource(label: label, text: text) }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 640, height: 440)
    }
}
