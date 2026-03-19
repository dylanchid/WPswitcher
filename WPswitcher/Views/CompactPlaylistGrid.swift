import SwiftUI

private extension PlaylistRecord {
    var readyEntryCount: Int {
        entries.reduce(into: 0) { count, entry in
            if entry.lightWallpaper != nil || entry.darkWallpaper != nil {
                count += 1
            }
        }
    }

    var compactSummary: String {
        "\(entries.count) entries • \(readyEntryCount) ready • every \(intervalMinutes)m"
    }
}

struct CompactPlaylistGrid: View {
    let playlists: [PlaylistRecord]
    let selectedPlaylistID: UUID?
    let onSelectPlaylist: (UUID) -> Void
    let onPlayNow: (PlaylistRecord) -> Void
    let onDelete: (UUID) -> Void
    let previewTextProvider: (PlaylistRecord) -> String
    let canPlayProvider: (PlaylistRecord) -> Bool

    private let columnSpacing: CGFloat = 18
    private let rowSpacing: CGFloat = 18
    private let cardMinimumWidth: CGFloat = 240

    var body: some View {
        GeometryReader { proxy in
            let columns = max(1, Int((proxy.size.width + columnSpacing) / (cardMinimumWidth + columnSpacing)))
            ScrollView {
                LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: columnSpacing), count: columns), spacing: rowSpacing) {
                    ForEach(playlists) { playlist in
                        CompactPlaylistCard(
                            playlist: playlist,
                            isSelected: selectedPlaylistID == playlist.id,
                            onSelect: { onSelectPlaylist(playlist.id) },
                            onPlayNow: { onPlayNow(playlist) },
                            onDelete: { onDelete(playlist.id) },
                            previewText: previewTextProvider(playlist),
                            canPlay: canPlayProvider(playlist)
                        )
                    }
                }
                .padding(1)
            }
        }
    }
}

private struct CompactPlaylistCard: View {
    let playlist: PlaylistRecord
    let isSelected: Bool
    let onSelect: () -> Void
    let onPlayNow: () -> Void
    let onDelete: () -> Void
    let previewText: String
    let canPlay: Bool

    var body: some View {
        Button {
            onSelect()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(playlist.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Text(previewText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }

                HStack(spacing: 8) {
                    Text(playlist.compactSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }

                HStack(spacing: 10) {
                    actionButton(
                        title: "Open",
                        systemImage: "slider.horizontal.3",
                        prominence: .secondary,
                        action: onSelect
                    )

                    actionButton(
                        title: "Play Now",
                        systemImage: "play.fill",
                        prominence: .primary,
                        action: onPlayNow
                    )
                    .disabled(!canPlay)

                    actionButton(
                        title: "Delete",
                        systemImage: "trash",
                        prominence: .destructive,
                        action: onDelete
                    )
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(nsColor: isSelected ? .selectedContentBackgroundColor : .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor.opacity(0.55) : Color(nsColor: .separatorColor).opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onSelect()
            } label: {
                Label("Open Playlist", systemImage: "rectangle.stack")
            }
            Button {
                onPlayNow()
            } label: {
                Label("Play Now", systemImage: "play.fill")
            }
            Button {
                onDelete()
            } label: {
                Label("Delete Playlist", systemImage: "trash")
            }
        }
    }

    private func actionButton(
        title: String,
        systemImage: String,
        prominence: ActionProminence,
        action: @escaping () -> Void
    ) -> some View {
        Group {
            switch prominence {
            case .primary:
                Button(action: action) {
                    Label(title, systemImage: systemImage)
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

            case .secondary:
                Button(action: action) {
                    Label(title, systemImage: systemImage)
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

            case .destructive:
                Button(action: action) {
                    Label(title, systemImage: systemImage)
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.small)
            }
        }
    }
}

private enum ActionProminence {
    case primary
    case secondary
    case destructive
}
