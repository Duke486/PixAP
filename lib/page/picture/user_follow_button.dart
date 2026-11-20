import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/follow_detail_alert.dart';
import 'package:pixez/component/ipad_surface.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/utils/haptic_util.dart';

class UserFollowButton extends StatefulWidget {
  final int id;
  final bool followed;
  final bool glass;
  final Future<Null> Function() onPressed;
  final Function(bool follow, String restrict) onConfirm;
  const UserFollowButton({
    super.key,
    required this.id,
    required this.followed,
    this.glass = false,
    required this.onPressed,
    required this.onConfirm,
  });

  @override
  State<UserFollowButton> createState() => _UserFollowButtonState();
}

class _UserFollowButtonState extends State<UserFollowButton> {
  late bool _followed;
  bool _loading = false;
  @override
  void initState() {
    _followed = widget.followed;
    super.initState();
  }

  @override
  void didUpdateWidget(covariant UserFollowButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _followed = widget.followed;
  }

  Future<void> _toggleFollow() async {
    if (_loading) return;
    if (_followed) {
      HapticUtil.light();
    } else {
      HapticUtil.medium();
    }
    setState(() => _loading = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.glass && usesIPadLayout(context)) {
      return IPadSurface(
        child: TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: _loading ? null : _toggleFollow,
          onLongPress: _loading ? null : _longPressAction,
          child: _loading
              ? const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                )
              : Text(
                  _followed
                      ? I18n.of(context).followed
                      : I18n.of(context).follow,
                ),
        ),
      );
    }
    if (_loading) {
      return Container(
        height: 32,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1),
            ),
          ),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.secondary),
        ),
      );
    }
    if (_followed) {
      return GestureDetector(
        onTap: _toggleFollow,
        onLongPress: () {
          _longPressAction();
        },
        child: Container(
          height: 32,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                I18n.of(context).followed,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.secondary),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: _toggleFollow,
      onLongPress: () {
        _longPressAction();
      },
      child: Container(
        height: 32,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              I18n.of(context).follow,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }

  _longPressAction() {
    HapticUtil.heavy();
    showDialog(
      context: context,
      builder: (context) {
        return FollowDetailAlert(
          id: widget.id,
          onConfirm: (follow, restrict) {
            widget.onConfirm(follow, restrict);
          },
        );
      },
    );
  }
}
