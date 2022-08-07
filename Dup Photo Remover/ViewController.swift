//
//  ViewController.swift
//  Dup Photo Remover
//
//  Created by Ru Jia on 2022/8/4.
//

import UIKit
import Photos
import PhotosUI
import CommonCrypto

class ViewController: UIViewController {
    
    @IBOutlet weak var infoLabel: UILabel!
    
    var fetchResult: PHFetchResult<PHAsset>!
    var uniqueSet: Set<Data> = Set()
    var duplicatedItems: Array<PHAsset> = Array()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        checkPhotoAuthorization()
    }
    
    @IBAction func didPressButtonStart(_ sender: Any) {
        fetchAllPhotos()
    }
    

    func checkPhotoAuthorization() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite, handler: { authorizationLevel in
            DispatchQueue.main.async {
                self.infoLabel.text = String(describing: authorizationLevel)
            }
        })
    }
    
    func fetchAllPhotos() {
        PHPhotoLibrary.requestAuthorization { (status) in
            switch status {
            case .authorized:
                print("Good to proceed")
                let allPhotosOptions = PHFetchOptions()
                // 通过创建时间升序查找所有项目，顺序遍历时后遇到的MD5存在重复的可以加入到删除数组
                allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
                self.fetchResult = PHAsset.fetchAssets(with: .image, options: allPhotosOptions)
                DispatchQueue.main.async {
                    self.infoLabel.text = "Good to proceed with \(self.fetchResult.count) items"
                }
                self.findDuplicatedAssets()
            case .denied, .restricted:
                print("Not allowed")
                DispatchQueue.main.async {
                    self.infoLabel.text = "Not allowed"
                }
            case .notDetermined:
                print("Not determined yet")
                DispatchQueue.main.async {
                    self.infoLabel.text = "Not determined yet"
                }
            case .limited:
                DispatchQueue.main.async {
                    print("Authorization limited")
                }
                self.infoLabel.text = "Authorization limited"
            @unknown default:
                print("Unknown status")
            }
        }
    }
    
    func findDuplicatedAssets() {
        fetchResult.enumerateObjects { asset, index, stop in
            autoreleasepool(invoking: {
                print("photo: \(asset.localIdentifier)")
                let options = PHContentEditingInputRequestOptions()
                
                //获取保存的图片路径
                asset.requestContentEditingInput(with: options, completionHandler: {
                    (contentEditingInput:PHContentEditingInput?, info: [AnyHashable : Any]) in
                    let urlOfItem = contentEditingInput!.fullSizeImageURL!
                    let md5OfItem = self.md5File(url: urlOfItem)
                    print("地址：",urlOfItem)
                    print("MD5: \(String(describing: md5OfItem))")
                    if let md5 = md5OfItem {
                        if self.uniqueSet.contains(md5) {
                            self.duplicatedItems.append(asset)
                        } else {
                            self.uniqueSet.insert(md5)
                        }
                    }
                })
            })
        }
        
        // 删除找到的重复项目
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(self.duplicatedItems as NSArray)
        })
    }

}


// MARK: - MD5
extension ViewController {
    func md5File(url: URL) -> Data? {

        let bufferSize = 1024 * 1024

        do {
            // Open file for reading:
            let file = try FileHandle(forReadingFrom: url)
            defer {
                file.closeFile()
            }

            // Create and initialize MD5 context:
            var context = CC_MD5_CTX()
            CC_MD5_Init(&context)

            // Read up to `bufferSize` bytes, until EOF is reached, and update MD5 context:
            while autoreleasepool(invoking: {
                let data = file.readData(ofLength: bufferSize)
                if data.count > 0 {
                    data.withUnsafeBytes {
                        _ = CC_MD5_Update(&context, $0.baseAddress, numericCast(data.count))
                    }
                    return true // Continue
                } else {
                    return false // End of file
                }
            }) { }

            // Compute the MD5 digest:
            var digest: [UInt8] = Array(repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            _ = CC_MD5_Final(&digest, &context)

            return Data(digest)

        } catch {
            print("Cannot open file:", error.localizedDescription)
            return nil
        }
    }
}


