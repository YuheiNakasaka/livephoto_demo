import UIKit
import Flutter
import AVFoundation

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
                self.runLivePhotoConvertion(rawURL: "https://img.gifmagazine.net/gifmagazine/images/1545437/original.mp4")
            }
        })

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // LivePhoto変換の登場人物
    let SRC_KEY = "mp4"
    let STILL_KEY = "png"
    let MOV_KEY = "mov"
    
    // LivePhoto変換エントリポイント
    private func runLivePhotoConvertion(rawURL: String) {
        if let videoURL = URL(string: rawURL) {
            self.downloadAsync(
                url: videoURL,
                to: self.filePath(forKey: SRC_KEY),
                completion: self.convertMp4ToMov
            )
        }
    }
    
    // MP4をMovに変換する
    private func convertMp4ToMov(mp4Path: URL) {
        // srcのビデオをmovに変換する
        let avAsset = AVURLAsset(url: mp4Path)
        let preset = AVAssetExportPresetPassthrough
        let outFileType = AVFileType.mov
        if let exportSession = AVAssetExportSession(asset: avAsset, presetName: preset), let outputURL = self.filePath(forKey: MOV_KEY) {
            
            AVAssetExportSession.determineCompatibility(ofExportPreset: preset, with: avAsset, outputFileType: outFileType, completionHandler: { (isCompatible) in
                if !isCompatible {
                    return
            }})
            
            exportSession.outputFileType = outFileType
            exportSession.outputURL = outputURL
            self.deleteFile(url: outputURL)
            
            exportSession.exportAsynchronously { () -> Void in
                switch exportSession.status {
                case AVAssetExportSessionStatus.completed:
                    print("AVAssetExportSessionStatus completed")
                    self.generateThumbnail(movURL: outputURL)
                    print("generateThumbnail completed")
                    self.generateLivePhoto()
                    break
                case AVAssetExportSessionStatus.failed:
                    print("AVAssetExportSessionStatus failed. \(String(describing: exportSession.error))")
                    break
                case AVAssetExportSessionStatus.cancelled:
                    print("AVAssetExportSessionStatus cancelled")
                    break
                default:
                    break
                }
            }
        }
    }
    
    // LivePhotoの生成
    private func generateLivePhoto() {
        let pngPath = self.filePath(forKey: STILL_KEY)!
        let movPath = self.filePath(forKey: MOV_KEY)!
        if #available(iOS 9.1, *) {
            print("Start to generate LivePhoto")
            LivePhoto.generate(from: pngPath, videoURL: movPath, progress: { percent in }, completion: { livePhoto, resources in
                print("Generation done")
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
        }
    }
    
    // ビデオからサムネイルpngを生成する
    private func generateThumbnail(movURL: URL?) {
        guard let movURL = movURL else { return }
        let asset = AVURLAsset(url: movURL, options: nil)
        let imgGenerator = AVAssetImageGenerator(asset: asset)
        let filePath = self.filePath(forKey: STILL_KEY)
        if let cgImage = try? imgGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil) {
            let pngImage = UIImage(cgImage: cgImage)
            if let pngRep = pngImage.pngData() {
                if let filePath = filePath {
                    do {
                        self.deleteFile(url: filePath)
                        try pngRep.write(to: filePath, options: .atomic)
                    } catch let err {
                        print("Failed to generate png: \(err)")
                    }
                } else {
                    print("filePath nil")
                }
            } else {
                print("pngRep nil")
            }
        }
    }
    
    // 非同期ダウンロード
    private func downloadAsync(url: URL, to localUrl: URL?, completion: @escaping (_: URL) -> ()) {
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig)
        let request = URLRequest(url: url)
        let task = session.downloadTask(with: request) {(tempLocalUrl, response, error) in
            if let tempLocalUrl = tempLocalUrl, let localUrl = localUrl, error == nil {
                do {
                    self.deleteFile(url: localUrl)
                    try FileManager.default.copyItem(at: tempLocalUrl, to: localUrl)
                    completion(localUrl)
                } catch let err {
                    print(err)
                }
            } else {
                print("Downloading Locally error")
            }
        }
        task.resume()
    }
    
    private func filePath(forKey key: String) -> URL? {
        let fileManager = FileManager.default
        guard let documentURL = fileManager.urls(for: .documentDirectory,
                                                in: FileManager.SearchPathDomainMask.userDomainMask).first else { return nil }
        return documentURL.appendingPathComponent(key + "." + key)
    }
    
    private func deleteFile(url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            print("Delete existing file")
            do {
                try FileManager.default.removeItem(atPath: url.path)
            } catch {
                print("Failed to delete file")
            }
        }
    }
}
