//
//  ViewController.swift


import UIKit
import AVFoundation
import AssetsLibrary

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    @IBOutlet weak var backView: UIView!
    @IBOutlet weak var cameraImageView: UIImageView!
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var WinkLabel: UILabel!
    
    var openCV = OpenCV()
    
    var session: AVCaptureSession! //セッション
    var device: AVCaptureDevice! //カメラ
    var output: AVCaptureVideoDataOutput! //出力先
    
    var assetWriter: AVAssetWriter!
    var videoAssetsInput: AVAssetWriterInput! //動画保存用
    var pixelBuffer: AVAssetWriterInputPixelBufferAdaptor! //動画保存用のピクセルバッファ
    var frameNumber: Int64 = 0 //動画保存フレーム
    var startTime: CMTime!
    var endTime: CMTime!
    var imageSize : CGSize? = nil
    
    var recordingMode = false //録画開始モード
    
    var wink: Wink = Wink.close
    var winkStartTime: Double = 0.0 //Winkがスタートした時間
    var winkEndTime: Double = 0.0 //Winkがエンドした時間
    
    var eyeStatusArray = [Wink]() //過去のWink回数
    let EyeStatusStackCount = 6 //過去何回のデータを用いるか
    
    override func viewDidLoad() {
        super.viewDidLoad()
        super.viewDidLoad()
        
        // *************** XMLのセット ***************
        openCV.setFaceXML(CascadeName.face.rawValue) //顔
        openCV.setEyeXML(CascadeName.eye.rawValue) //眼
        
        // *************** カメラ準備 ***************
        if initCamera() {
            session.startRunning()
        }else{
            assert(false) //カメラが使えない
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.backView.frame = self.view.frame
    }

    
    // カメラの準備処理
    func initCamera() -> Bool {
        let preset = AVCaptureSession.Preset.medium //解像度
        //解像度
        //        AVCaptureSession.Preset.Photo : 852x640
        //        AVCaptureSession.Preset.High : 1280x720
        //        AVCaptureSession.Preset.Medium : 480x360
        //        AVCaptureSession.Preset.Low : 192x144
 
        
        let frame = CMTimeMake(value: 1, timescale: 30) //フレームレート
        let position = AVCaptureDevice.Position.front //フロントカメラかバックカメラか
        
        setImageViewLayout(preset: preset)//UIImageViewの大きさを調整
        
        // セッションの作成.
        session = AVCaptureSession()
        
        // 解像度の指定.
        session.sessionPreset = preset
        
        // デバイス取得.
        device = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera,
                                           for: AVMediaType.video,
                                           position: position)
        
        // VideoInputを取得.
        var input: AVCaptureDeviceInput! = nil
        do {
            input = try
                AVCaptureDeviceInput(device: device) as AVCaptureDeviceInput
        } catch let error {
            print(error)
            return false
        }
        
        // セッションに追加.
        if session.canAddInput(input) {
            session.addInput(input)
        } else {
            return false
        }
        
        // 出力先を設定
        output = AVCaptureVideoDataOutput()
        
        //ピクセルフォーマットを設定
        output.videoSettings =
            [ kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String : Int(kCVPixelFormatType_32BGRA) ]
        
        //サブスレッド用のシリアルキューを用意
        output.setSampleBufferDelegate(self, queue: DispatchQueue.main)
        
        // 遅れてきたフレームは無視する
        output.alwaysDiscardsLateVideoFrames = true
        
        // FPSを設定
        do {
            try device.lockForConfiguration()
            
            device.activeVideoMinFrameDuration = frame //フレームレート
            device.unlockForConfiguration()
        } catch {
            return false
        }
        
        // セッションに追加.
        if session.canAddOutput(output) {
            session.addOutput(output)
        } else {
            return false
        }
        
        // カメラの向きを合わせる
        for connection in output.connections {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = AVCaptureVideoOrientation.portrait
            }
        }
        
        return true
    }
    
    // 1フレーム終了後に実行
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if !CMSampleBufferDataIsReady(sampleBuffer){ return }
        DispatchQueue.main.async{ //非同期処理として実行
            if self.frameNumber == 0{
                self.startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            }
            let img = self.captureImage(sampleBuffer) //UIImageへ変換
            var resultImg: UIImage //結果を格納する

            // *************** 画像処理 ***************
                //①グレー変換
//            resultImg = self.openCV.toGrayImg(img) //変換
            
                //②肌色検出
//            let arr = NSMutableArray()
//            self.openCV.getSkinArea(img, img: arr)
//            resultImg = self.drawRectangle(image: img, rect: arr)
            
                // ③眼の検出
            let detectedFace = NSMutableArray() //検出された顔
            let detectedEye = NSMutableArray() //検出された眼
            self.openCV.faceDetect(img, detectedFace) //顔を検出
            
            if detectedFace.count > 0{
                //顔の領域を切り取り
                let center: (x: CGFloat, y: CGFloat) = (x: img.size.width / 2, y: img.size.height / 2) //画像の中央
                var centerId = -1 //中央に近いid
                var minDiff = CGFloat.getDiff(x1: 0, x2: img.size.width, y1: 0, y2: img.size.height) //最も小さい差分
                //得られた顔の中から最も中央に近いものを選択する
                for i in 0 ..< (detectedFace.count / 4){
                    let x:Int = detectedFace[i * 4 + 0] as! NSNumber as! Int
                    let y:Int = detectedFace[i * 4 + 1] as! NSNumber as! Int
                    //                let width:Int = detectedFace[i * 4 + 2] as! NSNumber as! Int
                    //                let height:Int = detectedFace[i * 4 + 3] as! NSNumber as! Int
                    let diff = CGFloat.getDiff(x1: center.x, x2: CGFloat(x), y1: center.y, y2: CGFloat(y))
                    if diff < minDiff{
                        minDiff = diff
                        centerId = i
                    }
                }

                //顔の部分結果
                let fx = CGFloat(detectedFace[centerId * 4 + 0] as! NSNumber as! Int)
                let fy = CGFloat(detectedFace[centerId * 4 + 1] as! NSNumber as! Int)
                let fw = CGFloat(detectedFace[centerId * 4 + 2] as! NSNumber as! Int)
                let fh = CGFloat(detectedFace[centerId * 4 + 3] as! NSNumber as! Int)
                let faceImg = img.cropping(to: CGRect(x: fx, y: fy, width: fw, height: fh/2))!
//                self.faceImageView.image = faceImg
//                self.faceImageView.frame.size = CGSize(width: fw, height: fh)
                
                //眼を抽出
                self.openCV.eyeDetect(faceImg, detectedEye)
                var detects = [Int]() //検出された矩形
                for i in 0..<detectedEye.count / 4{
                    let ix:Int = (detectedEye[i * 4 + 0] as! NSNumber as! Int)
                    let iy:Int = (detectedEye[i * 4 + 1] as! NSNumber as! Int)
                    let iw:Int = detectedEye[i * 4 + 2] as! NSNumber as! Int
                    let ih:Int = detectedEye[i * 4 + 3] as! NSNumber as! Int
                    var collision = false
                    for j in detects{
                        let jx:Int = (detectedEye[j * 4 + 0] as! NSNumber as! Int)
                        let jy:Int = (detectedEye[j * 4 + 1] as! NSNumber as! Int)
                        if (ix + iw/2) > jx && (ix + iw/2) < jx &&//x座標が中
                            (iy + ih/2) > jy && (iy + ih/2) < jy{ //y座標が中
                            collision = true
                        }
                    }
                    if !collision{detects.append(i)}
                }
                
                switch detects.count{
                case 0:
                    if self.eyeStatusArray.count < self.EyeStatusStackCount{
                        self.eyeStatusArray.append(.close)
                    }else{
                        self.eyeStatusArray.remove(at: 0)
                        self.eyeStatusArray.append(.close)
                    }
                case 1:
                    if CGFloat(detectedEye[detects[0] * 4 + 0] as! NSNumber as! Int + Int(fx)) < center.x{
                        //右側の眼
                        if self.eyeStatusArray.count < self.EyeStatusStackCount{
                            self.eyeStatusArray.append(.right)
                        }else{
                            self.eyeStatusArray.remove(at: 0)
                            self.eyeStatusArray.append(.right)
                        }
                    }else{
                        //左側の眼
                        if self.eyeStatusArray.count < self.EyeStatusStackCount{
                            self.eyeStatusArray.append(.left)
                        }else{
                            self.eyeStatusArray.remove(at: 0)
                            self.eyeStatusArray.append(.left)
                        }
//                        if !self.wink.isWink(){self.winkStartTime = self.getCurrentTime()}
                    }
                case 2:
                    if self.eyeStatusArray.count < self.EyeStatusStackCount{
                        self.eyeStatusArray.append(.doubleEye)
                    }else{
                        self.eyeStatusArray.remove(at: 0)
                        self.eyeStatusArray.append(.doubleEye)
                    }
                default: break
//                    D("Error \(detects.count)")
                }
                
                //winkの種類を数える
                var kindsArray: [Wink:Int] = [.right:0, .left:0, .doubleEye:0, .close:0] //各回数
                if self.eyeStatusArray.count == self.EyeStatusStackCount{
                    for kind in self.eyeStatusArray{
                        let num = kindsArray[kind]!
                        kindsArray[kind] = num + 1
                    }
                    //winkの種類を判別
                    var max = 0
                    for k in [Wink.right, Wink.left, Wink.doubleEye, Wink.close]{
                        if max < kindsArray[k]!{
                            max = kindsArray[k]!
                            self.wink = k
                        }
                    }
                }else{
                    self.wink = Wink.doubleEye
                }
                
                self.winkActivation()
                
                // winkの時間を計測
                if self.winkStartTime == -1 && self.wink.isWink(){
                    self.winkStartTime = self.getCurrentTime()
                }else if self.winkStartTime != -1 && self.wink == Wink.doubleEye{
                    self.winkEndTime = self.getCurrentTime()
                    D(self.winkEndTime - self.winkStartTime)
                    self.winkStartTime = -1
                }
                
                //眼に矩形を表示
                resultImg = img
                UIGraphicsBeginImageContext(resultImg.size)
                resultImg.draw(in: CGRect.init(x: 0, y: 0, width: img.size.width, height: img.size.height))
                let context = UIGraphicsGetCurrentContext()
                context?.setStrokeColor(UIColor.red.cgColor) //線の色
                context?.setLineWidth(5.0) //線の太さ
                for i in 0 ..< (detectedEye.count / 4){
                    let x:Int = (detectedEye[i * 4 + 0] as! NSNumber as! Int  + Int(fx))
                    let y:Int = (detectedEye[i * 4 + 1] as! NSNumber as! Int + Int(fy))
                    let width:Int = detectedEye[i * 4 + 2] as! NSNumber as! Int
                    let height:Int = detectedEye[i * 4 + 3] as! NSNumber as! Int
                    context?.addRect(CGRect(x: x, y: y, width: width, height: height))
                }
                context?.strokePath()
                resultImg = UIGraphicsGetImageFromCurrentImageContext()!
                UIGraphicsEndImageContext()
                
            }else{
                resultImg = img
            }
            // *****************************************
            
            // 動画保存
            if self.recordingMode{ self.recordMovie(img: resultImg, sampleBuffer) }
            
            // 表示
            self.cameraImageView.image = resultImg
        }
    }
    
    // 矩形書き出し
    func drawRectangle(image: UIImage, rect: NSMutableArray) -> UIImage{
        var resultImg: UIImage = image

        UIGraphicsBeginImageContext(resultImg.size)
        resultImg.draw(in: CGRect.init(x: 0, y: 0, width: resultImg.size.width, height: image.size.height))
        let context = UIGraphicsGetCurrentContext()
        context?.setStrokeColor(UIColor.red.cgColor) //線の色
        context?.setLineWidth(5.0) //線の太さ
        for i in 0 ..< (rect.count / 4){
            let x:Int = rect[i * 4 + 0] as! NSNumber as! Int
            let y:Int = rect[i * 4 + 1] as! NSNumber as! Int
            let width:Int = rect[i * 4 + 2] as! NSNumber as! Int
            let height:Int = rect[i * 4 + 3] as! NSNumber as! Int
            context?.addRect(CGRect(x: x, y: y, width: width, height: height))
        }
        context?.strokePath()
        resultImg = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return resultImg
    }
    
    // sampleBufferからUIImageを作成
    func captureImage(_ sampleBuffer:CMSampleBuffer) -> UIImage{
        let imageBuffer: CVImageBuffer! = CMSampleBufferGetImageBuffer(sampleBuffer)
        
        // ベースアドレスをロック
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        // 画像データの情報を取得
        let baseAddress: UnsafeMutableRawPointer = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0)!
        
        let bytesPerRow: Int = CVPixelBufferGetBytesPerRow(imageBuffer)
        let width: Int = CVPixelBufferGetWidth(imageBuffer)
        let height: Int = CVPixelBufferGetHeight(imageBuffer)
        
        // RGB色空間を作成
        let colorSpace: CGColorSpace! = CGColorSpaceCreateDeviceRGB()
        
        // Bitmap graphic contextを作成
        let bitsPerCompornent: Int = 8
        let bitmapInfo = CGBitmapInfo(rawValue: (CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) as UInt32)
        let newContext: CGContext! = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: bitsPerCompornent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) as CGContext?
        
        // Quartz imageを作成
        let imageRef: CGImage! = newContext!.makeImage()
        
        // ベースアドレスをアンロック
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        // UIImageを作成
        let resultImage: UIImage = UIImage(cgImage: imageRef)
        if imageSize == nil{
            imageSize = CGSize(width: resultImage.size.width, height: resultImage.size.height)
        }
        return resultImage
    }
    
    // UIImageをCVPixelBufferに変換
    private func pixelBufferFromUIImage(image: UIImage) -> CVPixelBuffer? {
        let cgImage: CGImage = image.cgImage!
        
        let options = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        
        var pxBuffer: CVPixelBuffer? = nil
        
        let width: Int = cgImage.width
        let height: Int = cgImage.height
        
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, options as CFDictionary?, &pxBuffer)
        
        CVPixelBufferLockBaseAddress(pxBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        let pxData: UnsafeMutableRawPointer = CVPixelBufferGetBaseAddress(pxBuffer!)!
        
        let bitsPerComponent: size_t = 8
        let bytePerRow: size_t = 4 * width
        
        let rgbColorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
        let context: CGContext = CGContext(data: pxData, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytePerRow, space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        
        CVPixelBufferUnlockBaseAddress(pxBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pxBuffer!
    }
    
    //imageViewの大きさを調整
    func setImageViewLayout(preset: AVCaptureSession.Preset){
        let width = self.view.frame.width / 3
        var height:CGFloat
        switch preset {
        case .photo:
            height = width * 852 / 640
        case .high:
            height = width * 1280 / 720
        case .medium:
            height = width * 480 / 360
        case .low:
            height = width * 192 / 144
        case .cif352x288:
            height = width * 352 / 288
        case .hd1280x720:
            height = width * 1280 / 720
        default:
            height = self.view.frame.height
        }
        cameraImageView.frame = CGRect(x: 0, y: 0, width: width, height: height)
    }

    // *************** 動画保存関連 ***************
    //動画の保存
    func recordMovie(img: UIImage, _ sampleBuffer:CMSampleBuffer){
        //        キャプチャー開始時刻を記録
        if frameNumber == 0 {
            startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        }
        
        let timeStanp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let frameTime = CMTimeSubtract(timeStanp, self.startTime)
        
        
        if self.videoAssetsInput.isReadyForMoreMediaData {
            
            if let frame = img.toCVPixelBuffer(){
                self.pixelBuffer.append(frame, withPresentationTime: frameTime) //アセットに書き出し
            }
            self.frameNumber += 1
        }
        self.endTime = frameTime
    }
    
    //停止
    func stopCapture(){
        DispatchQueue.main.async {
            self.videoAssetsInput.markAsFinished()
            // endSession()を呼ばないとキャプチャーを正常終了できない
            self.assetWriter.endSession(atSourceTime: self.endTime)
            // キャプチャー（ビデオ保存）を終了
            self.assetWriter.finishWriting {
                print("finish")
                self.videoAssetsInput = nil
            }
        }
    }
    
    //
    func setupAssetWriter(){
//        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first  //パス
        let date = Date()
        let time = date.getText(template: .time) //日付時間
        let fileName : String = "\(time).mp4" //ファイル名
        let filePath = NSSearchPathForDirectoriesInDomains(
            FileManager.SearchPathDirectory.documentDirectory,
            FileManager.SearchPathDomainMask.userDomainMask, true).last! + "/" + fileName //ファイルパス
        let fileURL = URL(fileURLWithPath: filePath) //ファイルのURL
        
        var videoHeight: CGFloat = 480
        var videoWidth: CGFloat = 360
        if let size = imageSize{
            videoHeight = size.height
            videoWidth = size.width
        }
        
        // ビデオ入力設定 (h264コーデックを使用・フルHD)
        let videoSettings = [
            AVVideoWidthKey: videoWidth,
            AVVideoHeightKey: videoHeight,
            AVVideoCodecKey: AVVideoCodecType.h264
            ] as [String: Any]
        
        videoAssetsInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)

        // フレームごとの画像を処理するためのバッファーを準備
        pixelBuffer = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoAssetsInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
                kCVPixelBufferWidthKey as String: videoWidth,
                kCVPixelBufferHeightKey as String: videoHeight,
                ])
        frameNumber = 0  // フレーム番号の初期化
        
        do {
            // アセットライターの準備
            try assetWriter = AVAssetWriter(outputURL: fileURL, fileType: .mp4)
            videoAssetsInput.expectsMediaDataInRealTime = true
            // アセットライターにビデオ入力を接続
            assetWriter.add(videoAssetsInput)
            assetWriter.startWriting()
            assetWriter.startSession(atSourceTime: CMTime.zero)
        } catch {
            print("could not start video recording ", error)
        }
    }
    
    
    // *************** action ***************
    @IBAction func recordingButton(_ sender: Any) {
        if recordingMode{ stopCapture() }else{ setupAssetWriter() }
        recordingMode = !recordingMode
        let image = recordingMode ?
            ImageName.stopBtn.toUIImage() :
            ImageName.recordBtn.toUIImage()
        button.setImage(image, for: .normal)
    }
    
    // *************** 時間 ***************
    //時間をDoubleで取得する
    func getCurrentTime() -> Double{
        var tv = timeval()
        gettimeofday(&tv, nil)
        let t = Double(tv.tv_sec) + Double(tv.tv_usec) / 1000000.0
        return t
    }
    
    // *************** Winkの機能 ***************
    var didActivate = false
    func winkActivation(){
        D("#########\(self.backView.center)")
        WinkLabel.text = wink.rawValue

        if !wink.isWink(){
            didActivate = false
            if !isBackViewOriginPos() && wink == .doubleEye{
                UIView.animate(withDuration: 0.5, delay: 0.0, options: UIView.AnimationOptions.beginFromCurrentState, animations: {
                    self.backView.center.y = self.view.center.y
                }, completion: {result in D(self.backView.center)})
            }
            return
        } //winkじゃなければBack
        
        if didActivate{ return } //使用済みでもだめ
        
        if wink == Wink.left{
            if isBackViewOriginPos(){
                UIView.animate(withDuration: 0.5, delay: 0.0, options: UIView.AnimationOptions.beginFromCurrentState, animations: {
                    self.backView.center.y += self.backView.frame.size.height / 2
                }, completion: {result in D(self.backView.center)})
            }else if backView.center.y == view.center.y - self.view.frame.size.height / 2{
                UIView.animate(withDuration: 0.5, delay: 0.0, options: UIView.AnimationOptions.beginFromCurrentState, animations: {
                    self.backView.center.y += self.backView.frame.size.height / 2
                }, completion: {result in D(self.backView.center)})
            }
        }else{
            if isBackViewOriginPos(){
                UIView.animate(withDuration: 0.5, delay: 0.0, options: UIView.AnimationOptions.beginFromCurrentState, animations: {
                    self.backView.center.y += self.backView.frame.size.height / 2
                }, completion: {result in D(self.backView.center)})
            }else if backView.center.y == view.center.y - self.view.frame.size.height / 2{
                UIView.animate(withDuration: 0.5, delay: 0.0, options: UIView.AnimationOptions.beginFromCurrentState, animations: {
                    self.backView.center.y += self.backView.frame.size.height / 2
                }, completion: {result in D(self.backView.center)})
            }
        }
        didActivate = true
    }
    
    func isBackViewOriginPos() -> Bool{
        return backView.center == self.view.center
    }
}

