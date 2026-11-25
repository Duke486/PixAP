import SwiftUI

final class ArtworkNavigationSelection: ObservableObject {
    @Published var page: CGFloat?
    @Published var index: Int

    init(_ index: Int) {
        self.index = index
    }
}

struct ArtworkNavigation: View {
    let labels: [String]
    @ObservedObject var selectionState: ArtworkNavigationSelection
    private var selected: Int { selectionState.index }
    var horizontal = false
    var phoneTabs = false
    var prominent = false
    var segmentWidths: [CGFloat]? = nil
    var tint: Color? = nil
    let select: (Int) -> Void
    private let itemSize: CGFloat = 46
    private let itemSpacing: CGFloat = 6
    private let icons = ["house", "chart.bar", "heart", "magnifyingglass", "ellipsis"]
    @Namespace private var selection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @GestureState private var dragPosition: CGFloat?
    private var lensPosition: CGFloat {
        dragPosition ?? selectionState.page ?? CGFloat(selected)
    }

    private func position(at y: CGFloat) -> CGFloat {
        min(CGFloat(max(0, labels.count - 1)), max(0, (y - itemSize / 2) / (itemSize + itemSpacing)))
    }

    private var controls: some View {
        VStack(spacing: itemSpacing) {
            ForEach(labels.indices, id: \.self) { index in
                Button {
                    selectionState.index = index
                    select(index)
                } label: {
                    Image(systemName: icons[index])
                        .symbolVariant(selected == index ? .fill : .none)
                        .font(.system(size: 21, weight: selected == index ? .semibold : .regular))
                        .frame(width: itemSize, height: itemSize)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(selected == index ? (tint ?? .primary) : .primary)
                .accessibilityLabel(labels[index])
                .accessibilityAddTraits(selected == index ? .isSelected : [])
            }
        }
        // Keep one lens mounted so the glass travels between any two icons.
        .background(alignment: .top) {
            railLens
                .frame(width: itemSize, height: itemSize)
                .modifier(RailLensMotion(position: lensPosition, stride: itemSize + itemSpacing,
                                        reduceMotion: reduceMotion))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(DragGesture(minimumDistance: 5)
            .updating($dragPosition) { value, state, _ in
                state = position(at: value.location.y)
            }
            .onEnded { value in
                let height = CGFloat(labels.count) * (itemSize + itemSpacing) - itemSpacing
                guard (0...itemSize).contains(value.location.x), (0...height).contains(value.location.y) else { return }
                let index = Int(position(at: value.location.y).rounded())
                if index != selected {
                    selectionState.index = index
                    select(index)
                }
            })
        .padding(7)
    }

    @ViewBuilder private var railLens: some View {
        if #available(iOS 26, *) {
            Circle()
                .fill(.clear)
                .glassEffect(.regular.tint((tint ?? .primary).opacity(0.16)), in: Circle())
                .glassEffectID("railSelection", in: selection)
        } else {
            Circle().fill((tint ?? .primary).opacity(0.12))
        }
    }

    private var segments: some View {
        HStack(spacing: 0) {
            ForEach(labels.indices, id: \.self) { index in
                Button {
                    select(index)
                } label: {
                    Text(labels[index])
                        .font(prominent ? .system(size: 14, weight: index == selected ? .semibold : .regular)
                                        : .subheadline.weight(index == selected ? .semibold : .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(prominent ? 0.6 : 1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .frame(width: segmentWidths?[index])
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .background {
                    if index == selected {
                        if #available(iOS 26, *) {
                            Capsule().fill(.clear)
                                .glassEffect(.regular.tint(prominent ? .primary.opacity(0.13) : nil).interactive(), in: Capsule())
                                .matchedGeometryEffect(id: "segment", in: selection)
                        } else {
                            Capsule().fill(.regularMaterial)
                        }
                    }
                }
                .accessibilityAddTraits(index == selected ? .isSelected : [])
            }
        }
        .padding(3)
        .animation(.easeInOut(duration: 0.18), value: selected)
    }

    @ViewBuilder private var content: some View {
        if horizontal { segments } else { controls }
    }

    @ViewBuilder var body: some View {
        if #available(iOS 26, *), phoneTabs {
            ArtworkPhoneNavigation(labels: labels, selectionState: selectionState, tint: tint, select: select)
        } else if #available(iOS 26, *) {
            GlassEffectContainer(spacing: horizontal ? 12 : 0) {
                content.glassEffect(.regular.tint(prominent ? .primary.opacity(0.07) : nil).interactive(), in: Capsule())
            }
            .animation(horizontal || reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.76), value: selected)
        } else {
            content.background(.regularMaterial, in: Capsule())
                .animation(horizontal || reduceMotion ? nil : .easeInOut(duration: 0.2), value: selected)
        }
    }
}

@available(iOS 26, *)
private struct ArtworkPhoneNavigation: View {
    let labels: [String]
    @ObservedObject var selectionState: ArtworkNavigationSelection
    let tint: Color?
    let select: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection
    @GestureState private var dragPosition: CGFloat?
    @Namespace private var glass
    private let symbols = ["house", "chart.bar", "heart", "magnifyingglass", "ellipsis"]
    private let itemInset: CGFloat = 5

    private var spring: Animation? {
        reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82)
    }

    private func logicalPosition(_ visualPosition: CGFloat) -> CGFloat {
        layoutDirection == .rightToLeft ? CGFloat(labels.count - 1) - visualPosition : visualPosition
    }

    private func tabPosition(at x: CGFloat, slot: CGFloat) -> CGFloat {
        let position = logicalPosition((x - itemInset) / slot - 0.5)
        return min(max(0, position), CGFloat(labels.count - 1))
    }

    private func choose(_ index: Int) {
        withAnimation(spring) {
            selectionState.page = nil
            selectionState.index = index
        }
        select(index)
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            if !labels.isEmpty, size.width > itemInset * 2, size.height > 14 {
                let slot = (size.width - itemInset * 2) / CGFloat(labels.count)
                GlassEffectContainer(spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(labels.indices, id: \.self) { index in
                            let selected = selectionState.index == index
                            Button {
                                choose(index)
                            } label: {
                                VStack(spacing: 3) {
                                    Image(systemName: symbols[index])
                                        .symbolVariant(selected ? .fill : .none)
                                        .font(.system(size: 22, weight: selected ? .semibold : .regular))
                                    Text(labels[index])
                                        .font(.system(size: 10.5, weight: .medium))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .frame(width: slot, height: size.height)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(selected ? (tint ?? .primary) : .primary)
                            .accessibilityLabel(labels[index])
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal, itemInset)
                    .background { selectionGlass(in: size, slot: slot) }
                    .contentShape(Capsule())
                    .simultaneousGesture(DragGesture(minimumDistance: 5)
                        .updating($dragPosition) { value, state, _ in
                            state = tabPosition(at: value.location.x, slot: slot)
                        }
                        .onEnded { value in
                            guard (0...size.width).contains(value.location.x),
                                  (0...size.height).contains(value.location.y) else { return }
                            let index = Int(tabPosition(at: value.location.x, slot: slot).rounded())
                            if index != selectionState.index { choose(index) }
                        })
                    .glassEffect(.regular.interactive(), in: Capsule())
                }
            }
        }
        .padding(.horizontal, 18)
    }

    private func selectionGlass(in size: CGSize, slot: CGFloat) -> some View {
        let position = dragPosition ?? (reduceMotion ? nil : selectionState.page) ?? CGFloat(selectionState.index)
        let stretch = reduceMotion ? 0 : abs(sin(.pi * position))
        let width = max(1, slot - 4) * (1 + 0.12 * stretch)
        let height = min(size.height - 14, slot * 0.72)
        let x = itemInset + (logicalPosition(position) + 0.5) * slot
        return Capsule()
            .fill(.clear)
            .frame(width: width, height: height)
            .glassEffect(.regular.tint((tint ?? .primary).opacity(0.17)), in: Capsule())
            .glassEffectID("phoneSelection", in: glass)
            .position(x: min(max(itemInset + width / 2, x), size.width - itemInset - width / 2),
                      y: size.height / 2)
            .animation(spring, value: dragPosition != nil)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct RailLensMotion: AnimatableModifier {
    var position: CGFloat
    let stride: CGFloat
    let reduceMotion: Bool

    var animatableData: CGFloat {
        get { position }
        set { position = newValue }
    }

    func body(content: Content) -> some View {
        let stretch = reduceMotion ? 0 : abs(sin(.pi * position))
        content.scaleEffect(x: 1 - 0.08 * stretch, y: 1 + 0.28 * stretch)
            .offset(y: position * stride)
    }
}
