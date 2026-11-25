import 'package:pixez/component/ipad_surface.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/page/search/suggest/search_suggestion_page.dart';

class SearchBar extends StatefulWidget {
  final ValueChanged<BuildContext>? onSaucenao;
  const SearchBar({Key? key, this.onSaucenao}) : super(key: key);

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  late TextEditingController _textEditingController;
  @override
  void initState() {
    _textEditingController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (usesAppleControls(context)) {
      return SizedBox(height: 48, child: Row(children: [
        Expanded(child: InkWell(onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SearchSuggestionPage())),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
            const Icon(Icons.search), const SizedBox(width: 10),
            Expanded(child: Text(I18n.of(context).search_word_hint)),
          ])))),
        Builder(
          builder: (anchor) => IconButton(
            icon: const Icon(Icons.image_search_outlined),
            onPressed: () => widget.onSaucenao?.call(anchor),
          ),
        ),
      ]));
    }
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.grey.withValues(alpha: 0.4),
      ),
      child: Container(
        height: 48,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              margin: const EdgeInsets.only(left: 8, right: 2),
              child: IconButton(icon: Icon(Icons.search), onPressed: () {}),
            ),
            Expanded(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => SearchSuggestionPage(),
                    ),
                  );
                },
                child: Container(
                  child: Text(
                    I18n.of(context).search_word_hint,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).textTheme.displaySmall!.color,
                    ),
                  ),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 8, left: 4),
              child: Builder(
                builder: (anchor) => IconButton(
                  icon: const Icon(Icons.image_search),
                  onPressed: () => widget.onSaucenao?.call(anchor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
