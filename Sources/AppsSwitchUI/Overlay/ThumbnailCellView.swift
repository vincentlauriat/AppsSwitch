import AppKit
import SwiftUI
import AppsSwitchCore

struct ThumbnailCellView: View {
    let window: WindowInfo
    let thumbnail: NSImage?
    let isSelected: Bool

    private var appIcon: NSImage {
        NSRunningApplication(processIdentifier: window.ownerPID)?.icon ?? NSWorkspace.shared.icon(for: .application)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.15))
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    // Screen Recording not (yet) granted, or the capture simply hasn't finished
                    // loading — the app icon is a reasonable placeholder either way.
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                }
            }
            .frame(width: 180, height: 120)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
            )

            HStack(spacing: 4) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 14, height: 14)
                Text(window.title)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: 180)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
    }
}
