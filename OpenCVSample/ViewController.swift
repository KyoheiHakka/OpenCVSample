//
//  ViewController.swift


import UIKit
import AVFoundation
import AssetsLibrary

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    @IBOutlet weak var cameraImageView: UIImageView!
    @IBOutlet weak var button: UIButton!
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        super.viewDidLoad()
        
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

    
    // カメラの準備処理
    func initCamera() -> Bool {
        let preset = AVCaptureSession.Preset.medium //解像度
        //解像度
        //        AVCaptureSession.Preset.Photo : 852x640
        //        AVCaptureSession.Preset.High : 1280x720
        //        AVCaptureSession.Preset.Medium : 480x360
        //        AVCaptureSession.Preset.Low : 192x144
 
        
        let frame = CMTimeMake(1, 20) //フレームレート
        let position = AVCaptureDevice.Position.back //フロントカメラかバックカメラか
        
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
//            resultImg = self.openCV.toGrayImg(img) //変換
            let arr = NSMutableArray()
            self.openCV.getSkinArea(img, img: arr)
            resultImg = self.drawRectangle(image: img, rect: arr)
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
        let width = self.view.frame.width
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
            assetWriter.startSession(atSourceTime: kCMTimeZero)
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
}

