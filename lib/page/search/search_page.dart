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

import 'package:pixez/component/ipad_surface.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:material_ui/material_ui.dart' hide SearchBar;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/tags.dart';
import 'package:pixez/models/trend_tags.dart';
import 'package:pixez/page/picture/illust_lighting_page.dart';
import 'package:pixez/page/preview/preview_page.dart';
import 'package:pixez/page/saucenao/sauce_nao_modal.dart';
import 'package:pixez/page/search/result_page.dart';
import 'package:pixez/page/search/search_bar.dart';
import 'package:pixez/page/search/suggest/search_suggestion_page.dart';
import 'package:pixez/page/search/trend_tags_store.dart';
import 'package:pixez/page/webview/saucenao_webview_page.dart';
import 'package:pixez/utils/haptic_util.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  SearchPageState createState() => SearchPageState();
}

class SearchPageState extends State<SearchPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  Future<void> refreshGrid() async {
    await _trendTagsStore.fetch();
    if (mounted) setState(() => _gridRefresh++);
  }

  String editString = "";
  final _discoveryScroll = ScrollController();
  int _searchReset = 0;
  int _gridRefresh = 0;

  bool _pickingSauceNaoImage = false;

  Future<void> _imageSearch(BuildContext context) async {
    if (Platform.isIOS) {
      if (_pickingSauceNaoImage) return;
      _pickingSauceNaoImage = true;
      try {
        await SauceNaoModal.showFromPicker(context);
      } finally {
        _pickingSauceNaoImage = false;
      }
    } else if (userSetting.useSaunceNaoWebview) {
      Leader.push(context, SauncenaoWebview());
    } else {
      await SauceNaoModal.show(context);
    }
  }

  late TrendTagsStore _trendTagsStore;
  late AnimationController _animationController;
  late Animation<double> animation;
  late StreamSubscription<String> _topSubscription;
  late ReactionDisposer _accountReaction;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationController.forward();
  }

  @override
  void initState() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    animation = Tween(begin: 0.0, end: 0.25).animate(_animationController);

    _trendTagsStore = TrendTagsStore();
    _tabController = TabController(length: 3, vsync: this);
    super.initState();
    _accountReaction = reaction((_) => (accountStore.now?.userId, userSetting.locale), (selection) {
      if (selection.$1 != null) tagHistoryStore.fetch();
      _trendTagsStore.fetch();
    }, fireImmediately: true);
    _topSubscription = topStore.topStream.listen((event) {
      if (event != '400' || !mounted || accountStore.now == null) return;
      if (usesAppleControls(context)) {
        FocusManager.instance.primaryFocus?.unfocus();
        setState(() => _searchReset++);
        if (_discoveryScroll.hasClients) _discoveryScroll.jumpTo(0);
      } else {
        _openSearch();
      }
    });
  }

  void _openSearch() {
    if (!mounted) return;
    Navigator.push(
      context,
      PageRouteBuilder(pageBuilder: (_, __, ___) => SearchSuggestionPage()),
    );
  }

  @override
  void dispose() {
    _topSubscription.cancel();
    _accountReaction();
    _discoveryScroll.dispose();
    _animationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildFirstRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Container(
            child: Padding(
              child: Text(
                I18n.of(context).search,
                style: TextStyle(
                  fontWeight: isIPhone ? FontWeight.normal : FontWeight.bold,
                  fontSize: isIPhone ? 28 : 30.0,
                  color: Theme.of(context).textTheme.titleLarge!.color,
                ),
              ),
              padding: EdgeInsets.only(left: 16.0, bottom: 10.0),
            ),
          ),
        ],
      ),
    );
  }

  bool _tagExpand = false;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(
      builder: (context, snapshot) {
        return Observer(
          builder: (_) {
            if (accountStore.now == null) return const LoginInFirst();
            if (usesAppleControls(context)) {
              return SafeArea(
                top: false,
                bottom: false,
                child: SearchSuggestionPage(
                  key: ValueKey(_searchReset),
                  onImageSearch: _imageSearch,
                  historySlivers: () => _inlineHistorySlivers(context),
                  idleContent: _buildContent(context, snapshot),
                  idleScrollController: _discoveryScroll,
                ),
              );
            }
            return NestedScrollView(
              body: _buildContent(context, snapshot),
              headerSliverBuilder:
                  (BuildContext context, bool innerBoxIsScrolled) {
                    return [
                      SliverToBoxAdapter(
                        child: Container(
                          height: MediaQuery.of(context).padding.top,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: IPadSurface(
                          maxWidth: 700,
                          child: SearchBar(onSaucenao: _imageSearch),
                        ),
                      ),
                    ];
                  },
            );
          },
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, BoxConstraints snapshot) {
    final tags = _trendTagsStore.visibleTrendTags;
    final apple = usesAppleControls(context);
    final columnCount = max(
      3,
      (snapshot.maxWidth / (apple ? 245 : 200)).floor(),
    );
    final top = apple
        ? MediaQuery.paddingOf(context).top +
              SearchSuggestionPage.inlineToolbarHeight
        : 0.0;
    final toolbarTravel = apple
        ? SearchSuggestionPage.inlineToolbarTravel(context)
        : 0.0;
    final gridGap = (toolbarTravel * .55).clamp(0.0, 96.0).toDouble();
    return RefreshIndicator(
      edgeOffset: top,
      onRefresh: refreshGrid,
      child: CustomScrollView(
        controller: apple ? _discoveryScroll : null,
        slivers: [
          if (apple)
            SliverToBoxAdapter(
              child: SizedBox(height: top + toolbarTravel + gridGap),
            )
          else ...[
            SliverToBoxAdapter(child: _buildFirstRow(context)),
            ..._historySlivers(context),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  I18n.of(context).recommand_tag,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ],
          if (tags.isNotEmpty)
            SliverPadding(
              key: ValueKey((
                accountStore.now?.userId,
                Object.hashAll(muteStore.banTags.map((tag) => tag.name)),
              )),
              padding: EdgeInsets.symmetric(
                horizontal: usesIPadLayout(context) ? 40 : 12,
                vertical: 8,
              ),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _SearchGridTile(
                    tag: tags[index],
                    refresh: _gridRefresh,
                    builder: (context, tag, image) => GestureDetector(
                      onTap: () {
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(
                            builder: (_) {
                              return ResultPage(word: tag.tag);
                            },
                          ),
                        );
                      },
                      onLongPress: () {
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(
                            builder: (_) {
                              return IllustLightingPage(id: tag.illust.id);
                            },
                          ),
                        );
                      },
                      child: Card(
                        margin: usesAppleControls(context)
                            ? EdgeInsets.zero
                            : null,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(apple ? 12 : 8),
                        ),
                        child: Stack(
                          children: <Widget>[
                            Positioned.fill(child: image),
                            if (apple)
                              const Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black87,
                                      ],
                                      stops: [0.38, 1],
                                    ),
                                  ),
                                ),
                              )
                            else
                              Opacity(
                                opacity: 0.4,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            Align(
                              child: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      "#${tag.tag}",
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: isIPhone
                                            ? 15
                                            : apple
                                            ? 16
                                            : 12,
                                      ),
                                    ),
                                    if (tag.translatedName?.isNotEmpty == true)
                                      Text(
                                        tag.translatedName!,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isIPhone
                                              ? 13
                                              : apple
                                              ? 14
                                              : 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              alignment: Alignment.bottomCenter,
                            ),
                            if (apple)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _SearchTileGlassEdge(
                                      Theme.of(context).brightness,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  childCount: tags.length,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columnCount,
                  childAspectRatio: 1.0,
                  mainAxisSpacing: usesAppleControls(context) ? 2 : 0,
                  crossAxisSpacing: usesAppleControls(context) ? 2 : 0,
                ),
              ),
            ),
          if (apple)
            SliverLayoutBuilder(
              builder: (context, constraints) => SliverToBoxAdapter(
                child: SizedBox(
                  height: max(
                    32.0,
                    constraints.viewportMainAxisExtent +
                        toolbarTravel -
                        constraints.precedingScrollExtent,
                  ),
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: SizedBox(
                height: (MediaQuery.sizeOf(context).width / 3) - 16,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _inlineHistorySlivers(BuildContext context) {
    final tags = tagHistoryStore.tags
        .where((tag) => tag.type == null || tag.type == 0)
        .toList();
    if (tags.isEmpty) return const [];
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      I18n.of(context).history,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: isIPhone ? 13 : null, fontWeight: isIPhone ? FontWeight.normal : null),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 19),
                    tooltip: I18n.of(context).clear_search_tag_history,
                    onPressed: () => _confirmClearHistory(context),
                  ),
                ],
              ),
              Wrap(
                runSpacing: 4,
                spacing: 8,
                children: [
                  for (final tag in tags.take(_tagExpand ? tags.length : 12))
                    buildActionChip(tag, context, inline: true),
                  if (tags.length > 12)
                    ActionChip(
                      label: Icon(
                        _tagExpand ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _tagExpand = !_tagExpand),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ];
  }

  void _confirmClearHistory(BuildContext context) {
    HapticUtil.heavy();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(I18n.of(dialogContext).clean_history),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(I18n.of(dialogContext).cancel),
            ),
            TextButton(
              onPressed: () {
                tagHistoryStore.deleteAll();
                Navigator.of(dialogContext).pop();
              },
              child: Text(I18n.of(dialogContext).ok),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _historySlivers(BuildContext context) => [
    SliverToBoxAdapter(
      child: Observer(
        builder: (context) {
          if (tagHistoryStore.tags
              .where((element) => element.type == null || element.type == 0)
              .isNotEmpty)
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    I18n.of(context).history,
                    style: TextStyle(
                      fontSize: 16.0,
                      color: Theme.of(context).textTheme.headlineSmall!.color,
                    ),
                  ),
                ],
              ),
            );
          else
            return Container();
        },
      ),
    ),
    SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      sliver: SliverToBoxAdapter(
        child: Observer(
          builder: (BuildContext context) {
            if (tagHistoryStore.tags.isNotEmpty) {
              final targetTags = tagHistoryStore.tags
                  .where((element) => element.type == null || element.type == 0)
                  .toList();
              if (targetTags.length > 20) {
                final resultTags = targetTags.sublist(0, 12);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5.0),
                  child: Wrap(
                    children: [
                      for (var f in _tagExpand ? targetTags : resultTags)
                        buildActionChip(f, context),
                      ActionChip(
                        label: AnimatedSwitcher(
                          duration: Duration(milliseconds: 300),
                          transitionBuilder: (child, anim) {
                            return ScaleTransition(child: child, scale: anim);
                          },
                          child: Icon(
                            !_tagExpand ? Icons.expand_more : Icons.expand_less,
                          ),
                        ),
                        padding: EdgeInsets.all(0.0),
                        onPressed: () {
                          setState(() {
                            _tagExpand = !_tagExpand;
                          });
                        },
                      ),
                    ],
                    runSpacing: 0.0,
                    spacing: 5.0,
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5.0),
                child: Wrap(
                  children: [
                    for (var f in targetTags) buildActionChip(f, context),
                  ],
                  runSpacing: 0.0,
                  spacing: 3.0,
                ),
              );
            }
            return Container();
          },
        ),
      ),
    ),
    SliverToBoxAdapter(
      child: Observer(
        builder: (context) {
          if (tagHistoryStore.tags
              .where((element) => element.type == null || element.type == 0)
              .isNotEmpty)
            return InkWell(
              onTap: () => _confirmClearHistory(context),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 18.0,
                        color: Theme.of(context).textTheme.bodySmall!.color,
                      ),
                      Text(
                        I18n.of(context).clear_search_tag_history,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: Theme.of(context).textTheme.bodySmall!.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          return Container();
        },
      ),
    ),
  ];

  Widget buildActionChip(
    TagsPersist f,
    BuildContext context, {
    bool inline = false,
  }) {
    return GestureDetector(
      onLongPress: () {
        HapticUtil.heavy();
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('${I18n.of(context).delete}?'),
              actions: [
                TextButton(
                  onPressed: () {
                    tagHistoryStore.delete(f.id!);
                    Navigator.of(context).pop();
                  },
                  child: Text(I18n.of(context).ok),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(I18n.of(context).cancel),
                ),
              ],
            );
          },
        );
      },
      child: ActionChip(
        padding: inline
            ? const EdgeInsets.symmetric(horizontal: 6)
            : EdgeInsets.zero,
        label: Text(
          f.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: isIPhone ? const TextStyle(fontSize: 12, fontWeight: FontWeight.normal) : inline ? null : const TextStyle(fontSize: 12.0),
        ),
        onPressed: () {
          FocusManager.instance.primaryFocus?.unfocus();
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (context) =>
                  ResultPage(word: f.name, translatedName: f.translatedName),
            ),
          );
        },
      ),
    );
  }

  late TabController _tabController;

  @override
  bool get wantKeepAlive => true;
}

class _SearchGridTile extends StatefulWidget {
  const _SearchGridTile({required this.tag, required this.refresh, required this.builder});

  final TrendTags tag;
  final int refresh;
  final Widget Function(BuildContext, TrendTags, Widget) builder;

  @override
  State<_SearchGridTile> createState() => _SearchGridTileState();
}

class _SearchGridTileState extends State<_SearchGridTile>
    with SingleTickerProviderStateMixin {
  late final _fade =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      )..addStatusListener((status) {
        if (status != AnimationStatus.completed || _previous == null) return;
        setState(() {
          _previous?.dispose();
          _previous = null;
        });
      });
  ImageStream? _stream;
  ImageStreamListener? _listener;
  String? _requestedUrl;
  String? _displayedUrl;
  TrendTags? _displayedTag;
  ImageInfo? _image;
  ImageInfo? _previous;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadImage();
  }

  @override
  void didUpdateWidget(_SearchGridTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadImage(retry: oldWidget.refresh != widget.refresh && _stream == null);
  }

  void _loadImage({bool retry = false}) {
    final url = widget.tag.illust.imageUrls.squareMedium;
    final animate = !MediaQuery.disableAnimationsOf(context);
    if (_displayedUrl == url) _displayedTag = widget.tag;
    if (_requestedUrl == url && !retry) return;
    _requestedUrl = url;
    _stopListening();
    if (url.isEmpty || _displayedUrl == url) return;

    final stream = PixivProvider.url(
      url,
    ).resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((image, synchronous) {
      _stopListening();
      void showImage() {
        final shouldFade = animate && (!synchronous || _image != null);
        _previous?.dispose();
        _previous = shouldFade ? _image : null;
        if (!shouldFade) _image?.dispose();
        _image = image;
        _displayedUrl = url;
        _displayedTag = widget.tag;
        if (shouldFade) {
          _fade.forward(from: 0);
        } else {
          _fade.value = 1;
        }
      }

      if (synchronous) {
        showImage();
      } else {
        setState(showImage);
      }
    }, onError: (_, _) => _stopListening());
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  void _stopListening() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _listener = null;
    _stream = null;
  }

  @override
  void dispose() {
    _stopListening();
    _fade.dispose();
    _previous?.dispose();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previous = _previous;
    final image = _image;
    return widget.builder(
      context,
      _displayedTag ?? widget.tag,
      Stack(
        fit: StackFit.expand,
        children: [
          if (previous != null)
            RawImage(
              image: previous.image,
              scale: previous.scale,
              fit: BoxFit.cover,
            ),
          if (image != null)
            FadeTransition(
              opacity: _fade,
              child: RawImage(
                image: image.image,
                scale: image.scale,
                fit: BoxFit.cover,
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchTileGlassEdge extends CustomPainter {
  const _SearchTileGlassEdge(this.brightness);

  final Brightness brightness;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1);
    final rim = RRect.fromRectAndRadius(rect, const Radius.circular(11));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: brightness == Brightness.dark
            ? const [
                Color(0x8CE4EBFF),
                Color(0x358D9AB6),
                Color(0x75232A38),
                Color(0x70B9C7E2),
              ]
            : const [
                Color(0xD9FFFFFF),
                Color(0x26FFFFFF),
                Color(0x73000000),
                Color(0xBFFFFFFF),
              ],
        stops: [0, .38, .73, 1],
      ).createShader(rect);
    canvas.drawRRect(rim, paint);
  }

  @override
  bool shouldRepaint(_SearchTileGlassEdge oldDelegate) =>
      oldDelegate.brightness != brightness;
}
