import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

bool get usesNativeFormControls => defaultTargetPlatform == TargetPlatform.iOS;

class GlassFormControl extends StatefulWidget {
  const GlassFormControl(
    this.kind,
    this.parameters,
    this.onChange, {
    super.key,
    this.onEnd,
  });

  final String kind;
  final Map<String, Object?> parameters;
  final ValueChanged<dynamic> onChange;
  final ValueChanged<double>? onEnd;

  @override
  State<GlassFormControl> createState() => _GlassFormControlState();
}

class _GlassFormControlState extends State<GlassFormControl> {
  MethodChannel? channel;
  Map<String, Object?> get args => {'kind': widget.kind, ...widget.parameters};

  @override
  void didUpdateWidget(GlassFormControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    channel?.invokeMethod<void>('update', args);
  }

  @override
  void dispose() {
    channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UiKitView(
    viewType: 'pixez/formControl',
    creationParams: args,
    creationParamsCodec: const StandardMessageCodec(),
    gestureRecognizers: widget.kind == 'slider' || widget.kind == 'switch'
        ? {
            Factory<OneSequenceGestureRecognizer>(
              () => HorizontalDragGestureRecognizer(),
            ),
          }
        : const {},
    onPlatformViewCreated: (id) {
      if (!mounted) return;
      channel = MethodChannel('pixez/formControl/$id');
      channel!.setMethodCallHandler((call) async {
        if (call.method == 'change') widget.onChange(call.arguments);
        if (call.method == 'end') widget.onEnd?.call(call.arguments as double);
      });
      channel!.invokeMethod<void>('update', args);
    },
  );
}

Widget glassSwitch(Switch control, {String? label}) {
  if (!usesNativeFormControls) return control;
  return SizedBox(
    width: 58,
    height: 44,
    child: GlassFormControl('switch', {
      'value': control.value,
      'enabled': control.onChanged != null,
      'label': label,
    }, (v) => control.onChanged?.call(v as bool)),
  );
}

Widget glassSwitchTile(SwitchListTile tile) {
  if (!usesNativeFormControls) return tile;
  return ListTile(
    title: tile.title,
    subtitle: tile.subtitle,
    leading: tile.secondary,
    enabled: tile.onChanged != null,
    onTap: tile.onChanged == null ? null : () => tile.onChanged!(!tile.value),
    trailing: glassSwitch(
      Switch(value: tile.value, onChanged: tile.onChanged),
      label: tile.title is Text ? (tile.title as Text).data : null,
    ),
  );
}

Widget glassSlider(Slider control) {
  if (!usesNativeFormControls) return control;
  return SizedBox(
    height: 48,
    child: GlassFormControl(
      'slider',
      {
        'value': control.value,
        'min': control.min,
        'max': control.max,
        'enabled': control.onChanged != null,
      },
      (v) => control.onChanged?.call(v as double),
      onEnd: control.onChangeEnd,
    ),
  );
}

class GlassChoice extends StatelessWidget {
  const GlassChoice({
    super.key,
    required this.labels,
    required this.index,
    required this.onSelect,
    this.symbol,
    this.active = false, this.glass = false, this.fixedOrder = false,
  });
  final List<String> labels;
  final int index;
  final String? symbol;
  final bool active;
  final bool glass;
  final bool fixedOrder;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final text = index >= 0 && index < labels.length ? labels[index] : '';
    final fontSize = MediaQuery.textScalerOf(context).scale(17);
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Size to the localized label while UIKit draws the actual control.
          if (symbol == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 23),
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: 0,
                  child: Text(
                    text,
                    maxLines: 1,
                    softWrap: false,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 44),
          Positioned.fill(
            child: GlassFormControl('menu', {
              'labels': labels,
              'index': index,
              'symbol': symbol,
              'fontSize': fontSize,
              'active': active, 'glass': glass,
              if (fixedOrder) 'fixedOrder': true,
              'dark': Theme.of(context).brightness == Brightness.dark,
              'label': symbol == null
                  ? text
                  : MaterialLocalizations.of(context).showMenuTooltip,
            }, (v) => onSelect(v as int)),
          ),
        ],
      ),
    );
  }
}

Widget glassPopup<T>(
  BuildContext context,
  PopupMenuButton<T> menu,
  String symbol, {
  bool active = false, bool glass = false,
}) {
  if (!usesNativeFormControls) return menu;
  final items = menu.itemBuilder(context).cast<PopupMenuItem<T>>();
  return GlassChoice(
    labels: [for (final item in items) (item.child as Text).data!],
    index: items.indexWhere(
      (item) => menu.initialValue != null && item.value == menu.initialValue,
    ),
    symbol: symbol,
    active: active, glass: glass,
    onSelect: (index) {
      final item = items[index];
      item.onTap?.call();
      if (item.value != null) menu.onSelected?.call(item.value as T);
    },
  );
}

/// Separates settings on the common page surface without stacking card backgrounds.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.child, this.margin});
  final Widget child;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    if (!usesNativeFormControls) return Card(margin: margin, child: child);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        child,
        const Divider(height: 1, thickness: .5, indent: 16, endIndent: 16),
      ]),
    );
  }
}

class GlassActionButton extends StatelessWidget {
  const GlassActionButton({super.key, required this.label, required this.onPressed,
    this.prominent = false, this.compact = false, this.symbol});
  final String label;
  final VoidCallback? onPressed;
  final bool prominent;
  final bool compact;
  final String? symbol;

  @override
  Widget build(BuildContext context) {
    if (!usesNativeFormControls) {
      return prominent
          ? FilledButton(onPressed: onPressed, child: Text(label))
          : TextButton(onPressed: onPressed, child: Text(label));
    }
    const fontSize = 16.0;
    final button = Stack(alignment: Alignment.center, children: [
      Padding(padding: EdgeInsets.symmetric(horizontal: compact ? 14 : symbol == null ? 16 : 28),
        child: ExcludeSemantics(child: Opacity(opacity: 0, child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(widthFactor: 1, heightFactor: 1, child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontSize: fontSize, fontWeight: compact ? FontWeight.w500 : FontWeight.w600))),
        )))),
      Positioned.fill(child: GlassFormControl('action', {
        'label': label, 'symbol': symbol, 'enabled': onPressed != null,
        'compact': compact, 'fontSize': MediaQuery.textScalerOf(context).scale(fontSize), 'prominent': prominent, 'dark': Theme.of(context).brightness == Brightness.dark,
      }, (_) => onPressed?.call())),
    ]);
    return compact ? Center(widthFactor: 1, heightFactor: 1, child: ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 44), child: button)) : button;
  }
}
