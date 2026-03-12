import AppKit
import SwiftUI

private struct CompactPlaylistCardConfiguration {
    let gradient: LinearGradient
    let overlayColor: Color
}

private extension PlaylistRecord {
    var gradient: LinearGradient {
        let colors: [Color] = [
            .init(nsColor: .systemPurple),
            .init(nsColor: .systemIndigo),
            .init(nsColor: .systemTeal)
        ]
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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

    private let columnSpacing: CGFloat = 16
    private let rowSpacing: CGFloat = 12
    private let cardMinimumWidth: CGFloat = 170

    var body: some View {
        GeometryReader { proxy in
            let compactHeight = proxy.size.height < 150
            let columns = max(1, Int(proxy.size.width / (cardMinimumWidth + columnSpacing)))
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
                            canPlay: canPlayProvider(playlist),
                            compact: compactHeight
                        )
                        .frame(minHeight: compactHeight ? 110 : 148)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)
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
    let compact: Bool

    private var titleFont: Font {
        compact ? .subheadline.weight(.semibold) : .headline
    }

    private var verticalSpacing: CGFloat {
        compact ? 8 : 10
    }

    private var actionSpacing: CGFloat {
        compact ? 6 : 8
    }

    private var contentPadding: CGFloat {
        compact ? 12 : 14
    }

    var body: some View {
        Button {
            onSelect()
        } label: {
            VStack(alignment: .leading, spacing: verticalSpacing) {
                HStack {
                    Text(playlist.name)
                        .font(titleFont)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(previewText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer()
                actionRow
            }
            .padding(contentPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(playlist.gradient)
                    .opacity(isSelected ? 1 : 0.8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(isSelected ? 0.9 : 0.5), lineWidth: isSelected ? 2 : 1)
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

    private var actionRow: some View {
        HStack(spacing: actionSpacing) {
            playButton
            deleteButton
        }
    }

    private var playButton: some View {
        Button {
            onPlayNow()
        } label: {
            Group {
                if compact {
                    Image(systemName: "play.fill")
                } else {
                    Label("Play", systemImage: "play.fill")
                        .labelStyle(.titleAndIcon)
                }
            }
            .font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!canPlay)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            onDelete()
        } label: {
            Group {
                if compact {
                    Image(systemName: "trash")
                } else {
                    Label("Delete", systemImage: "trash")
                        .labelStyle(.titleAndIcon)
                }
            }
            .font(.caption)
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
    }
}
