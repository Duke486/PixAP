//
//  AppWidgetDBManager.swift
//  SsssGridManExtension
//
//  Created by Perol Notsf on 2022/9/9.
//

import FMDB
import Foundation

struct AppWidgetIllust {
    let id: Int
    let illustId: Int
    let userId: Int
    let pictureUrl: String
    let largeUrl: String?
    let thumbnail: Data?
    let title: String?
    let userName: String?
    let time: Int
    let type: String
}

enum AppWidgetDBManager {
    static let tableIllustPersist = "glanceillustpersist"
    static let cid = "id"
    static let cillust_id = "illust_id"
    static let cuser_id = "user_id"
    static let cpicture_url = "picture_url"
    static let clarge_url = "large_url"
    static let ctitle = "title"
    static let cuser_name = "user_name"
    static let ctime = "time"
    static let ctype = "type"
    
    static func fetch() -> [AppWidgetIllust] {
        let selectedType = UserDefaults(suiteName: "group.com.duke486.pixez.ipad")?.string(forKey: "widget_illust_type") ?? "recom"
        guard let container = containerURL() else {
            return []
        }
        let url = container.appendingPathComponent("DB/glanceillustpersist.db")
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let db = FMDatabase(path: url.path)
        guard db.open() else { return [] }
        defer { db.close() }
        var illusts = [AppWidgetIllust]()
        do {
            let qSet = try db.executeQuery(
                "SELECT * FROM \(tableIllustPersist) WHERE type = ? ORDER BY time DESC LIMIT 40",
                values: [selectedType]
            )
            defer { qSet.close() }
            let thumbnailColumn = qSet.columnIndex(forName: "thumbnail")
            let largeURLColumn = qSet.columnIndex(forName: clarge_url)
            while qSet.next() {
                guard let pictureURL = qSet.string(forColumn: cpicture_url) else { continue }
                illusts.append(AppWidgetIllust(
                    id: Int(qSet.longLongInt(forColumn: cid)),
                    illustId: Int(qSet.longLongInt(forColumn: cillust_id)),
                    userId: Int(qSet.longLongInt(forColumn: cuser_id)),
                    pictureUrl: pictureURL,
                    largeUrl: largeURLColumn >= 0 ? qSet.string(forColumnIndex: largeURLColumn) : nil,
                    thumbnail: thumbnailColumn >= 0 ? qSet.data(forColumnIndex: thumbnailColumn) : nil,
                    title: qSet.string(forColumn: ctitle),
                    userName: qSet.string(forColumn: cuser_name),
                    time: Int(qSet.longLongInt(forColumn: ctime)),
                    type: selectedType
                ))
            }
        } catch {
            print("db query error === \(error.localizedDescription)")
        }
        return illusts.shuffled()
    }

    private static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.duke486.pixez.ipad")
    }

    static func illustFolder() -> URL? {
        containerURL()?.appendingPathComponent("Illusts", isDirectory: true)
    }
}
