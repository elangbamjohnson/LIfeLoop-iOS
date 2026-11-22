import SwiftUI

struct PrioritySwipeAction: Identifiable {
    let title: String
    let icon: String
    let tint: Color
    let perform: () -> Void

    var id: String { title }
}

/// Reveals explicit action buttons when swiped horizontally, while allowing vertical scrolling.
/// Neither tapping nor swiping the card will trigger detail navigation.
struct PrioritySwipeRow<Content: View>: View {
    let leadingActions: [PrioritySwipeAction]
    let trailingActions: [PrioritySwipeAction]
    let isExpanded: Bool
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection
    @GestureState private var isDragging = false
    @State private var offset: CGFloat = 0
    @State private var settledOffset: CGFloat = 0
    @State private var isHorizontalDrag: Bool?
    private let actionWidth: CGFloat = 76

    private var direction: CGFloat { layoutDirection == .rightToLeft ? -1 : 1 }

    var body: some View {
        ZStack(alignment: .center) {
            // Action buttons layer behind the card
            if offset > 0 || settledOffset > 0 {
                actionButtons(leadingActions)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if offset < 0 || settledOffset < 0 {
                actionButtons(trailingActions)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            // Foreground card content
            content()
                .offset(x: offset * direction)
                .overlay {
                    if settledOffset != 0 {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                settle(at: 0)
                            }
                    }
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .updating($isDragging) { _, dragging, _ in dragging = true }
                .onChanged { value in
                    if isHorizontalDrag == nil {
                        isHorizontalDrag = abs(value.translation.width) > abs(value.translation.height) * 1.5
                    }
                    guard isHorizontalDrag == true else { return }
                    let proposed = settledOffset + value.translation.width * direction
                    offset = min(CGFloat(leadingActions.count) * actionWidth,
                                 max(-CGFloat(trailingActions.count) * actionWidth, proposed))
                }
                .onEnded { _ in finishDrag() }
        )
        .onChange(of: isDragging) { _, dragging in
            if !dragging { finishDrag() }
        }
        .onChange(of: isExpanded) { _, _ in settle(at: 0) }
        .onChange(of: leadingActions.map(\.id)) { _, _ in settle(at: 0) }
        .onChange(of: trailingActions.map(\.id)) { _, _ in settle(at: 0) }
    }

    private func actionButtons(_ actions: [PrioritySwipeAction]) -> some View {
        HStack(spacing: 0) {
            ForEach(actions) { action in
                Button {
                    settle(at: 0)
                    action.perform()
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: action.icon)
                        Text(action.title)
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.white)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .background(action.tint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(action.title)
            }
        }
    }

    private func finishDrag() {
        defer { isHorizontalDrag = nil }
        guard isHorizontalDrag == true else { return }
        let width = offset > 0
            ? CGFloat(leadingActions.count) * actionWidth
            : -CGFloat(trailingActions.count) * actionWidth
        settle(at: abs(offset) > abs(width) * 0.4 ? width : 0)
    }

    private func settle(at position: CGFloat) {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
            offset = position
            settledOffset = position
        }
    }
}
