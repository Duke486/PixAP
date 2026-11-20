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
import 'dart:math' as math;
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/component/progressive_toolbar_blur.dart';
import 'package:pixez/main.dart';
import 'package:pixez/page/hello/ranking/rank_store.dart';
import 'package:pixez/page/hello/ranking/ranking_mode/rank_mode_page.dart';
import 'package:pixez/utils/haptic_util.dart';

class RankPage extends StatefulWidget {
  RankPage({Key? key});

  @override
  _RankPageState createState() => _RankPageState();
}

class _RankPageState extends State<RankPage>
    with AutomaticKeepAliveClientMixin {
  late RankStore rankStore;
  final modeList = [
    "day",
    "day_male",
    "day_female",
    "week_original",
    "week_rookie",
    "week",
    "month",
    "day_ai",
    "day_r18_ai",
    "day_r18",
    "week_r18",
    "week_r18g",
  ];
  var boolList = Map<int, bool>();
  late DateTime nowDate;
  late StreamSubscription<String> subscription;
  String? dateTime;
  TabController? _tabs;

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }

  @override
  void initState() {
    nowDate = DateTime.now();
    rankStore = RankStore()..init();
    int i = 0;
    modeList.forEach((element) {
      boolList[i] = false;
      i++;
    });
    super.initState();
    subscription = topStore.topStream.listen((event) {
      if (event == "200") {
        topStore.setTop((201 + (_tabs?.index ?? 0)).toString());
      }
    });
  }

  String toRequestDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  DateTime nowDateTime = DateTime.now();
  int tapCount = 0;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final strings = I18n.of(context);
    final rankListMean = strings.mode_list.split(' ');
    final labels = [
      for (final (i, mode) in modeList.indexed)
        switch (mode) {
          'day_r18_ai' => '🆁18 AI',
          'day_r18' => '🆁18',
          'week_r18' => '🆁18 ${strings.rank_weekly}',
          'week_r18g' => '🆁18 ${strings.rank_grotesque}',
          _ => rankListMean[i],
        },
    ];
    return Observer(
      builder: (_) {
        final modes = rankStore.modeList.toList();
        if (rankStore.inChoice || modes.isEmpty) {
          _tabs = null;
          return _buildChoicePage(context, labels);
        }
        final titles = [
          for (final mode in modes) labels[modeList.indexOf(mode)],
        ];
        final showToolbar = !fullScreenStore.fullscreen;
        return DefaultTabController(
          length: modes.length,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final controller = _tabs = DefaultTabController.of(context);
              final tablet = usesIPadLayout(context);
              final media = MediaQuery.of(context);
              final scheme = Theme.of(context).colorScheme;
              final reselectStyle = Theme.of(context).textTheme.labelLarge;
              final reselectPainter = TextPainter(
                text: TextSpan(
                  text: strings.rank_reselect,
                  style: reselectStyle,
                ),
                textDirection: Directionality.of(context),
                textScaler: media.textScaler,
              )..layout();
              final reselectWidth = math.max(
                kMinInteractiveDimension,
                reselectPainter.width.ceilToDouble() + 16,
              );
              reselectPainter.dispose();
              final iconButtonCount = Platform.isAndroid ? 2 : 1;
              final actions = [
                if (Platform.isAndroid)
                  SizedBox(
                    width: kMinInteractiveDimension,
                    child: IconButton(
                      icon: const Icon(Icons.fullscreen),
                      onPressed: fullScreenStore.toggle,
                    ),
                  ),
                SizedBox(
                  width: reselectWidth,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: reselectStyle,
                    ),
                    onPressed: rankStore.reset,
                    child: Text(strings.rank_reselect),
                  ),
                ),
                SizedBox(
                  width: kMinInteractiveDimension,
                  child: IconButton(
                    icon: const Icon(Icons.date_range),
                    onPressed: () => _showTimePicker(context),
                  ),
                ),
              ];
              const outerInset = 8.0;
              const trackInset = 4.0;
              const spacing = 2.0;
              const labelPadding = 6.0;
              final labelStyle = Theme.of(context).textTheme.labelLarge!
                  .copyWith(fontSize: 14, fontWeight: FontWeight.w600);
              // Measure against the same width and spacing used by the Wrap so
              // the artwork starts below the last row on narrow screens.
              final width = math.max(
                1.0,
                constraints.maxWidth -
                    media.padding.horizontal -
                    iconButtonCount * kMinInteractiveDimension -
                    reselectWidth -
                    outerInset -
                    trackInset * 2,
              );
              var rowHeight = 36.0;
              var rowWidth = 0.0;
              final rows = <List<int>>[[]];
              final widths = <double>[];
              for (final title in titles) {
                final painter = TextPainter(
                  text: TextSpan(text: title, style: labelStyle),
                  textDirection: Directionality.of(context),
                  textScaler: media.textScaler,
                )..layout(maxWidth: math.max(1.0, width - labelPadding * 2));
                final labelWidth = math.min(
                  width,
                  painter.width.ceilToDouble() + labelPadding * 2,
                );
                rowHeight = math.max(
                  rowHeight,
                  painter.height.ceilToDouble() + 8,
                );
                painter.dispose();
                if (rowWidth > 0 && rowWidth + spacing + labelWidth > width) {
                  rows.add([]);
                  rowWidth = 0;
                }
                rows.last.add(widths.length);
                widths.add(labelWidth);
                rowWidth += (rowWidth > 0 ? spacing : 0) + labelWidth;
              }
              final toolbarHeight = math.max(
                kToolbarHeight,
                rows.length * rowHeight +
                    (rows.length - 1) * spacing +
                    trackInset * 4,
              );
              final top = showToolbar ? media.padding.top + toolbarHeight : 0.0;
              final picker = DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: .035),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(trackInset),
                  child: AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) => Wrap(
                      alignment: WrapAlignment.center,
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        for (final (i, title) in titles.indexed)
                          Semantics(
                            selected: i == controller.index,
                            child: SizedBox(
                              width: widths[i],
                              height: rowHeight,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.standard,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: labelPadding,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  foregroundColor: scheme.onSurface,
                                  backgroundColor: i == controller.index
                                      ? scheme.onSurface.withValues(alpha: .08)
                                      : Colors.transparent,
                                ),
                                onPressed: () {
                                  HapticUtil.selectionClick();
                                  controller.animateTo(i);
                                },
                                child: Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  style: labelStyle.copyWith(
                                    color: i == controller.index
                                        ? scheme.onSurface
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
              final nativePicker = AnimatedBuilder(
                animation: controller,
                builder: (context, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: spacing,
                  children: [
                    for (final row in rows)
                      SizedBox(
                        width: 6 + row.fold(0.0, (sum, i) => sum + widths[i]),
                        height: rowHeight,
                        child: NativeGlassControl(
                          horizontal: true,
                          prominent: true,
                          labels: [for (final i in row) titles[i]],
                          segmentWidths: [for (final i in row) widths[i]],
                          index: row.indexOf(controller.index),
                          onSelect: (i) {
                            HapticUtil.selectionClick();
                            controller.animateTo(row[i]);
                          },
                        ),
                      ),
                  ],
                ),
              );
              return Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: tablet ? 0 : top),
                    child: TabBarView(
                      children: [
                        for (final (i, mode) in modes.indexed)
                          RankModePage(
                            key: ValueKey((mode, dateTime)),
                            date: dateTime,
                            mode: mode,
                            index: i,
                            topInset: tablet ? top : 0,
                          ),
                      ],
                    ),
                  ),
                  if (showToolbar)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: top,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (tablet)
                            const ProgressiveToolbarBlur()
                          else
                            ColoredBox(color: scheme.surface),
                          SafeArea(
                            bottom: false,
                            child: Material(
                              type: MaterialType.transparency,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: outerInset,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Center(
                                        child: tablet ? nativePicker : picker,
                                      ),
                                    ),
                                    ...actions,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildChoicePage(BuildContext context, List<String> labels) {
    final strings = I18n.of(context);
    Future<void> save() async {
      await rankStore.saveChange(boolList);
      rankStore.inChoice = false;
    }

    return Column(
      children: [
        AppBar(elevation: 0, title: Text(strings.choice_you_like)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
            children: [
              Wrap(
                spacing: 4,
                children: [
                  for (final (i, label) in labels.indexed)
                    FilterChip(
                      label: Text(label),
                      selected: boolList[i] ?? false,
                      onSelected: (selected) =>
                          setState(() => boolList[i] = selected),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: defaultTargetPlatform == TargetPlatform.iOS
                    ? IPadSurface(
                        includeIPhone: true,
                        darkGlass:
                            Theme.of(context).brightness == Brightness.dark,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(
                              120,
                              kMinInteractiveDimension,
                            ),
                          ),
                          onPressed: save,
                          child: Text(strings.save),
                        ),
                      )
                    : FilledButton.tonal(
                        onPressed: save,
                        child: Text(strings.save),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _pickingDate = false;

  Future<void> _showTimePicker(BuildContext context) async {
    if (_pickingDate) return;
    final today = DateUtils.dateOnly(DateTime.now());
    final earliest = DateTime(2007, 8);
    final initial = DateUtils.dateOnly(nowDateTime);
    final DateTime? date;
    _pickingDate = true;
    try {
      date = await _pickDate(context, earliest, today, initial);
    } finally {
      _pickingDate = false;
    }
    if (date != null && mounted) {
      nowDateTime = date;
      final requestDate = toRequestDate(date);
      setState(() => dateTime = requestDate);
    }
  }

  Future<DateTime?> _pickDate(
    BuildContext context,
    DateTime earliest,
    DateTime latest,
    DateTime initial,
  ) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      List<int> parts(DateTime date) => [date.year, date.month, date.day];
      try {
        final strings = I18n.of(context);
        final result = await const MethodChannel('pixez/rankDatePicker')
            .invokeListMethod<int>('pick', {
              'initial': parts(initial),
              'minimum': parts(earliest),
              'maximum': parts(latest),
              'title': MaterialLocalizations.of(context).datePickerHelpText,
              'cancel': strings.cancel,
              'done': strings.ok,
              'locale': Localizations.localeOf(context).toLanguageTag(),
              'dark': Theme.of(context).brightness == Brightness.dark,
            });
        return result == null || result.length != 3
            ? null
            : DateTime(result[0], result[1], result[2]);
      } on MissingPluginException {
        // Use the in-app calendar when the native bridge is unavailable.
      } on PlatformException {
        // Use the in-app calendar when iOS cannot present the picker.
      }
    }
    if (!context.mounted) return null;
    return showDatePicker(
      context: context,
      initialDate: initial,
      locale: userSetting.locale,
      firstDate: earliest,
      lastDate: latest,
    );
  }

  @override
  bool get wantKeepAlive => true;
}
