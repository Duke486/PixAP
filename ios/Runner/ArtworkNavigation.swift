import SwiftUI

final class ArtworkNavigationSelection: ObservableObject {
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
    var prominent = false
    var segmentWidths: [CGFloat]? = nil
    let select: (Int) -> Void
    private let itemSize: CGFloat = 46
    private let itemSpacing: CGFloat = 6
    private let icons = ["house", "chart.bar", "heart", "magnifyingglass", "ellipsis"]
    @Namespace private var selection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                .foregroundStyle(.primary)
                .accessibilityLabel(labels[index])
                .accessibilityAddTraits(selected == index ? .isSelected : [])
            }
        }
        // Keep one lens mounted so the glass travels between any two icons.
        .background(alignment: .top) {
            railLens
                .frame(width: itemSize, height: itemSize)
                .offset(y: CGFloat(selected) * (itemSize + itemSpacing))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .padding(7)
    }

    @ViewBuilder private var railLens: some View {
        if #available(iOS 26, *) {
            Circle()
                .fill(.clear)
                .glassEffect(.regular.tint(.primary.opacity(0.12)), in: Circle())
                .glassEffectID("railSelection", in: selection)
        } else {
            Circle().fill(.primary.opacity(0.08))
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
        if #available(iOS 26, *) {
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
