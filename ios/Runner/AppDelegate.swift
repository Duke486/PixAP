import UIKit
import LocalAuthentication
import SwiftUI
import Flutter
import ImageIO
import MobileCoreServices
import Photos
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    
    // 🎵 Morning Dew - Single - AryaMusic Records & ciaffa
    // https://music.apple.com/cn/album/morning-dew/1686069386?i=1686069387
    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        let device = FlutterMethodChannel(name: "pixez/device",
            binaryMessenger: engineBridge.applicationRegistrar.messenger())
        device.setMethodCallHandler { call, result in
            guard call.method == "isPhone" else {
                result(FlutterMethodNotImplemented)
                return
            }
            result(UIDevice.current.userInterfaceIdiom == .phone)
        }
        let session = FlutterMethodChannel(name: "pixez/demoSession",
            binaryMessenger: engineBridge.applicationRegistrar.messenger())
        session.setMethodCallHandler { [weak self] call, result in
            let key = "flutter.demo_mode_enabled"
            if call.method == "active" {
                result(UserDefaults.standard.bool(forKey: key))
                return
            }
            guard call.method == "restart", let enabled = call.arguments as? Bool,
                  let window = self?.visibleViewController()?.view.window else {
                result(FlutterError(code: "restart_unavailable", message: nil, details: nil))
                return
            }
            let defaults = UserDefaults.standard
            if enabled {
                for name in ["language_num", "cross_count", "h_cross_count", "theme_mode"] {
                    if let value = defaults.object(forKey: "flutter." + name) {
                        defaults.set(value, forKey: "pixap.demo." + name)
                    }
                }
            }
            defaults.set(enabled, forKey: key)
            result(nil)
            DispatchQueue.main.async {
                window.rootViewController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController()
                window.makeKeyAndVisible()
            }
        }
        let batteryChannel = FlutterMethodChannel(name: "samples.flutter.dev/battery",
                                                  binaryMessenger: engineBridge.applicationRegistrar.messenger())
        batteryChannel.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            guard call.method == "getBatteryLevel" else {
                result(FlutterMethodNotImplemented)
                return
            }
            let args = call.arguments as? [String:Any]
            
            
            let path : String = args?["path"] as! String
            let delay:Int = args?["delay"] as! Int
            self.receiveBatteryLevel(result: result,path: path ,delay: delay)
            
        })
        if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PixezGlassRail") {
            registrar.register(FadingBackdropFactory(), withId: "pixez/fadingBackdrop")
            registrar.register(FormControlFactory(registrar.messenger()), withId: "pixez/formControl")
            registrar.register(GlassSurfaceFactory(), withId: "pixez/glassSurface")
            registrar.register(GlassRailFactory(registrar.messenger()), withId: "pixez/glassRail")
        }
        DocumentPlugin.bind(engineBridge)
        DeepLinkPlugin.register(with: engineBridge.pluginRegistry.registrar(forPlugin: "DeepLinkPlugin")!)
        bindAppWidgetChannel(engineBridge)
        let colors = FlutterMethodChannel(name: "pixez/themeColor", binaryMessenger: engineBridge.applicationRegistrar.messenger())
        colors.setMethodCallHandler { [weak self] call, result in
            guard call.method == "pick", let value = call.arguments as? NSNumber,
                  let presenter = self?.visibleViewController(), !(presenter is UIColorPickerViewController) else {
                result(nil)
                return
            }
            let picker = ThemeColorPicker()
            picker.complete = result
            picker.delegate = picker
            picker.supportsAlpha = false
            let rgb = value.uint32Value
            picker.selectedColor = UIColor(red: CGFloat(rgb >> 16 & 255) / 255,
                green: CGFloat(rgb >> 8 & 255) / 255, blue: CGFloat(rgb & 255) / 255, alpha: 1)
            picker.modalPresentationStyle = .pageSheet
            presenter.present(picker, animated: true)
            picker.presentationController?.delegate = picker
        }
        bindRankDatePicker(engineBridge)
        bindSauceNaoImagePreparation(engineBridge)
        let historyChannel = FlutterMethodChannel(
            name: "pixez/historyPrivacy",
            binaryMessenger: engineBridge.applicationRegistrar.messenger()
        )
        historyChannel.setMethodCallHandler { call, result in
            guard call.method == "authenticate" else {
                result(FlutterMethodNotImplemented)
                return
            }
            let auth = LAContext()
            auth.localizedFallbackTitle = ""
            guard auth.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil),
                  auth.biometryType == .faceID else {
                result(false)
                return
            }
            auth.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                localizedReason: call.arguments as? String ?? "View browsing history") { success, _ in
                DispatchQueue.main.async { result(success) }
            }
        }
    }

    private func bindSauceNaoImagePreparation(_ engineBridge: FlutterImplicitEngineBridge) {
        let channel = FlutterMethodChannel(
            name: "pixez/sauceNaoImage",
            binaryMessenger: engineBridge.applicationRegistrar.messenger()
        )
        channel.setMethodCallHandler { [weak self] call, result in
            if call.method == "pickSource" {
                guard let self else {
                    result(nil)
                    return
                }
                self.presentSauceNaoSource(call.arguments, result: result)
                return
            }
            guard call.method == "prepare" else {
                result(FlutterMethodNotImplemented)
                return
            }
            guard let path = call.arguments as? String, !path.isEmpty else {
                result(FlutterError(code: "invalid_path", message: nil, details: nil))
                return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                let jpeg = autoreleasepool {
                    Self.prepareThumbnailJPEG(
                        at: URL(fileURLWithPath: path), maxPixelSize: 1440, compressionQuality: 0.78
                    )
                }
                DispatchQueue.main.async {
                    guard let jpeg else {
                        result(FlutterError(code: "unsupported_image", message: nil, details: nil))
                        return
                    }
                    result(FlutterStandardTypedData(bytes: jpeg))
                }
            }
        }
    }

    private func presentSauceNaoSource(_ arguments: Any?, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any],
              let x = args["x"] as? Double, let y = args["y"] as? Double,
              let width = args["width"] as? Double, let height = args["height"] as? Double,
              let photos = args["photos"] as? String, let files = args["files"] as? String,
              let presenter = visibleViewController(),
              let sourceView = presenter.viewIfLoaded, let window = sourceView.window,
              presenter.presentedViewController == nil
        else {
            result(FlutterError(code: "picker_unavailable", message: nil, details: nil))
            return
        }
        let picker = SauceNaoSourcePopover(photos: photos, files: files, result: result)
        picker.modalPresentationStyle = .popover
        let popover = picker.popoverPresentationController
        popover?.sourceView = sourceView
        let anchor = CGRect(x: x, y: y, width: width, height: height).intersection(window.bounds)
        let windowRect = anchor.isEmpty
            ? CGRect(x: window.bounds.midX, y: window.safeAreaInsets.top, width: 1, height: 1)
            : anchor
        popover?.sourceRect = sourceView.convert(windowRect, from: window)
        popover?.permittedArrowDirections = [.up, .down]
        popover?.delegate = picker
        presenter.present(picker, animated: true)
    }

    private static func prepareThumbnailJPEG(at url: URL, maxPixelSize: Int, compressionQuality: CGFloat) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCache: false,
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        return UIImage(cgImage: image).jpegData(compressionQuality: compressionQuality)
    }

    private func bindRankDatePicker(_ engineBridge: FlutterImplicitEngineBridge) {
        let channel = FlutterMethodChannel(name: "pixez/rankDatePicker",
                                           binaryMessenger: engineBridge.applicationRegistrar.messenger())
        channel.setMethodCallHandler { [weak self] call, result in
            guard call.method == "pick" else {
                result(FlutterMethodNotImplemented)
                return
            }
            let foregroundWindow = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first(where: { $0.activationState == .foregroundActive && $0.keyWindow != nil })?.keyWindow
            guard let args = call.arguments as? [String: Any],
                  let presenter = foregroundWindow?.rootViewController ?? self?.visibleViewController(),
                  presenter.viewIfLoaded?.window != nil,
                  presenter.presentedViewController == nil,
                  let picker = RankDatePickerController(arguments: args, result: result) else {
                result(FlutterError(code: "picker_unavailable", message: nil, details: nil))
                return
            }
            let navigation = UINavigationController(rootViewController: picker)
            navigation.overrideUserInterfaceStyle = (args["dark"] as? Bool ?? false) ? .dark : .light
            navigation.modalPresentationStyle = .formSheet
            navigation.preferredContentSize = CGSize(width: 420, height: 300)
            navigation.presentationController?.delegate = picker
            presenter.present(navigation, animated: true)
        }
    }

    private func bindAppWidgetChannel(_ engineBridge: FlutterImplicitEngineBridge) {
        let appWidgetChannel = FlutterMethodChannel(name: "com.perol.dev/app_widget",
                                                    binaryMessenger: engineBridge.applicationRegistrar.messenger())
        appWidgetChannel.setMethodCallHandler { call, result in
            let appGroup = "group.com.duke486.pixez.ipad"
            switch call.method {
            case "databaseDirectory":
                guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
                    result(FlutterError(code: "widget_container_unavailable", message: nil, details: nil))
                    return
                }
                let directory = container.appendingPathComponent("DB", isDirectory: true)
                do {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    result(directory.path)
                } catch {
                    result(FlutterError(code: "widget_directory_unavailable", message: error.localizedDescription, details: nil))
                }
            case "makeThumbnail":
                guard let path = call.arguments as? String else {
                    result(FlutterError(code: "bad_args", message: "path is required", details: nil))
                    return
                }
                DispatchQueue.global(qos: .utility).async {
                    let data = autoreleasepool {
                        Self.prepareThumbnailJPEG(
                            at: URL(fileURLWithPath: path), maxPixelSize: 1024, compressionQuality: 0.82
                        )
                    }
                    DispatchQueue.main.async { result(data.map { FlutterStandardTypedData(bytes: $0) }) }
                }
            case "setRecommendType":
                guard let args = call.arguments as? [String: Any], let type = args["type"] as? String else {
                    result(FlutterError(code: "bad_args", message: "type is required", details: nil))
                    return
                }
                UserDefaults(suiteName: appGroup)?.set(type, forKey: "widget_illust_type")
                WidgetCenter.shared.reloadTimelines(ofKind: "Tinker")
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    @objc private func saveImage(image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: AnyObject) {
        var showMessage = ""
        if error != nil{
            showMessage = "保存失败"
        }else{
            showMessage = "保存成功"
        }
        print("encode result: \(showMessage)")
    }
    
    func getAllFilePath(_ dirPath: String) -> [String]? {
        var filePaths = [String]()
        
        do {
            let array = try FileManager.default.contentsOfDirectory(atPath: dirPath)
            
            for fileName in array {
                var isDir: ObjCBool = true
                
                let fullPath = "\(dirPath)/\(fileName)"
                
                if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir) {
                    if !isDir.boolValue {
                        filePaths.append(fullPath)
                    }
                }
            }
            
        } catch let error as NSError {
            print("get file path error: \(error)")
        }
        
        return filePaths;
    }
    
    func saveImageInAlbum(albumName: String = "",gifPath:String) {
        var assetAlbum: PHAssetCollection?
        if albumName.isEmpty {
            let list = PHAssetCollection
                .fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary,
                                       options: nil)
            assetAlbum = list[0]
        } else {
            let list = PHAssetCollection
                .fetchAssetCollections(with: .album, subtype: .any, options: nil)
            list.enumerateObjects({ (album, index, stop) in
                let assetCollection = album
                if albumName == assetCollection.localizedTitle {
                    assetAlbum = assetCollection
                    stop.initialize(to: true)
                }
            })
            if assetAlbum == nil {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetCollectionChangeRequest
                        .creationRequestForAssetCollection(withTitle: albumName)
                }, completionHandler: { (isSuccess, error) in
                    self.saveImageInAlbum(albumName: albumName,gifPath: gifPath)
                })
                return
            }
        }
        PHPhotoLibrary.shared().performChanges({
            let url = URL(fileURLWithPath: gifPath)
            let result =   PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
            
            
            if !albumName.isEmpty {
                let assetPlaceholder =   result?.placeholderForCreatedAsset
                let albumChangeRequset = PHAssetCollectionChangeRequest(for:
                                                                            assetAlbum!)
                albumChangeRequset!.addAssets([assetPlaceholder!]  as NSArray)
            }
        }) { (isSuccess: Bool, error: Error?) in
            if isSuccess {
                DispatchQueue.main.async {
                    let alertController = UIAlertController(title: "encode success", message: nil, preferredStyle: UIAlertController.Style.alert)
                    self.visibleViewController()?.present(alertController, animated: true, completion: nil)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
                        alertController.dismiss(animated: true, completion: nil)
                    }
                }
                print("Your image was successfully saved")
            } else{
                print(error!.localizedDescription)
                
            }
        }
    }
    
    private func receiveBatteryLevel(result: FlutterResult,path:String,delay:Int) {
        let docs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let gifPath =  docs[0] as String + "/"+String(Int(Date.init().timeIntervalSince1970)) + ".gif"
        var paths = getAllFilePath(path)
        paths =  paths?.sorted{$0.localizedStandardCompare($1) == .orderedAscending}
        let imageArray: NSMutableArray = NSMutableArray()
        for i in paths! {
            print(i)
            let image = UIImage.init(named: i)
            if image != nil {
                imageArray.add(image!)
            }
            
        }
        let ok = saveGifToDocument(imageArray: imageArray, gifPath,delay: delay)
        if(ok){
            saveImageInAlbum(albumName: "pxez", gifPath: gifPath)
            
        }
        result(Int(1))
    }
    
    func saveGifToDocument(imageArray images: NSArray, _ gifPath: String,delay:Int) -> Bool {
        guard images.count > 0 &&
                gifPath.utf8CString.count > 0 else {
            return false
        }
        
        let url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, gifPath as CFString, .cfurlposixPathStyle, false)
        let destion = CGImageDestinationCreateWithURL(url!, kUTTypeGIF, images.count, nil)
        let adelay = Float(delay)/Float(1000)
        print("delay time\(adelay)")
        let delayTime = [kCGImagePropertyGIFUnclampedDelayTime as String:adelay]
        let destDic   = [kCGImagePropertyGIFDictionary as String:delayTime]
        let gifPropertiesDic:NSMutableDictionary = NSMutableDictionary()
        gifPropertiesDic.setValue(0, forKey: kCGImagePropertyGIFLoopCount as String)//
        let gifDictionaryDestDic = [kCGImagePropertyGIFDictionary as String:gifPropertiesDic]
        CGImageDestinationSetProperties(destion!,gifDictionaryDestDic as CFDictionary?);
        for image in images {
            CGImageDestinationAddImage(destion!, (image as! UIImage).cgImage!, destDic as CFDictionary)
            print("kkkkkkkk\(images.count)")
        }
        return CGImageDestinationFinalize(destion!)
    }
    
    private func visibleViewController() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        return visibleViewController(from: window?.rootViewController)
    }
    
    private func visibleViewController(from viewController: UIViewController?) -> UIViewController? {
        if let navigationController = viewController as? UINavigationController {
            return visibleViewController(from: navigationController.visibleViewController)
        }
        if let tabBarController = viewController as? UITabBarController {
            return visibleViewController(from: tabBarController.selectedViewController)
        }
        if let presentedViewController = viewController?.presentedViewController {
            return visibleViewController(from: presentedViewController)
        }
        return viewController
    }
}

private final class SauceNaoSourcePopover: UIViewController, UIPopoverPresentationControllerDelegate {
    private let photos: String
    private let files: String
    private var result: FlutterResult?

    init(photos: String, files: String, result: @escaping FlutterResult) {
        self.photos = photos
        self.files = files
        self.result = result
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = CGSize(width: 156, height: 91)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        let divider = UIView()
        divider.backgroundColor = .separator
        divider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        let stack = UIStackView(arrangedSubviews: [
            button(photos, icon: "photo.on.rectangle", source: "photos"),
            divider,
            button(files, icon: "folder", source: "files"),
        ])
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func button(_ title: String, icon: String, source: String) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.image = UIImage(systemName: icon)
        configuration.imagePadding = 8
        configuration.baseForegroundColor = .label
        let button = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in
            guard let self else { return }
            self.dismiss(animated: true) { self.complete(source) }
        })
        button.contentHorizontalAlignment = .leading
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return button
    }

    func adaptivePresentationStyle(
        for controller: UIPresentationController,
        traitCollection: UITraitCollection
    ) -> UIModalPresentationStyle {
        .none
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        complete(nil)
    }

    private func complete(_ source: String?) {
        let callback = result
        result = nil
        callback?(source)
    }
}

private final class GlassRailFactory: NSObject, FlutterPlatformViewFactory {
    let messenger: FlutterBinaryMessenger
    init(_ messenger: FlutterBinaryMessenger) { self.messenger = messenger }
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
    func create(withFrame frame: CGRect, viewIdentifier id: Int64, arguments: Any?) -> FlutterPlatformView {
        let args = arguments as? [String: Any] ?? [:]
        if #unavailable(iOS 26), args["phoneTabs"] as? Bool == true {
            return PhoneTabsView(frame, id, args, messenger)
        }
        return GlassRailView(frame, id, args, messenger)
    }
}

private func navigationTint(_ args: [String: Any]) -> UIColor? {
    guard let tint = (args["tint"] as? NSNumber)?.uint32Value else { return nil }
    return UIColor(red: CGFloat((tint >> 16) & 255) / 255,
                   green: CGFloat((tint >> 8) & 255) / 255,
                   blue: CGFloat(tint & 255) / 255,
                   alpha: CGFloat(tint >> 24) / 255)
}

private final class GlassRailView: NSObject, FlutterPlatformView {
    private let host: UIHostingController<ArtworkNavigation>
    private let channel: FlutterMethodChannel
    init(_ frame: CGRect, _ id: Int64, _ args: [String: Any], _ messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "pixez/glassRail/\(id)", binaryMessenger: messenger)
        self.channel = channel
        let selection = ArtworkNavigationSelection(args["index"] as? Int ?? 0)
        func content(_ args: [String: Any]) -> ArtworkNavigation {
            let horizontal = args["horizontal"] as? Bool ?? false
            let labels = args["labels"] as? [String] ?? []
            return ArtworkNavigation(labels: horizontal ? labels : Array(labels.prefix(5)), selectionState: selection, horizontal: horizontal,
                                     phoneTabs: args["phoneTabs"] as? Bool ?? false,
                                     prominent: args["prominent"] as? Bool ?? false,
                                     segmentWidths: (args["widths"] as? [NSNumber])?.map { CGFloat($0.doubleValue) },
                                     tint: navigationTint(args).map { Color(uiColor: $0) }) {
                channel.invokeMethod("select", arguments: $0)
            }
        }
        host = UIHostingController(rootView: content(args))
        super.init()
        if #available(iOS 26, *), args["phoneTabs"] as? Bool == true {
            host.safeAreaRegions = []
        }
        host.view.frame = frame
        host.view.backgroundColor = .clear
        channel.setMethodCallHandler { [weak self] call, result in
            if call.method == "page", let page = call.arguments as? NSNumber {
                let value = CGFloat(page.doubleValue)
                if value == value.rounded() {
                    selection.index = Int(value)
                    selection.page = nil
                } else {
                    selection.page = value
                }
                result(nil)
                return
            }
            guard call.method == "update", let args = call.arguments as? [String: Any] else {
                result(FlutterMethodNotImplemented)
                return
            }
            if let host = self?.host {
                let updated = content(args)
                let current = host.rootView
                if current.labels != updated.labels || current.horizontal != updated.horizontal ||
                    current.phoneTabs != updated.phoneTabs ||
                    current.prominent != updated.prominent || current.segmentWidths != updated.segmentWidths ||
                    current.tint != updated.tint {
                    host.rootView = updated
                }
                if let index = args["index"] as? Int, selection.index != index {
                    selection.index = index
                }
            }
            result(nil)
        }
    }
    deinit { channel.setMethodCallHandler(nil) }
    func view() -> UIView { host.view }
}

private final class RankDatePickerController: UIViewController, UIAdaptivePresentationControllerDelegate {
    private let picker = UIDatePicker()
    private let calendar: Calendar
    private var result: FlutterResult?

    init?(arguments: [String: Any], result: @escaping FlutterResult) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        func date(_ key: String) -> Date? {
            guard let parts = arguments[key] as? [Int], parts.count == 3 else { return nil }
            return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        }
        guard let minimum = date("minimum"), let maximum = date("maximum"),
              let initial = date("initial"), minimum <= maximum else { return nil }
        self.calendar = calendar
        self.result = result
        super.init(nibName: nil, bundle: nil)

        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        picker.calendar = calendar
        if let locale = arguments["locale"] as? String { picker.locale = Locale(identifier: locale) }
        picker.minimumDate = minimum
        picker.maximumDate = maximum
        picker.date = min(maximum, max(minimum, initial))
        navigationItem.title = arguments["title"] as? String
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: arguments["cancel"] as? String, style: .plain, target: self, action: #selector(cancel)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: arguments["done"] as? String, style: .done, target: self, action: #selector(confirm)
        )
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        picker.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(picker)
        let safe = view.safeAreaLayoutGuide
        let wheelHeight = picker.heightAnchor.constraint(equalToConstant: 216)
        wheelHeight.priority = .defaultHigh
        NSLayoutConstraint.activate([
            picker.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 8),
            picker.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -8),
            picker.centerYAnchor.constraint(equalTo: safe.centerYAnchor),
            picker.heightAnchor.constraint(lessThanOrEqualTo: safe.heightAnchor),
            wheelHeight,
        ])
    }

    @objc private func cancel() { finish(nil) }

    @objc private func confirm() {
        let parts = calendar.dateComponents([.year, .month, .day], from: picker.date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else {
            finish(nil)
            return
        }
        finish([year, month, day])
    }

    private func finish(_ date: [Int]?) {
        guard let completion = result else { return }
        result = nil
        dismiss(animated: true) { completion(date) }
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        result?(nil)
        result = nil
    }
}

private final class GlassSurfaceFactory: NSObject, FlutterPlatformViewFactory {
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
    func create(withFrame frame: CGRect, viewIdentifier id: Int64, arguments: Any?) -> FlutterPlatformView {
        let args = arguments as? [String: Any]
        return GlassSurfaceView(
            frame: frame,
            dark: args?["dark"] as? Bool ?? false,
            circular: args?["circular"] as? Bool ?? false,
            tint: (args?["tint"] as? NSNumber)?.uint32Value
        )
    }
}

private final class GlassSurfaceView: NSObject, FlutterPlatformView {
    private let surface: UIVisualEffectView

    init(frame: CGRect, dark: Bool, circular: Bool, tint: UInt32?) {
        let effect: UIVisualEffect
        if #available(iOS 26, *) {
            let glass = UIGlassEffect(style: .regular)
            if let tint {
                glass.tintColor = UIColor(
                    red: CGFloat((tint >> 16) & 255) / 255,
                    green: CGFloat((tint >> 8) & 255) / 255,
                    blue: CGFloat(tint & 255) / 255,
                    alpha: CGFloat(tint >> 24) / 255
                )
            } else if circular {
                glass.tintColor = UIColor.label.withAlphaComponent(0.07)
            }
            effect = glass
        } else {
            effect = UIBlurEffect(style: .systemMaterial)
        }
        surface = circular ? CircularGlassEffectView(effect: effect) : UIVisualEffectView(effect: effect)
        super.init()
        if dark { surface.overrideUserInterfaceStyle = .dark }
        surface.frame = frame
        surface.layer.cornerRadius = 22
        surface.layer.cornerCurve = .continuous
        surface.clipsToBounds = true
        surface.isUserInteractionEnabled = false
        surface.accessibilityElementsHidden = true
    }

    func view() -> UIView { surface }
}


private final class CircularGlassEffectView: UIVisualEffectView {
    override func layoutSubviews() {
        layer.cornerRadius = min(bounds.width, bounds.height) / 2
        super.layoutSubviews()
    }
}

private final class FormControlFactory: NSObject, FlutterPlatformViewFactory {
    let messenger: FlutterBinaryMessenger
    init(_ messenger: FlutterBinaryMessenger) { self.messenger = messenger }
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
    func create(withFrame frame: CGRect, viewIdentifier id: Int64, arguments: Any?) -> FlutterPlatformView {
        FormControlView(frame, id, arguments as? [String: Any] ?? [:], messenger)
    }
}

private final class SettingsActionButton: UIButton {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: 0, dy: -3).contains(point)
    }
}

private final class FormControlView: NSObject, FlutterPlatformView {
    private static let pixivBlue = UIColor(red: 0, green: 150.0 / 255, blue: 250.0 / 255, alpha: 1)
    private let container: UIView
    private let control: UIControl
    private let channel: FlutterMethodChannel

    init(_ frame: CGRect, _ id: Int64, _ args: [String: Any], _ messenger: FlutterBinaryMessenger) {
        container = UIView(frame: frame)
        channel = FlutterMethodChannel(name: "pixez/formControl/\(id)", binaryMessenger: messenger)
        switch args["kind"] as? String {
        case "switch": control = UISwitch()
        case "slider": control = UISlider()
        case "action" where args["compact"] as? Bool == true: control = SettingsActionButton(type: .system)
        default: control = UIButton(type: .system)
        }
        super.init()
        container.addSubview(control)
        control.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            control.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            control.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        if !(control is UISwitch) {
            control.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true
            control.heightAnchor.constraint(equalTo: container.heightAnchor, constant: control is SettingsActionButton ? -6 : 0).isActive = true
        }
        if args["kind"] as? String == "action" {
            control.addTarget(self, action: #selector(activate), for: .primaryActionTriggered)
        }
        control.addTarget(self, action: #selector(changed), for: .valueChanged)
        control.addTarget(self, action: #selector(ended), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        update(args)
        channel.setMethodCallHandler { [weak self] call, result in
            guard call.method == "update", let args = call.arguments as? [String: Any] else {
                result(FlutterMethodNotImplemented)
                return
            }
            self?.update(args)
            result(nil)
        }
    }
    func view() -> UIView { container }

    private func update(_ args: [String: Any]) {
        control.isEnabled = args["enabled"] as? Bool ?? true
        control.accessibilityLabel = args["label"] as? String
        if let dark = args["dark"] as? Bool { container.overrideUserInterfaceStyle = dark ? .dark : .light }
        if let toggle = control as? UISwitch {
            toggle.onTintColor = Self.pixivBlue
            toggle.setOn(args["value"] as? Bool ?? false, animated: toggle.window != nil)
        } else if let slider = control as? UISlider {
            slider.tintColor = Self.pixivBlue
            slider.minimumTrackTintColor = Self.pixivBlue
            slider.minimumValue = (args["min"] as? NSNumber)?.floatValue ?? 0
            slider.maximumValue = (args["max"] as? NSNumber)?.floatValue ?? 1
            if !slider.isTracking { slider.value = (args["value"] as? NSNumber)?.floatValue ?? 0 }
            if args["clearTrack"] as? Bool == true {
                slider.minimumTrackTintColor = .clear
                slider.maximumTrackTintColor = .clear
            }
        } else if let button = control as? UIButton {
            if args["kind"] as? String == "action" {
                let prominent = args["prominent"] as? Bool == true
                var config: UIButton.Configuration
                if #available(iOS 26, *) {
                    config = prominent ? .prominentGlass() : .glass()
                } else {
                    config = prominent ? .filled() : .tinted()
                }
                config.cornerStyle = .capsule
                if prominent { config.baseBackgroundColor = Self.pixivBlue }
                config.title = args["label"] as? String
                if args["compact"] as? Bool == true {
                    config.buttonSize = .medium
                    config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
                    var title = AttributedString(config.title ?? "")
                    title.font = .systemFont(ofSize: CGFloat((args["fontSize"] as? NSNumber)?.doubleValue ?? 16), weight: .medium)
                    config.attributedTitle = title
                }
                if let symbol = args["symbol"] as? String {
                    config.image = UIImage(systemName: symbol)
                    if args["iconOnly"] as? Bool == true {
                        config.title = nil
                        config.contentInsets = .zero
                        config.baseForegroundColor = .label
                    } else {
                        config.imagePadding = 6
                    }
                }
                button.configuration = config
                return
            }
            let labels = args["labels"] as? [String] ?? []
            let selected = args["index"] as? Int ?? -1
            let symbol = args["symbol"] as? String
            var config = UIButton.Configuration.plain()
            if args["glass"] as? Bool == true {
                if #available(iOS 26, *) { config = .glass() } else { config = .tinted() }
                config.cornerStyle = .capsule
                config.contentInsets = .zero
            }
            config.image = UIImage(systemName: symbol ?? "chevron.up.chevron.down")
            config.baseForegroundColor = args["active"] as? Bool == true ? .systemBlue : (symbol == nil ? .secondaryLabel : .label)
            if symbol == nil, labels.indices.contains(selected) {
                var title = AttributedString(labels[selected])
                title.font = .systemFont(ofSize: CGFloat((args["fontSize"] as? NSNumber)?.doubleValue ?? 17))
                config.attributedTitle = title
                config.titleLineBreakMode = .byTruncatingTail
                config.imagePlacement = .trailing
                config.imagePadding = 3
                config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 10)
                config.contentInsets = .init(top: 2, leading: 6, bottom: 2, trailing: 6)
            }
            button.configuration = config
            button.titleLabel?.numberOfLines = 1
            button.showsMenuAsPrimaryAction = true
            if #available(iOS 16, *) {
                button.preferredMenuElementOrder = args["fixedOrder"] as? Bool == true ? .fixed : .automatic
            }
            button.menu = UIMenu(children: labels.enumerated().map { index, label in
                UIAction(title: label, state: index == selected ? .on : .off) { [weak self] _ in
                    self?.channel.invokeMethod("change", arguments: index)
                }
            })
        }
    }
    @objc private func activate() { channel.invokeMethod("change", arguments: nil) }
    @objc private func changed() {
        if let toggle = control as? UISwitch { channel.invokeMethod("change", arguments: toggle.isOn) }
        if let slider = control as? UISlider { channel.invokeMethod("change", arguments: Double(slider.value)) }
    }
    @objc private func ended() {
        if let slider = control as? UISlider { channel.invokeMethod("end", arguments: Double(slider.value)) }
    }
}

// Use the system tab bar on iOS versions without Liquid Glass.
private final class PhoneTabsView: NSObject, FlutterPlatformView, UITabBarDelegate {
    private let bar: UITabBar
    private let channel: FlutterMethodChannel
    private var labels: [String] = []
    private let symbols = ["house", "chart.bar", "heart", "magnifyingglass", "ellipsis"]

    init(_ frame: CGRect, _ id: Int64, _ args: [String: Any], _ messenger: FlutterBinaryMessenger) {
        bar = UITabBar(frame: frame)
        channel = FlutterMethodChannel(name: "pixez/glassRail/\(id)", binaryMessenger: messenger)
        super.init()
        bar.itemPositioning = .fill
        bar.delegate = self
        update(args)
        channel.setMethodCallHandler { [weak self] call, result in
            if call.method == "page", let value = call.arguments as? NSNumber {
                self?.updatePageSelection(CGFloat(value.doubleValue))
            } else if call.method == "update", let args = call.arguments as? [String: Any] {
                self?.update(args)
            } else {
                result(FlutterMethodNotImplemented)
                return
            }
            result(nil)
        }
    }

    private func update(_ args: [String: Any]) {
        bar.tintColor = navigationTint(args)
        let titles = Array((args["labels"] as? [String] ?? []).prefix(symbols.count))
        if titles != labels {
            labels = titles
            bar.items = titles.enumerated().map { index, title in
                let symbol = symbols[index]
                let image = UIImage(systemName: symbol)
                let item = UITabBarItem(title: title, image: image, selectedImage: UIImage(systemName: symbol + ".fill") ?? image)
                item.tag = index
                return item
            }
        }
        if let index = args["index"] as? Int { updatePageSelection(CGFloat(index)) }
    }

    private func updatePageSelection(_ position: CGFloat) {
        guard !labels.isEmpty else { return }
        let value = min(max(0, position), CGFloat(labels.count - 1))
        let item = bar.items?[Int(value.rounded())]
        if bar.selectedItem !== item { bar.selectedItem = item }
    }

    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        channel.invokeMethod("select", arguments: item.tag)
    }

    deinit { channel.setMethodCallHandler(nil) }
    func view() -> UIView { bar }
}

private final class FadingBackdropFactory: NSObject, FlutterPlatformViewFactory {
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
    func create(withFrame frame: CGRect, viewIdentifier id: Int64, arguments: Any?) -> FlutterPlatformView {
        let args = arguments as? [String: Any]
        return FadingBackdrop(frame: frame, direction: args?["direction"] as? String ?? "down",
                              dark: args?["dark"] as? Bool ?? false)
    }
}

private final class BackdropMask: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
}

private final class FadingBackdrop: UIVisualEffectView, FlutterPlatformView {
    private let fade = BackdropMask()
    private var maskedSize = CGSize.zero

    init(frame: CGRect, direction: String, dark: Bool) {
        super.init(effect: UIBlurEffect(style: direction == "down" ? .systemMaterial : .systemUltraThinMaterial))
        self.frame = frame
        overrideUserInterfaceStyle = dark ? .dark : .light
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        let gradient = fade.layer as! CAGradientLayer
        switch direction {
        case "left": gradient.startPoint = CGPoint(x: 1, y: 0.5); gradient.endPoint = CGPoint(x: 0, y: 0.5)
        case "right": gradient.startPoint = CGPoint(x: 0, y: 0.5); gradient.endPoint = CGPoint(x: 1, y: 0.5)
        default: gradient.startPoint = CGPoint(x: 0.5, y: 0); gradient.endPoint = CGPoint(x: 0.5, y: 1)
        }
        gradient.colors = [UIColor.black.cgColor, UIColor.clear.cgColor]
        fade.isOpaque = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != maskedSize else { return }
        maskedSize = bounds.size
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fade.frame = bounds
        // UIVisualEffectView copies its mask to internal views. Reassign on resize.
        mask = fade
        CATransaction.commit()
    }
    func view() -> UIView { self }
}

private final class ThemeColorPicker: UIColorPickerViewController, UIColorPickerViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
    var complete: FlutterResult?

    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) { finish() }
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) { finish() }

    private func finish() {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        let rgb = selectedColor.cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!,
                                                  intent: .defaultIntent, options: nil)
        let callback = complete
        complete = nil
        guard let rgb, UIColor(cgColor: rgb).getRed(&r, green: &g, blue: &b, alpha: &a) else { callback?(nil); return }
        callback?(0xff000000 | Int((r * 255).rounded()) << 16 | Int((g * 255).rounded()) << 8 | Int((b * 255).rounded()))
    }
}
