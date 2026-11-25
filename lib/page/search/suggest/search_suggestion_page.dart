/*
 * Copyright (C) 2020. by perol_notsf, All rights reserved
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:bot_toast/bot_toast.dart';
import 'package:pixez/component/ipad_surface.dart';
import 'package:pixez/component/progressive_toolbar_blur.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/page/picture/illust_lighting_page.dart';
import 'package:pixez/page/saucenao/sauce_store.dart';
import 'package:pixez/page/search/result_page.dart';
import 'package:pixez/page/search/suggest/suggestion_store.dart';
import 'package:pixez/page/soup/soup_page.dart';
import 'package:pixez/page/user/users_page.dart';
import 'package:pixez/utils/haptic_util.dart';

class SearchSuggestionPage extends StatefulWidget {
  static const _inputHeight = 48.0;
  static const _topGap = 8.0;
  static const _titleGap = 12.0;
  static const inlineToolbarHeight = _inputHeight + 8.0;
  static const inlineToolbarWidth = 560.0;

  static double inlineToolbarTravel(BuildContext context) =>
      (MediaQuery.sizeOf(context).height * .22).clamp(0.0, 184.0).toDouble();
  final String? preword;
  final Widget? idleContent;
  final ScrollController? idleScrollController;
  final List<Widget> Function()? historySlivers;
  final ValueChanged<BuildContext>? onImageSearch;

  const SearchSuggestionPage({
    super.key,
    this.preword,
    this.idleContent,
    this.idleScrollController,
    this.historySlivers,
    this.onImageSearch,
  });

  @override
  _SearchSuggestionPageState createState() => _SearchSuggestionPageState();
}

class _SearchSuggestionPageState extends State<SearchSuggestionPage> {
  late TextEditingController _filter;
  late SuggestionStore _suggestionStore;
  late SauceStore _sauceStore;
  FocusNode focusNode = FocusNode();
  final tagGroup = [];
  bool idV = false;

  @override
  void initState() {
    idV = widget.preword != null && int.tryParse(widget.preword!) != null;
    _suggestionStore = SuggestionStore();
    _sauceStore = SauceStore();
    _sauceStore.observableStream.listen((event) {
      if (!mounted) return;
      if (event != null && _sauceStore.results.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PageView(
              children: _sauceStore.results
                  .map((element) => IllustLightingPage(id: element))
                  .toList(),
            ),
          ),
        );
      } else {
        BotToast.showText(text: I18n.ofContext().no_result);
      }
    });
    var query = widget.preword ?? '';
    _filter = TextEditingController(text: query);
    focusNode.addListener(_focusChanged);
    final tags = query.trim().split(RegExp(r'\s+'));
    if (tags.length > 1) tagGroup.addAll(tags);
    super.initState();
  }

  void _focusChanged() => setState(() {});

  @override
  void dispose() {
    focusNode.removeListener(_focusChanged);
    focusNode.dispose();
    _filter.dispose();
    _sauceStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final hasQuery = _filter.text.trim().isNotEmpty;
        final history = !hasQuery && widget.historySlivers != null
            ? widget.historySlivers!()
            : const <Widget>[];
        final suggestedTags = hasQuery
            ? _suggestionStore.autoWords?.tags
            : null;
        final hasSuggestions =
            history.isNotEmpty ||
            tagGroup.isNotEmpty ||
            idV ||
            (suggestedTags?.isNotEmpty ?? false);
        final suggestionList = CustomScrollView(
          primary: widget.idleContent == null ? null : false,
          shrinkWrap: widget.idleContent != null,
          slivers: [
            ...history,
            if (tagGroup.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Wrap(
                    spacing: 10,
                    children: [
                      for (String i in tagGroup)
                        ActionChip(
                          label: Text(i),
                          onPressed: () {
                            final start = _filter.text.indexOf(i);
                            if (start != -1)
                              _filter.selection = TextSelection.fromPosition(
                                TextPosition(offset: start + i.length),
                              );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            SliverVisibility(
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index == 0)
                    return ListTile(
                      title: Text(_filter.text),
                      subtitle: Text(I18n.of(context).illust_id),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => IllustLightingPage(
                              id: int.tryParse(_filter.text)!,
                            ),
                          ),
                        );
                      },
                    );
                  if (index == 1)
                    return ListTile(
                      title: Text(_filter.text),
                      subtitle: Text(I18n.of(context).painter_id),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                UsersPage(id: int.tryParse(_filter.text)!),
                          ),
                        );
                      },
                    );
                  if (index == 2 && _filter.text.length < 5)
                    return ListTile(
                      title: Text(_filter.text),
                      subtitle: Text("Pixivision Id"),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => SoupPage(
                              url:
                                  "https://www.pixivision.net/zh/a/${_filter.text.trim()}",
                              spotlight: null,
                            ),
                          ),
                        );
                      },
                    );
                  return ListTile();
                }, childCount: 3),
              ),
              visible: idV,
            ),
            if (suggestedTags != null && suggestedTags.isNotEmpty)
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final tags = suggestedTags;
                  return GestureDetector(
                    onLongPress: () {
                      HapticUtil.heavy();
                      Clipboard.setData(ClipboardData(text: tags[index].name));
                      BotToast.showText(
                        text: I18n.of(context).copied_to_clipboard,
                      );
                    },
                    child: ListTile(
                      onTap: () {
                        if (tagGroup.length > 1) {
                          tagGroup.last = tags[index].name;
                          var text = tagGroup.join(" ");
                          _filter.text = text;
                          _filter.selection = TextSelection.fromPosition(
                            TextPosition(offset: text.length),
                          );
                          setState(() {});
                        } else {
                          FocusScope.of(context).unfocus();
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (context) {
                                return ResultPage(
                                  word: tags[index].name,
                                  translatedName:
                                      tags[index].translated_name ?? "",
                                );
                              },
                            ),
                          );
                        }
                      },
                      title: Text(tags[index].name),
                      subtitle: Text(tags[index].translated_name ?? ""),
                    ),
                  );
                }, childCount: suggestedTags.length),
              ),
          ],
        );
        final suggestions = isIPhone
            ? ListTileTheme.merge(
                titleTextStyle: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontSize: 15, fontWeight: FontWeight.normal),
                subtitleTextStyle: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontSize: 13, fontWeight: FontWeight.normal),
                child: suggestionList,
              )
            : suggestionList;
        if (widget.idleContent != null) {
          return _buildInlineSearch(
            context,
            suggestions: hasSuggestions ? suggestions : null,
            hasQuery: hasQuery,
          );
        }
        return Scaffold(
          appBar: _buildAppBar(context),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _sauceStore.findImage(context: context),
            child: const Icon(Icons.add_photo_alternate),
          ),
          body: suggestions,
        );
      },
    );
  }

  Widget _buildInlineSearch(
    BuildContext context, {
    required Widget? suggestions,
    required bool hasQuery,
  }) {
    final padding = MediaQuery.paddingOf(context);
    final bottom =
        math.max(padding.bottom, MediaQuery.viewInsetsOf(context).bottom) + 8;
    final titleStyle = Theme.of(
      context,
    ).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.bold);
    final titleHeight =
        MediaQuery.textScalerOf(context).scale(titleStyle.fontSize!) + 8;
    final titleExtent = titleHeight + SearchSuggestionPage._titleGap;
    final focusedTop = padding.top + SearchSuggestionPage._topGap;
    final pinnedTop = focusedTop + titleExtent;
    final scroll = widget.idleScrollController;
    final travel = scroll == null
        ? 0.0
        : SearchSuggestionPage.inlineToolbarTravel(context);
    final maxWidth = isIPhone ? null : SearchSuggestionPage.inlineToolbarWidth;
    final focused = focusNode.hasFocus;

    return ListenableBuilder(
      listenable: scroll ?? const AlwaysStoppedAnimation<double>(0),
      child: _buildInlineField(context, maxWidth: maxWidth, hasQuery: hasQuery),
      builder: (context, field) {
        final offset = scroll != null && scroll.hasClients
            ? scroll.offset
            : 0.0;
        final idleTop = math.max(
          pinnedTop,
          padding.top + travel - math.max(0.0, offset),
        );
        return TweenAnimationBuilder<double>(
          tween: Tween(end: focused ? 1.0 : 0.0),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
          child: field,
          builder: (context, progress, field) {
            final fieldTop = lerpDouble(idleTop, focusedTop, progress)!;
            final widthFactor = isIPhone ? lerpDouble(.84, 1, progress)! : 1.0;
            final sideInset = isIPhone ? 8.0 * progress : 0.0;
            return Stack(
              fit: StackFit.expand,
              children: [
                NotificationListener<ScrollStartNotification>(
                  onNotification: (notification) {
                    if (notification.dragDetails != null) focusNode.unfocus();
                    return false;
                  },
                  child: widget.idleContent!,
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: pinnedTop + SearchSuggestionPage.inlineToolbarHeight,
                  child: const ProgressiveToolbarBlur(),
                ),
                if (progress > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        key: const ValueKey('search-background-scrim'),
                        color: Colors.black.withValues(alpha: .36 * progress),
                      ),
                    ),
                  ),
                if (suggestions != null && progress > 0)
                  Positioned(
                    key: const ValueKey('inline-search-suggestions'),
                    top: fieldTop + SearchSuggestionPage.inlineToolbarHeight,
                    left: sideInset,
                    right: sideInset,
                    bottom: bottom,
                    child: IgnorePointer(
                      ignoring: !focused,
                      child: Opacity(
                        opacity: progress,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: FractionallySizedBox(
                            widthFactor: widthFactor,
                            child: TextFieldTapRegion(
                              child: IPadSurface(
                                maxWidth: maxWidth,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ClipRRect(
                                    key: const ValueKey(
                                      'search-suggestions-panel',
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    child: suggestions,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: lerpDouble(idleTop - titleExtent, focusedTop, progress),
                  left: 0,
                  right: 0,
                  height: titleHeight,
                  child: IgnorePointer(
                    child: Opacity(
                      key: const ValueKey('search-title-opacity'),
                      opacity: (1 - 2 * progress).clamp(0.0, 1.0),
                      child: Center(
                        child: Semantics(
                          header: true,
                          child: Text(
                            I18n.of(context).search,
                            style: titleStyle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  key: const ValueKey('inline-search-field'),
                  top: fieldTop,
                  left: sideInset,
                  right: sideInset,
                  child: FractionallySizedBox(
                    widthFactor: widthFactor,
                    child: field,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInlineField(
    BuildContext context, {
    required double? maxWidth,
    required bool hasQuery,
  }) {
    return TextFieldTapRegion(
      child: IPadSurface(
        maxWidth: maxWidth,
        child: SizedBox(
          key: const ValueKey('search-input-toolbar'),
          height: SearchSuggestionPage._inputHeight,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: I18n.of(context).search,
                onPressed: hasQuery
                    ? () => _submitSearch(_filter.text)
                    : focusNode.requestFocus,
              ),
              Expanded(
                child: _textField(context, TextInputType.text, focusNode),
              ),
              if (_filter.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _filter.clear();
                    onChange('');
                  },
                ),
              IconButton(icon: const Icon(Icons.paste), onPressed: _paste),
              Builder(
                builder: (anchor) => IconButton(
                  icon: const Icon(Icons.image_search_outlined),
                  onPressed: () {
                    focusNode.unfocus();
                    widget.onImageSearch?.call(anchor);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _paste() async {
    try {
      final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
      if (!mounted || text == null || text.isEmpty) return;
      focusNode.requestFocus();
      _filter.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      await onChange(text);
    } on PlatformException {
      // The system can deny clipboard access.
    }
  }

  AppBar _buildAppBar(context) {
    return AppBar(
      title: _textField(context, TextInputType.text, focusNode),
      iconTheme: IconThemeData(
        color: Theme.of(context).textTheme.bodyLarge!.color,
      ),
      actions: <Widget>[
        IconButton(
          icon: Icon(
            Icons.close,
            color: Theme.of(context).textTheme.bodyLarge!.color,
          ),
          onPressed: () {
            _filter.clear();
          },
        ),
        IconButton(
          icon: Icon(
            Icons.paste,
            color: Theme.of(context).textTheme.bodyLarge!.color,
          ),
          onPressed: _paste,
        ),
      ],
    );
  }

  Future<void> onChange(String query) async {
    tagGroup.clear();
    final tags = query.trim().split(RegExp(r'\s+'));
    if (tags.length > 1) tagGroup.addAll(tags);
    setState(() {});
    bool isNum = int.tryParse(query) != null;
    setState(() {
      idV = isNum;
    });
    if (query.startsWith('https://')) {
      focusNode.unfocus();
      Leader.pushWithUri(context, Uri.parse(query));
      _filter.clear();
      return;
    }
    var word = query.trim();
    if (word.isEmpty) return;
    if (isNum && word.length > 5) return; //超过五个数字应该就不需要给建议了吧
    word = tags.last;
    if (word.isEmpty) return;
    _suggestionStore.fetch(word);
  }

  void _submitSearch(String query) {
    final word = query.trim();
    if (word.isEmpty) return;
    focusNode.unfocus();
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (context) => ResultPage(word: word)));
  }

  TextField _textField(
    BuildContext context,
    TextInputType inputType,
    FocusNode node,
  ) {
    return TextField(
      controller: _filter,
      focusNode: node,
      keyboardType: inputType,
      autofocus: widget.idleContent == null,
      onTapOutside: widget.idleContent == null ? null : (_) => node.unfocus(),
      cursorColor: Theme.of(context).iconTheme.color,
      style: Theme.of(context).textTheme.titleMedium!.copyWith(
        color: Theme.of(context).iconTheme.color,
        fontSize: isIPhone ? 15 : null,
        fontWeight: isIPhone ? FontWeight.normal : null,
      ),
      onTap: () {
        FocusScope.of(context).requestFocus(node);
      },
      onChanged: (query) {
        onChange(query);
      },
      onSubmitted: _submitSearch,
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: I18n.of(context).search_word_or_paste_link,
      ),
    );
  }
}
