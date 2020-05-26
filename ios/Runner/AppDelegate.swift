import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    private var result: FlutterResult?
    private var flutterViewController: FlutterViewController {
        return self.window.rootViewController as! FlutterViewController
        
    }

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let channel = FlutterMethodChannel(name: "com.razokulover.livephotoDemo/livephoto", binaryMessenger: flutterViewController as! FlutterBinaryMessenger)
        channel.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            if call.method == "generate" {
                let args = call.arguments as! [String: Any]
                guard let photoURL = args["photoURL"] as? String else {
                    result(FlutterError.init(code: "ArgumentError", message: "Required argument not exist", details: nil))
                    return
                }
                guard let videoURL = args["videoURL"] as? String else {
                    result(FlutterError.init(code: "ArgumentError", message: "Required argument not exist", details: nil))
                    return
                }
                print("generate method executing \(photoURL) \(videoURL)")
                if #available(iOS 9.1, *) {
                    // Download media
                    self.downloadFile(forKey: "png", urlString: photoURL, type: "png")
                    self.downloadFile(forKey: "mov", urlString: videoURL, type: "mov")

                    let pngPath = self.filePath(forKey: "png")!
                    let movPath = self.filePath(forKey: "mov")!
                    LivePhoto.generate(from: pngPath, videoURL: movPath, progress: { percent in }, completion: { livePhoto, resources in
                        print("Generation results: \(String(describing: resources))")
                        if let resources = resources {
                            print("Success to generate Live Photo")
                            LivePhoto.saveToLibrary(resources, completion: {(success) in
                                if success {
                                    print("Successed to save Photos")
                                } else {
                                    print("Failed to save Photos")
                                }
                            })
                        }
                    })
                } else {
                    // Fallback on earlier versions
                }
            }
        })

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func downloadFile(forKey key: String, urlString: String, type: String) {
        guard let url = URL(string: urlString) else {
            return
        }

        do {
            print("Downloading...")
            let data = try Data(contentsOf: url)
            print("Finished downloading.")
            let filePath = self.filePath(forKey: key)
            if type == "png" {
                if let pngImage = UIImage(data: data) {
                    if let pngRep = pngImage.pngData() {
                        if let filePath = filePath {
                            do {
                                try pngRep.write(to: filePath, options: .atomic)
                            } catch let err {
                                print("Failed to download png: \(err)")
                            }
                        } else {
                            print("filePath nil")
                        }
                    } else {
                        print("pngRep nil")
                    }
                } else {
                    print("pngImage nil")
                }
            } else if type == "mov" {
                if let filePath = filePath {
                    do {
                        try data.write(to: filePath, options: .atomic)
                    } catch let err {
                        print("Failed to download png: \(err)")
                    }
                }
            } else {
                print("Failed to download because of errors occurring in Data")
            }
        } catch let err {
            print("Error: \(err)")
        }
    }
    
    private func filePath(forKey key: String) -> URL? {
        let fileManager = FileManager.default
        guard let documentURL = fileManager.urls(for: .documentDirectory,
                                                in: FileManager.SearchPathDomainMask.userDomainMask).first else { return nil }
        return documentURL.appendingPathComponent(key + "." + key)
    }
}
