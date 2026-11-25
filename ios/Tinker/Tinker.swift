//
//  Tinker.swift
//  Tinker
//
//  Created by Perol Notsf on 2024/7/8.
//

import AppIntents
import ImageIO
import SwiftUI
import WidgetKit

struct Provider: TimelineProvider {
    var placeHolderEntry: SimpleEntry {
        return SimpleEntry(date: .now, uiImage: nil, id: 1, illustId: 1, userId: 1, pictureUrl: "https://pixiv.net//", title: "No content available", userName: ":(", time: 0, type: "empty")
    }

    func placeholder(in context: Context) -> SimpleEntry {
        placeHolderEntry
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        Task.detached(priority: .utility) {
            completion(cachedEntry(from: AppWidgetDBManager.fetch()) ?? placeHolderEntry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task.detached(priority: .utility) {
            let illusts = AppWidgetDBManager.fetch()
            var entry = cachedEntry(from: illusts)
            if entry == nil {
                entry = await downloadedEntry(from: illusts)
            }
            let refreshDate = Date.now.addingTimeInterval(entry == nil ? 15 * 60 : 30 * 60)
            completion(Timeline(entries: [entry ?? placeHolderEntry], policy: .after(refreshDate)))
        }
    }

    private func cachedEntry(from illusts: [AppWidgetIllust]) -> SimpleEntry? {
        for illust in illusts {
            if let data = illust.thumbnail, let image = UIImage(data: data) {
                return illust.toSimple(uiImage: image)
            }
        }
        guard let folder = AppWidgetDBManager.illustFolder() else { return nil }
        for illust in illusts {
            let url = illust.largeUrl ?? illust.pictureUrl
            let suffix = url.split(separator: ".").last ?? "png"
            let path = folder.appendingPathComponent("\(illust.id).\(suffix)")
            if let source = CGImageSourceCreateWithURL(path as CFURL, nil),
               let image = thumbnail(from: source) {
                return illust.toSimple(uiImage: image)
            }
        }
        return nil
    }

    private func downloadedEntry(from illusts: [AppWidgetIllust]) async -> SimpleEntry? {
        // Compatible with databases written before the app began sharing thumbnails.
        for illust in illusts.prefix(2) {
            guard let url = URL(string: illust.pictureUrl) else { continue }
            var request = URLRequest(url: url, timeoutInterval: 4)
            request.setValue("https://app-api.pixiv.net/", forHTTPHeaderField: "Referer")
            request.setValue("PixivIOSApp/5.8.0", forHTTPHeaderField: "User-Agent")
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = thumbnail(from: source)
            else { continue }
            return illust.toSimple(uiImage: image)
        }
        return nil
    }

    private func thumbnail(from source: CGImageSource) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1024,
            kCGImageSourceShouldCache: false,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: image)
    }
}

extension AppWidgetIllust {
    func toSimple(uiImage: UIImage) -> SimpleEntry {
        SimpleEntry(date: .now, uiImage: uiImage, id: id, illustId: illustId, userId: userId, pictureUrl: pictureUrl, title: title, userName: userName, time: time, type: type)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let uiImage: UIImage?
    let id: Int
    let illustId: Int
    let userId: Int
    let pictureUrl: String
    let title: String?
    let userName: String?
    let time: Int
    let type: String
}

struct TinkerEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        buildContent()
    }

    @ViewBuilder func buildContent() -> some View {
        GeometryReader { red in
            ZStack {
                if entry.type != "empty", let uiImage = entry.uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: red.size.width, height: red.size.height, alignment: .center)
                }
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(entry.title ?? "")")
                                .font(.title3)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .shadow(radius: 5, x: 0, y: 5)
                            Text("@\(entry.userName ?? "")")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .shadow(radius: 5, x: 0, y: 5)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(
                        LinearGradient(gradient: Gradient(colors: [.black.opacity(0.0), .black.opacity(0.4)]), startPoint: .top, endPoint: .bottom)
                    )
                }
            }.frame(width: red.size.width, height: red.size.height, alignment: .center)
        }.widgetURL(URL(string: entry.type == "empty" ? "pixez://pixiv.net" : "pixez://pixiv.net/artworks/\(entry.illustId)"))
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct SuperCharge: AppIntent {
    static var title: LocalizedStringResource = "Refresh recommend illust"
    static var description = IntentDescription("Refresh recommend illust")

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct Tinker: Widget {
    let kind: String = "Tinker"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                ZStack {
                    Color.clear
                    VStack {
                        Spacer()
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(entry.title ?? "")")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .shadow(radius: 5, x: 0, y: 5)
                                Text("@\(entry.userName ?? "")")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .shadow(radius: 5, x: 0, y: 5)
                            }
                            Spacer()
                        }
                    }
                    VStack {
                        HStack(alignment: .top) {
                            Spacer()
                            Button(intent: SuperCharge()) {
                                Image(systemName: "arrow.clockwise")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 4)
                        }
                        Spacer()
                    }
                }
                .widgetURL(URL(string: entry.type == "empty" ? "pixez://pixiv.net" : "pixez://pixiv.net/artworks/\(entry.illustId)"))
                .containerBackground(for: .widget) {
                    ZStack {
                        if let image = entry.uiImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        }
                    }
                }
            } else {
                TinkerEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
    }
}

struct Tinker_Previews: PreviewProvider {
    static var previews: some View {
        let entry = SimpleEntry(date: .now, uiImage: nil, id: 1, illustId: 1, userId: 1, pictureUrl: "https://pixiv.net//", title: "Title", userName: "User", time: 0, type: "")
        TinkerEntryView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
