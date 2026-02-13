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
    private let rowSpacing: CGFloat = 16
    private let cardMinimumWidth: CGFloat = 180

    var body: some View {
        GeometryReader { proxy in
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
                            canPlay: canPlayProvider(playlist)
                        )
                        .frame(minHeight: 160)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
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
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(playlist.name)
                        .font(.headline)
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
                HStack(spacing: 8) {
                    Button {
                        onPlayNow()
                    } label: {
                        Label("Play Now", systemImage: "play.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!canPlay)
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .labelStyle(.titleAndIcon)
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }
            .padding(14)
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
}
