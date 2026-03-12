import SwiftUI

struct PlaylistEditorView: View {
    @ObservedObject private var viewModel: PlaylistEditorViewModel
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name
    }

    init(viewModel: PlaylistEditorViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                SectionCard(title: "Details") {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Playlist Name") {
                            TextField("Untitled", text: $viewModel.name)
                                .focused($focusedField, equals: .name)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 240)
                        }

                        LabeledContent("Rotation Interval") {
                            Stepper(
                                value: $viewModel.intervalMinutes,
                                in: 1...240,
                                step: 5
                            ) {
                                Text("\(viewModel.intervalMinutes) min")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            .controlSize(.small)
                        }

                        LabeledContent("Playback Mode") {
                            Picker("Playback Mode", selection: $viewModel.playbackMode) {
                                ForEach(PlaylistPlaybackMode.allCases, id: \.self) { mode in
                                    Text(label(for: mode)).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .controlSize(.small)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                SectionCard(title: "Entries", trailing: "\(viewModel.entries.count)") {
                    VStack(alignment: .leading, spacing: 12) {
                        if viewModel.entries.isEmpty {
                            Text("Add wallpapers to start building this playlist.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(viewModel.entries.indices), id: \.self) { index in
                                PlaylistEntryRow(
                                    index: index,
                                    isFirst: index == 0,
                                    isLast: index == viewModel.entries.count - 1,
                                    entry: $viewModel.entries[index],
                                    library: viewModel.wallpapers,
                                    moveUp: { viewModel.moveEntryUp(at: index) },
                                    moveDown: { viewModel.moveEntryDown(at: index) },
                                    remove: { viewModel.removeEntry(at: index) }
                                )
                            }
                        }
                        Button {
                            viewModel.addEntry()
                        } label: {
                            Label("Add Entry", systemImage: "plus")
                        }
                        .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                SectionCard(title: "Multi-Display") {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Policy") {
                            Picker("Policy", selection: $viewModel.multiDisplayPolicy) {
                                ForEach(MultiDisplayPolicy.allCases, id: \.self) { policy in
                                    Text(label(for: policy)).tag(policy)
                                }
                            }
                            .labelsHidden()
                            .controlSize(.small)
                        }

                        if viewModel.multiDisplayPolicy == .perDisplay {
                            if viewModel.displayAssignments.isEmpty {
                                Text("Define wallpapers for individual displays.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(Array(viewModel.displayAssignments.indices), id: \.self) { index in
                                    DisplayAssignmentRow(
                                        index: index,
                                        isFirst: index == 0,
                                        isLast: index == viewModel.displayAssignments.count - 1,
                                        assignment: $viewModel.displayAssignments[index],
                                        library: viewModel.wallpapers,
                                        displays: viewModel.availableDisplays,
                                        displayLabel: viewModel.labelForDisplay(id:),
                                        moveUp: { viewModel.moveDisplayAssignmentUp(at: index) },
                                        moveDown: { viewModel.moveDisplayAssignmentDown(at: index) },
                                        remove: { viewModel.removeDisplayAssignment(at: index) }
                                    )
                                }
                            }
                            Button {
                                viewModel.addDisplayAssignment()
                            } label: {
                                Label("Add Display Assignment", systemImage: "plus.circle")
                            }
                            .controlSize(.small)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 8) {
                    if viewModel.isSaving {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Button("Save") {
                        focusedField = nil
                        viewModel.saveChanges()
                    }
                    .disabled(!viewModel.canSave || !viewModel.hasUnsavedChanges)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                viewModel.refreshLibrary()
            }
        }
    }

    private var title: String {
        let trimmed = viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Playlist" : trimmed
    }

    private func label(for mode: PlaylistPlaybackMode) -> String {
        switch mode {
        case .sequential:
            return "Sequential"
        case .random:
            return "Random"
        }
    }

    private func label(for policy: MultiDisplayPolicy) -> String {
        switch policy {
        case .mirror:
            return "Mirror All Displays"
        case .perDisplay:
            return "Configure Per Display"
        }
    }

}

private struct PlaylistEntryRow: View {
    let index: Int
    let isFirst: Bool
    let isLast: Bool
    @Binding var entry: PlaylistEditorViewModel.Entry
    let library: [WallpaperRecord]
    let moveUp: () -> Void
    let moveDown: () -> Void
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("Entry \(index + 1)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 8) {
                    Button(action: moveUp) {
                        Image(systemName: "arrow.up")
                    }
                    .disabled(isFirst)

                    Button(action: moveDown) {
                        Image(systemName: "arrow.down")
                    }
                    .disabled(isLast)

                    Button(role: .destructive, action: remove) {
                        Image(systemName: "trash")
                    }
                }
                .buttonStyle(.borderless)
            }

            WallpaperPicker(
                title: "Light Mode Wallpaper",
                selection: $entry.lightWallpaperId,
                library: library
            )
            WallpaperPicker(
                title: "Dark Mode Wallpaper",
                selection: $entry.darkWallpaperId,
                library: library
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        )
    }
}

private struct DisplayAssignmentRow: View {
    let index: Int
    let isFirst: Bool
    let isLast: Bool
    @Binding var assignment: PlaylistEditorViewModel.DisplayAssignment
    let library: [WallpaperRecord]
    let displays: [DisplayDescriptor]
    let displayLabel: (String) -> String
    let moveUp: () -> Void
    let moveDown: () -> Void
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("Display \(index + 1)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 8) {
                    Button(action: moveUp) {
                        Image(systemName: "arrow.up")
                    }
                    .disabled(isFirst)

                    Button(action: moveDown) {
                        Image(systemName: "arrow.down")
                    }
                    .disabled(isLast)

                    Button(role: .destructive, action: remove) {
                        Image(systemName: "trash")
                    }
                }
                .buttonStyle(.borderless)
            }

            if displays.isEmpty {
                Text("No connected displays detected.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Display", selection: $assignment.displayID) {
                    ForEach(displays) { display in
                        Text(display.name).tag(display.id)
                    }
                }
                .controlSize(.small)
                Text("Identifier: \(displayLabel(assignment.displayID))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            WallpaperPicker(
                title: "Light Mode Wallpaper",
                selection: $assignment.lightWallpaperId,
                library: library
            )
            WallpaperPicker(
                title: "Dark Mode Wallpaper",
                selection: $assignment.darkWallpaperId,
                library: library
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        )
    }
}

private struct WallpaperPicker: View {
    let title: String
    @Binding var selection: UUID?
    let library: [WallpaperRecord]

    var body: some View {
        Menu {
            Button("None") {
                selection = nil
            }
            if !library.isEmpty {
                Section("Library") {
                    ForEach(library) { record in
                        Button(record.displayName) {
                            selection = record.id
                        }
                    }
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(selectionTitle)
                    .font(.body)
                    .foregroundStyle(selection == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .menuStyle(.borderlessButton)
    }

    private var selectionTitle: String {
        guard let selection,
              let record = library.first(where: { $0.id == selection })
        else {
            return "Select…"
        }
        return record.displayName
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    let trailing: String?
    @ViewBuilder let content: () -> Content

    init(title: String, trailing: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            content()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
        )
    }
}
