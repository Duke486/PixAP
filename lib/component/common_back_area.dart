import 'package:material_ui/material_ui.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/component/ipad_surface.dart';

class CommonBackArea extends StatefulWidget {
  const CommonBackArea({super.key});

  @override
  State<CommonBackArea> createState() => _CommonBackAreaState();
}

class _CommonBackAreaState extends State<CommonBackArea> {
  bool _isLongPress = false;
  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      child: IconButton(
        tooltip: isIPhone ? MaterialLocalizations.of(context).backButtonTooltip : null,
        icon: _isLongPress ? Icon(Icons.home) : BackButtonIcon(),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      onLongPress: () {
        setState(() {
          _isLongPress = true;
        });
        Leader.popUtilHome(context);
      },
    );
    return isIPhone ? Padding(padding: const EdgeInsetsDirectional.only(start: 8), child: IPadSurface(circular: true, child: button)) : button;
  }
}
