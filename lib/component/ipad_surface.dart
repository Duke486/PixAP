import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, listEquals;
import 'package:material_ui/material_ui.dart';

bool usesIPadLayout(BuildContext context) =>
    defaultTargetPlatform == TargetPlatform.iOS && MediaQuery.sizeOf(context).shortestSide >= 600;

/// Keeps the original control, controller, semantics, and tap handlers.
class IPadSurface extends StatelessWidget {
  const IPadSurface({
    super.key,
    required this.child,
    this.maxWidth,
    this.glass = true,
    this.darkGlass = false,
    this.circular = false,
    this.tint,
    this.includeIPhone = false,
  });
  final Widget child;
  final double? maxWidth;
  final bool glass;
  final bool darkGlass;
  final bool circular;
  final Color? tint;
  final bool includeIPhone;

  @override
  Widget build(BuildContext context) {
    if (!usesIPadLayout(context) &&
        !(includeIPhone && defaultTargetPlatform == TargetPlatform.iOS)) {
      return child;
    }
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(glass ? 24 : 19);
    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: glass ? 0.67 : 1),
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : radius,
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: child,
    );
    if (glass) {
      content = Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: UiKitView(viewType: 'pixez/glassSurface', creationParams: {'dark': darkGlass, 'circular': circular, if (tint != null) 'tint': tint!.toARGB32()}, creationParamsCodec: const StandardMessageCodec()),
              ),
            ),
          ),
          child,
        ],
      );
    }
    return Align(
      alignment: Alignment.center,
      widthFactor: 1, heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
        child: content,
      ),
    );
  }
}

/// The tab strip and the swipeable page view share one controller.
class IPadPageTabs extends StatelessWidget {
  const IPadPageTabs({super.key, required this.tabs, this.maxWidth = 700});
  final TabBar tabs;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (!usesIPadLayout(context)) return tabs;
    if (tabs.tabs.every((item) => item is Tab && item.text != null)) {
      final labels = tabs.tabs.cast<Tab>().map((item) => item.text!).toList();
      final controller = tabs.controller ?? DefaultTabController.of(context);
      return AnimatedBuilder(animation: controller, builder: (_, _) =>
        GlassSegmentPicker(labels: labels, index: controller.index, maxWidth: maxWidth,
          onSelect: (index) {
            controller.animateTo(index);
            tabs.onTap?.call(index);
          }));
    }
    final scheme = Theme.of(context).colorScheme;
    return Center(child: IPadSurface(maxWidth: maxWidth, child: TabBar(
      controller: tabs.controller, onTap: tabs.onTap,
      splashFactory: NoSplash.splashFactory,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      tabs: [
        for (final (index, item) in tabs.tabs.indexed)
          Tab(height: 32, child: AnimatedBuilder(
            animation: tabs.controller ?? DefaultTabController.of(context),
            builder: (_, _) {
              final selected = (tabs.controller ?? DefaultTabController.of(context)).index == index;
              final label = Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(child: item is Tab && item.text != null ? Text(item.text!) : item));
              return selected ? IPadSurface(child: label) : label;
            },
          )),
      ],
      isScrollable: true, tabAlignment: TabAlignment.center,
      dividerHeight: 0, padding: const EdgeInsets.all(2),
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: const BoxDecoration(),
      labelColor: scheme.onSurface, unselectedLabelColor: scheme.onSurfaceVariant,
      labelPadding: EdgeInsets.zero,
    )));
  }
}

class IPadGalleryCard extends StatelessWidget {
  const IPadGalleryCard({
    super.key,
    required this.child,
    this.radius = 22,
    this.scrolling = false,
    this.inset = 3,
    this.horizontalMargin = 5,
  });
  final bool scrolling;
  final double inset;
  final double horizontalMargin;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (scrolling) {
      final colors = Theme.of(context).colorScheme;
      return Padding(padding: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: 5), child: RepaintBoundary(child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [colors.surface, colors.surfaceContainerLow.withValues(alpha: .72)]),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1))]),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: colors.outlineVariant.withValues(alpha: .45)),
          ),
          child: Padding(padding: EdgeInsets.all(inset), child: ClipRRect(
            borderRadius: BorderRadius.circular(inset == 0 ? radius : radius - 4),
            child: child,
          )),
        ))));
    }
    return Padding(
    padding: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: 5),
    child: DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius),
      boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1))]),
      child: ClipRRect(borderRadius: BorderRadius.circular(radius), child: IPadSurface(child: Padding(padding: const EdgeInsets.all(3),
      child: ClipRRect(borderRadius: BorderRadius.circular(radius - 4), child: child))))),
  );
  }
}

class NativeGlassControl extends StatefulWidget {
  const NativeGlassControl({super.key, this.horizontal = false, this.prominent = false,
    this.segmentWidths, required this.index, required this.labels, required this.onSelect});
  final bool horizontal;
  final bool prominent;
  final List<double>? segmentWidths;
  final int index;
  final List<String> labels;
  final ValueChanged<int> onSelect;
  @override
  State<NativeGlassControl> createState() => NativeGlassControlState();
}

class NativeGlassControlState extends State<NativeGlassControl> {
  MethodChannel? channel;
  Map<String, Object> get args => {
    'horizontal': widget.horizontal, 'prominent': widget.prominent,
    'index': widget.index, 'labels': widget.labels,
    if (widget.segmentWidths != null) 'widths': widget.segmentWidths!,
  };
  @override
  void didUpdateWidget(NativeGlassControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index || !listEquals(oldWidget.labels, widget.labels) ||
        !listEquals(oldWidget.segmentWidths, widget.segmentWidths) ||
        oldWidget.prominent != widget.prominent) {
      channel?.invokeMethod<void>('update', args);
    }
  }
  @override
  void dispose() {
    channel?.setMethodCallHandler(null);
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => UiKitView(
    viewType: 'pixez/glassRail',
    creationParams: args,
    creationParamsCodec: const StandardMessageCodec(),
    onPlatformViewCreated: (id) {
      if (!mounted) return;
      channel = MethodChannel('pixez/glassRail/$id');
      channel!.setMethodCallHandler((call) async {
        if (call.method == 'select') widget.onSelect(call.arguments as int);
      });
      channel!.invokeMethod<void>('update', args);
    },
  );
}


class GlassSegmentPicker extends StatelessWidget {
  const GlassSegmentPicker({super.key, required this.labels, required this.index,
    required this.onSelect, this.maxWidth = 700, this.compact = false});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onSelect;
  final double maxWidth;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    if (compact) {
      final widths = [
        for (final label in labels) _compactWidth(context, label),
      ];
      final naturalWidth = widths.fold(0.0, (total, width) => total + width);
      return LayoutBuilder(builder: (context, constraints) {
        final available = math.min(maxWidth, constraints.maxWidth);
        final width = math.min(naturalWidth + 6, available);
        final scale = math.max(0, width - 6) / naturalWidth;
        return SizedBox(width: width, height: 36, child: NativeGlassControl(
          horizontal: true, prominent: true, index: index, labels: labels,
          segmentWidths: widths.map((width) => width * scale).toList(),
          onSelect: onSelect,
        ));
      });
    }
    double segmentWidth = 64;
    for (final label in labels) {
      final painter = TextPainter(text: TextSpan(text: label, style: const TextStyle(fontSize: 15)),
        textDirection: Directionality.of(context), textScaler: MediaQuery.textScalerOf(context))..layout();
      segmentWidth = math.max(segmentWidth, painter.width + 36);
      painter.dispose();
    }
    return Center(widthFactor: 1, heightFactor: 1, child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth), child: SingleChildScrollView(
        scrollDirection: Axis.horizontal, child: SizedBox(width: segmentWidth * labels.length + 6,
          height: 36, child: NativeGlassControl(horizontal: true, labels: labels, index: index, onSelect: onSelect)))));
  }
  double _compactWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      textDirection: Directionality.of(context),
    )..layout();
    final width = math.max(38.0, painter.width.ceilToDouble() + 18);
    painter.dispose();
    return width;
  }

}

class GalleryFavoriteButton extends StatelessWidget {
  const GalleryFavoriteButton({super.key, required this.heroTag, required this.child, required this.onPressed, this.backgroundColor});
  final Object heroTag;
  final Color? backgroundColor;
  final Widget child;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    if (!usesIPadLayout(context)) return FloatingActionButton(heroTag: heroTag, backgroundColor: backgroundColor, onPressed: onPressed, child: child);
    return Hero(tag: heroTag, child: IPadSurface(circular: true, child: SizedBox.square(dimension: 56,
      child: IconButton(iconSize: 27, onPressed: onPressed, icon: child))));
  }
}
