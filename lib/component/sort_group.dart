import 'package:pixez/component/ipad_surface.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/utils/haptic_util.dart';

class SortGroup extends StatefulWidget {
  final List<String> children;
  final Function onChange;
  final int initIndex;
  final bool compact;

  const SortGroup({
    Key? key,
    required this.children,
    required this.onChange,
    this.initIndex = 0,
    this.compact = false,
  }) : super(key: key);

  @override
  _SortGroupState createState() => _SortGroupState();
}

class _SortGroupState extends State<SortGroup> {
  int index = 0;

  @override
  void initState() {
    this.index = widget.initIndex;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (usesAppleControls(context)) {
      return GlassSegmentPicker(
        compact: widget.compact,
        labels: widget.children,
        index: index,
        onSelect: (i) {
          HapticUtil.selectionClick();
          widget.onChange(i);
          if (mounted) setState(() => index = i);
        },
      );
    }
    return SegmentedButton(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.disabled)) {
            return null;
          }
          if (states.contains(WidgetState.selected)) {
            return Theme.of(context).colorScheme.secondaryContainer;
          }
          return Theme.of(context).colorScheme.surface;
        }),
      ),
      segments: [
        for (var (index, i) in widget.children.indexed)
          ButtonSegment(value: index, label: Text(i)),
      ],
      selected: {this.index},
      onSelectionChanged: (p0) {
        HapticUtil.selectionClick();
        widget.onChange(p0.first);
        if (mounted)
          setState(() {
            this.index = p0.first;
          });
      },
    );
  }
}
