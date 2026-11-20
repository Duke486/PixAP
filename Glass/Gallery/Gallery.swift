import SwiftUI

@main struct GalleryApp: App {
    var body: some Scene { WindowGroup { Gallery() } }
}

struct Print: Identifiable, Hashable {
    let title: String
    let colors: [UInt32]
    let seed: Int
    var id: Int { seed }
    var palette: [Color] { colors.map { Color(red: Double($0 >> 16)/255, green: Double(($0 >> 8)&255)/255, blue: Double($0&255)/255) } }
    static let works = [
        Print(title:"山海之间", colors:[0x9db8bc,0xffd49a,0xfad79d,0x779596,0x436d72,0x193f47],seed:1),
        Print(title:"暮色来信", colors:[0xac7589,0xf2bb92,0xffddaa,0xa47383,0x775c70,0x403b59],seed:2),
        Print(title:"蓝调时分", colors:[0x556f9b,0xbbd2db,0xf0e6ba,0x7794ac,0x4b6b88,0x243d59],seed:3),
        Print(title:"赤岩", colors:[0xd9946f,0xffddaa,0xffe8b0,0xbf795f,0x975545,0x613c3c],seed:4),
        Print(title:"雾林", colors:[0x9aa897,0xeddfbb,0xf5e6b8,0x84988a,0x597b70,0x33564f],seed:5)
    ]
}

struct Landscape: View {
    let work: Print
    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height, palette = work.palette
            let bounds = CGRect(origin:.zero,size:size)
            context.fill(Path(bounds),with:.linearGradient(Gradient(colors:Array(palette.prefix(2))),startPoint:.zero,endPoint:CGPoint(x:0,y:h)))
            let r = min(w,h)*0.13
            context.fill(Path(ellipseIn:CGRect(x:w*0.69-r,y:h*0.29-r,width:2*r,height:2*r)),with:.color(palette[2]))
            for layer in 0..<3 {
                var mountain = Path()
                mountain.move(to:CGPoint(x:0,y:h))
                for i in 0...320 {
                    let t = Double(i)/320, a = t*8 + Double(work.seed*2+layer*5)
                    let ridge = sin(a)*0.09 + sin(2.3*a)*0.042 + sin(6.7*a)*0.013 + sin(17*a)*0.005
                    mountain.addLine(to:CGPoint(x:t*w,y:h*(0.52+Double(layer)*0.13+ridge)))
                }
                mountain.addLine(to:CGPoint(x:w,y:h))
                mountain.closeSubpath()
                context.fill(mountain,with:.color(palette[3+layer]))
            }
            // Tiny deterministic flecks lend the flat inks a paper grain.
            var random = UInt64(work.seed)
            func sample() -> Double {
                random = random &* 6364136223846793005 &+ 1
                return Double(random >> 32)/Double(UInt32.max)
            }
            var flecks = Path()
            for _ in 0..<Int(min(w*h/32,14000)) {
                flecks.addEllipse(in:CGRect(x:sample()*w,y:sample()*h,width:1.3,height:0.8))
            }
            context.fill(flecks,with:.color(.white.opacity(0.16)))
        }.accessibilityHidden(true)
    }
}

struct Gallery: View {
    @State private var selected = 0
    @State private var query = ""
    @State private var detail: Print?
    @State private var fullscreen = false
    @State private var category = 0
    @State private var rank = 0
    let tabs = ["首页", "排行", "速览", "搜索", "更多"]
    let symbols = ["house", "chart.bar", "heart", "magnifyingglass", "ellipsis"]
    private func cards(_ works: [Print]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 195), spacing: 14)], spacing: 18) {
            ForEach(works) { work in
                Button { detail = work } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        Landscape(work: work).aspectRatio(1.4, contentMode: .fit)
                            .clipShape(.rect(cornerRadius: 12))
                        Text(work.title).font(.subheadline.weight(.medium))
                    }
                }.buttonStyle(.plain)
            }
        }
    }
    var body: some View {
        GeometryReader { geometry in

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selected {
                    case 0:
                        Text("亮点").font(.title2.bold())
                        ScrollView(.horizontal) {
                            HStack(spacing: 12) {
                                ForEach(Print.works) { work in
                                    Button { detail = work } label: {
                                        Landscape(work: work).frame(width: 200, height: 98)
                                            .overlay(alignment: .bottomLeading) {
                                                Text(work.title).font(.headline).foregroundStyle(.white).padding(10)
                                            }.clipShape(.rect(cornerRadius: 12))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }.scrollIndicators(.hidden)
                        Text("为你推荐").font(.title2.bold())
                        cards(Print.works)
                    case 1:
                        Picker("排行周期", selection: $rank) {
                            ForEach(Array(["每日", "每周", "每月"].enumerated()), id: \.offset) { i, title in Text(title).tag(i) }
                        }.pickerStyle(.segmented)
                        cards(Array(Print.works.dropFirst(rank)) + Array(Print.works.prefix(rank)))
                    case 2:
                        Picker("速览", selection: $category) {
                            ForEach(Array(["动态", "收藏", "追更列表", "已关注"].enumerated()), id: \.offset) { i, title in Text(title).tag(i) }
                        }.pickerStyle(.segmented)
                        ContentUnavailableView("登录后查看", systemImage: "person.crop.circle")
                    case 3:
                        TextField("搜索作品", text: $query).textFieldStyle(.roundedBorder)
                        cards(Print.works.filter { query.isEmpty || $0.title.contains(query) })
                    default:
                        ForEach(["账户信息", "历史记录", "画质设置", "收藏标签", "屏蔽设置", "下载任务", "漫画", "小说"], id: \.self) { text in
                            Text(text).padding(.vertical, 5)
                            Divider()
                        }
                    }
                }.padding(.horizontal, 86).padding(.vertical, 16)
            }.navigationTitle(tabs[selected]).navigationBarTitleDisplayMode(.inline)
        }
        .overlay(alignment: .leading) {
            ArtworkNavigation(labels: tabs, selected: selected) { selected = $0 }.padding(.leading, 12)
        }
        }
        .sheet(item:$detail,onDismiss:{fullscreen = false}) { work in
            NavigationStack {
                Landscape(work:work).aspectRatio(1.6,contentMode:.fit).padding()
                    .navigationTitle(work.title)
                    .toolbar {
                        ToolbarItem(placement:.cancellationAction) { Button("关闭",systemImage:"xmark"){detail=nil} }
                        ToolbarItem { Button("全屏",systemImage:"arrow.up.left.and.arrow.down.right"){fullscreen=true} }
                    }
            }.presentationSizing(.page)
            .fullScreenCover(isPresented:$fullscreen) {
                ZStack(alignment:.topTrailing) {
                    Color.black.ignoresSafeArea()
                    Landscape(work:work).aspectRatio(1.6,contentMode:.fit).frame(maxWidth:.infinity,maxHeight:.infinity)
                    Button("关闭",systemImage:"xmark"){fullscreen=false}.labelStyle(.iconOnly).buttonStyle(.glass).padding()
                }
            }
        }
    }
}
