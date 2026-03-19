import SwiftUI

struct PlaylistEditorView: View {
    @ObservedObject private var viewModel: PlaylistEditorViewModel
    @FocusState private var focusedField: Field?
    @State private var selectedPane: EditorPane = .details

    private enum Field: Hashable {
        case name
    }

    private enum EditorPane: String, CaseIterable, Identifiable {
        case details
        case entries
        case displays

        var id: String { rawValue }

        var title: String {
            switch self {
            case .details:
                return "Details"
            case .entries:
                return "Entries"
            case .displays:
                return "Displays"
            }
        }
    }

    init(viewModel: PlaylistEditorViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    var body: some View {
        GeometryReader { proxy in
            let compact = isCompactLayout(proxy.size)
            ScrollView {
                VStack(alignment: .leading, spacing: compact ? 14 : 20) {
                    editorHeader

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if compact {
                        compactHeader
                        compactPanePicker
                        compactPaneContent
                    } else {
                        regularContent
                    }
                }
                .padding(compact ? 16 : 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Text(viewModel.hasUnsavedChanges ? "Unsaved Changes" : "All Changes Saved")
                        .font(.subheadline)
                        .foregroundStyle(viewModel.hasUnsavedChanges ? .secondary : .tertiary)

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

    private var regularContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 20) {
                detailsCard(compact: false)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                displaysCard(compact: false)
                    .frame(width: 340, alignment: .topLeading)
            }

            entriesCard(compact: false)
        }
    }

    private var editorHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.largeTitle.weight(.semibold))
            Text("Define the playlist schedule, choose wallpapers for each entry, and configure display-specific overrides where needed.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                EditorStatChip(label: "Entries", value: "\(viewModel.entries.count)")
                EditorStatChip(label: "Interval", value: "\(viewModel.intervalMinutes) min")
                EditorStatChip(label: "Mode", value: label(for: viewModel.playbackMode))
                EditorStatChip(label: "Displays", value: label(for: viewModel.multiDisplayPolicy))
            }
        }
    }

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Compact Editor")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                CompactStatBadge(label: "Entries", value: "\(viewModel.entries.count)")
                CompactStatBadge(label: "Every", value: "\(viewModel.intervalMinutes)m")
                CompactStatBadge(label: "Mode", value: label(for: viewModel.playbackMode))
            }
            CompactStatBadge(label: "Displays", value: label(for: viewModel.multiDisplayPolicy))
        }
    }

    private var compactPanePicker: some View {
        Picker("Editor Section", selection: $selectedPane) {
            ForEach(EditorPane.allCases) { pane in
                Text(pane.title).tag(pane)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var compactPaneContent: some View {
        switch selectedPane {
        case .details:
            detailsCard(compact: true)
        case .entries:
            entriesCard(compact: true)
        case .displays:
            displaysCard(compact: true)
        }
    }

    private func detailsCard(compact: Bool) -> some View {
        SectionCard(title: "Details", compact: compact) {
            VStack(alignment: .leading, spacing: compact ? 10 : 12) {
                TextField("Untitled", text: $viewModel.name)
                    .focused($focusedField, equals: .name)
                    .textFieldStyle(.roundedBorder)

                if compact {
                    HStack(spacing: 10) {
                        CompactStepperCard(
                            title: "Interval",
                            value: "\(viewModel.intervalMinutes) min",
                            decrement: {
                                viewModel.intervalMinutes = max(1, viewModel.intervalMinutes - 5)
                            },
                            increment: {
                                viewModel.intervalMinutes = min(240, viewModel.intervalMinutes + 5)
                            }
                        )
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Playback")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("Playback Mode", selection: $viewModel.playbackMode) {
                                ForEach(PlaylistPlaybackMode.allCases, id: \.self) { mode in
                                    Text(label(for: mode)).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                        }
                    }
                } else {
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func entriesCard(compact: Bool) -> some View {
        SectionCard(title: "Entries", trailing: "\(viewModel.entries.count)", compact: compact) {
            VStack(alignment: .leading, spacing: compact ? 10 : 12) {
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
                            remove: { viewModel.removeEntry(at: index) },
                            compact: compact
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
    }

    private func displaysCard(compact: Bool) -> some View {
        SectionCard(title: "Multi-Display", compact: compact) {
            VStack(alignment: .leading, spacing: compact ? 10 : 12) {
                if compact {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Policy")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Policy", selection: $viewModel.multiDisplayPolicy) {
                            ForEach(MultiDisplayPolicy.allCases, id: \.self) { policy in
                                Text(label(for: policy)).tag(policy)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }
                } else {
                    LabeledContent("Policy") {
                        Picker("Policy", selection: $viewModel.multiDisplayPolicy) {
                            ForEach(MultiDisplayPolicy.allCases, id: \.self) { policy in
                                Text(label(for: policy)).tag(policy)
                            }
                        }
                        .labelsHidden()
                        .controlSize(.small)
                    }
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
                                remove: { viewModel.removeDisplayAssignment(at: index) },
                                compact: compact
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

    private func isCompactLayout(_ size: CGSize) -> Bool {
        size.width <= 760 || size.height <= 520
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
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("Entry \(index + 1)")
                    .font(compact ? .caption.weight(.semibold) : .subheadline)
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
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            WallpaperPicker(
                title: "Light Mode Wallpaper",
                selection: $entry.lightWallpaperId,
                library: library,
                compact: compact
            )
            WallpaperPicker(
                title: "Dark Mode Wallpaper",
                selection: $entry.darkWallpaperId,
                library: library,
                compact: compact
            )
        }
        .padding(compact ? 10 : 12)
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
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("Display \(index + 1)")
                    .font(compact ? .caption.weight(.semibold) : .subheadline)
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
                .buttonStyle(.bordered)
                .controlSize(.small)
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
                library: library,
                compact: compact
            )
            WallpaperPicker(
                title: "Dark Mode Wallpaper",
                selection: $assignment.darkWallpaperId,
                library: library,
                compact: compact
            )
        }
        .padding(compact ? 10 : 12)
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
    let compact: Bool

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
                    .font(compact ? .callout : .body)
                    .foregroundStyle(selection == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
            )
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
    let compact: Bool
    @ViewBuilder let content: () -> Content

    init(title: String, trailing: String? = nil, compact: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.trailing = trailing
        self.compact = compact
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 12) {
            HStack {
                Text(title)
                    .font(compact ? .subheadline.weight(.semibold) : .headline)
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(compact ? .caption : .subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            content()
        }
        .padding(compact ? 10 : 12)
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

private struct CompactStatBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

private struct CompactStepperCard: View {
    let title: String
    let value: String
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button(action: decrement) {
                    Image(systemName: "minus")
                }
                .controlSize(.small)

                Text(value)
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)

                Button(action: increment) {
                    Image(systemName: "plus")
                }
                .controlSize(.small)
            }
        }
        .padding(8)
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

private struct EditorStatChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}
