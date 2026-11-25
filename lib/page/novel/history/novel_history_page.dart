/*
 * Copyright (C) 2020. by perol_notsf, All rights reserved
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful, but WITHOUT ANY
 *  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 *  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along with
 *  this program. If not, see <http://www.gnu.org/licenses/>.
 */
import 'package:material_ui/material_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/component/ipad_surface.dart';
import 'package:pixez/main.dart';
import 'package:pixez/page/novel/viewer/novel_viewer.dart';
import 'package:pixez/utils/haptic_util.dart';

class NovelHistory extends StatefulWidget {
  @override
  _NovelHistoryState createState() => _NovelHistoryState();
}

class _NovelHistoryState extends State<NovelHistory> {
  @override
  void initState() {
    novelHistoryStore.fetch();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        return Scaffold(
          appBar: AppBar(title: Text(I18n.of(context).history)),
          floatingActionButton: GalleryFavoriteButton(heroTag: 'novel-history-clear',
            child: Icon(Icons.delete_forever),
            onPressed: () async {
              HapticUtil.selectionClick();
              final result = await showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Text(
                      "${I18n.of(context).delete} ${I18n.of(context).all}?",
                    ),
                    actions: <Widget>[
                      TextButton(
                        child: Text(I18n.of(context).cancel),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: Text(I18n.of(context).ok),
                        onPressed: () {
                          Navigator.of(context).pop("OK");
                        },
                      ),
                    ],
                  );
                },
              );
              if (result == "OK") {
                novelHistoryStore.deleteAll();
              }
            },
          ),
          body: novelHistoryStore.data.isNotEmpty
              ? isIPhone
                    ? GridView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                          mainAxisExtent:
                              64 +
                              MediaQuery.textScalerOf(context).scale(16) * 5,
                        ),
                        itemCount: novelHistoryStore.data.length,
                        itemBuilder: (context, index) {
                          final novel = novelHistoryStore.data[index];
                          return Card(
                            child: InkWell(
                              onTap: () {
                                HapticUtil.selectionClick();
                                Leader.push(
                                  context,
                                  NovelViewerPage(id: novel.novelId),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      novel.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      novel.userName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    const Spacer(),
                                    Align(
                                      alignment: AlignmentDirectional.bottomEnd,
                                      child: IconButton(
                                        tooltip: I18n.of(context).delete,
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () {
                                          HapticUtil.selectionClick();
                                          novelHistoryStore.delete(
                                            novel.novelId,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    : ListView.builder(
                        itemBuilder: (context, index) {
                          final novel = novelHistoryStore.data[index];
                          return ListTile(
                            title: Text(novel.title),
                            subtitle: Text(novel.userName),
                            onTap: () {
                              HapticUtil.selectionClick();
                              Leader.push(
                                context,
                                NovelViewerPage(id: novel.novelId),
                              );
                            },
                            trailing: IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () {
                                HapticUtil.selectionClick();
                                novelHistoryStore.delete(novel.novelId);
                              },
                            ),
                          );
                        },
                        itemCount: novelHistoryStore.data.length,
                      )
              : Container(),
        );
      },
    );
  }
}
