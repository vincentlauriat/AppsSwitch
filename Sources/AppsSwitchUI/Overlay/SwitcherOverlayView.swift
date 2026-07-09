import SwiftUI
import AppsSwitchCore

public struct SwitcherOverlayView: View {
    var viewModel: SwitcherViewModel

    public init(viewModel: SwitcherViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack(spacing: 16) {
            ForEach(Array(viewModel.windows.enumerated()), id: \.element.id) { index, window in
                ThumbnailCellView(
                    window: window,
                    thumbnail: viewModel.thumbnails[window.windowID],
                    isSelected: index == viewModel.selectedIndex
                )
            }
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}
