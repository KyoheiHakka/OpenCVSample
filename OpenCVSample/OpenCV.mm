// OpenCV.mm

#import <opencv2/opencv.hpp>
#import <opencv2/highgui.hpp>
#import <opencv2/imgcodecs/ios.h>
#import <opencv2/core.hpp>

#import "OpenCV.h" //ライブラリによってはNOマクロがバッティングするので，これは最後にimport

@implementation OpenCV
//グレースケール変換
- (UIImage *) toGrayImg:(UIImage *)img{
    
    // *************** UIImage -> cv::Mat変換 ***************
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(img.CGImage);
    CGFloat cols = img.size.width;
    CGFloat rows = img.size.height;
    
    cv::Mat mat(rows, cols, CV_8UC4);
    
    CGContextRef contextRef = CGBitmapContextCreate(mat.data,
                                                    cols,
                                                    rows,
                                                    8,
                                                    mat.step[0],
                                                    colorSpace,
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault);
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), img.CGImage);
    CGContextRelease(contextRef);
    
    // *************** 処理 ***************
    cv::Mat grayImg;
    cv::cvtColor(mat, grayImg, CV_BGR2GRAY); //グレースケール変換
    
    // *************** cv::Mat → UIImage ***************
    UIImage *resultImg = MatToUIImage(grayImg);
    return resultImg;
}

//肌色検出
- (void) getSkinArea:(UIImage *) img img: (NSMutableArray *) arr{
    
    // *************** UIImage -> cv::Mat変換 ***************
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(img.CGImage);
    CGFloat cols = img.size.width;
    CGFloat rows = img.size.height;
    
    cv::Mat mat(rows, cols, CV_8UC4);
    
    CGContextRef contextRef = CGBitmapContextCreate(mat.data,
                                                    cols,
                                                    rows,
                                                    8,
                                                    mat.step[0],
                                                    colorSpace,
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault);
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), img.CGImage);
    CGContextRelease(contextRef);
    
    // *************** HSV変換 ***************
    cv::Mat hsv;
    cv::cvtColor(mat, hsv, cv::COLOR_RGB2HSV); //HSVに変換
    cv::medianBlur(hsv, hsv, 3);// medianフィルタを用いたノイズ除去
    // *************** 肌色抽出 ***************
    cv::Scalar low = cv::Scalar(0,70,90); //下限値（H,S,V）
    cv::Scalar high = cv::Scalar(35,255,255); //上限値(H,S,V)
    cv::inRange(hsv, low, high, hsv);
    
    std::vector< std::vector<cv::Point> > contours;
    std::vector<cv::Vec4i> hierarchy;
    cv::findContours(hsv,
                     contours,
                     hierarchy,
                     cv::RETR_EXTERNAL,
                     cv::CHAIN_APPROX_SIMPLE);
    // *************** 最大面積を取得 ***************
    double maxArea = 0.0f;
    int maxIdx = 0;
    for (int i = 0; i < contours.size(); i++){
        double temp = cv::contourArea(contours[i]);
        if (maxArea < temp){
            maxArea = temp;
            maxIdx = i;
        }
    }

    // *************** 最大，最小座標を求める ***************
    if(contours.size() != 0){
        double minX = contours[maxIdx][0].x;
        double minY = contours[maxIdx][0].y;
        double maxX = contours[maxIdx][0].x;
        double maxY = contours[maxIdx][0].y;
        for(int i = 0; i < contours[maxIdx].size(); i++){
            if(minX > contours[maxIdx][i].x){ minX = contours[maxIdx][i].x; }
            if(maxX < contours[maxIdx][i].x){ maxX = contours[maxIdx][i].x; }
            if(minY > contours[maxIdx][i].y){ minY = contours[maxIdx][i].y; }
            if(maxY < contours[maxIdx][i].y){ maxY = contours[maxIdx][i].y; }
        }
        cv::Point minP = cv::Point(minX,minY);
        cv::Point maxP = cv::Point(maxX,maxY);
        
        // *************** 矩形の座標を返す ***************
        cv::Rect rect(minP,maxP);
        [arr addObject: [NSNumber numberWithInteger: rect.x]];
        [arr addObject: [NSNumber numberWithInteger: rect.y]];
        [arr addObject: [NSNumber numberWithInteger: rect.width]];
        [arr addObject: [NSNumber numberWithInteger: rect.height]];
    }
}

// *************** カスケードの処理 ***************
cv::CascadeClassifier faceCas;
cv::CascadeClassifier eyeCas;
bool active;

- (bool) isActive{ return active; }

// 顔の識別器をセット
-(bool) setFaceXML:(NSString *)name{
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *path = [bundle pathForResource: name ofType:@"xml"];
    std::string cascadeName = (char *) [path UTF8String];
    if (!faceCas.load(cascadeName)) {
        active = false;
        return active;
    }
    active = true;
    return active;
}

-(bool) setEyeXML:(NSString *)name{
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *path = [bundle pathForResource: name ofType:@"xml"];
    std::string cascadeName = (char *) [path UTF8String];
    if (!eyeCas.load(cascadeName)) {
        active = false;
        return active;
    }
    active = true;
    return active;
}

//顔の検出
- (void) faceDetect: (UIImage *) image : (NSMutableArray*) arr{
    // UIImage -> cv::Mat変換
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat mat(rows, cols, CV_8UC4);
    
    CGContextRef contextRef = CGBitmapContextCreate(mat.data,
                                                    cols,
                                                    rows,
                                                    8,
                                                    mat.step[0],
                                                    colorSpace,
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault);
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    // 検出
    std::vector<cv::Rect> targets;
    std::vector<cv::Rect> targets2;
    
    //    cascade.detectMultiScale(mat, targets);
    faceCas.detectMultiScale(mat, //画像
                             targets, //ターゲット
                             1.1, //縮小スケール
                             5, //最小矩形数（これ以上の矩形が集中した部分を検出）
                             CV_HAAR_SCALE_IMAGE, //フラグ
                             cv::Size(30, 30)); //これよりも小さい物体は無視
    
    //検出した領域の座標を格納
    for (int i = 0; i < targets.size(); i++){
        cv::Rect rect = targets[i];
        [arr addObject: [NSNumber numberWithInteger: rect.x]];
        [arr addObject: [NSNumber numberWithInteger: rect.y]];
        [arr addObject: [NSNumber numberWithInteger: rect.width]];
        [arr addObject: [NSNumber numberWithInteger: rect.height]];
    }
}

- (void) eyeDetect: (UIImage *) image: (NSMutableArray*) arr{
    // UIImage -> cv::Mat変換
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat mat(rows, cols, CV_8UC4);
    
    CGContextRef contextRef = CGBitmapContextCreate(mat.data,
                                                    cols,
                                                    rows,
                                                    8,
                                                    mat.step[0],
                                                    colorSpace,
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault);
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    // 検出
    std::vector<cv::Rect> targets;
    std::vector<cv::Rect> targets2;
    
    //    cascade.detectMultiScale(mat, targets);
    eyeCas.detectMultiScale(mat, //画像
                             targets, //ターゲット
                             1.1, //縮小スケール
                             3, //最小矩形数（これ以上の矩形が集中した部分を検出）
                             CV_HAAR_SCALE_IMAGE, //フラグ
                             cv::Size(30, 30)); //これよりも小さい物体は無視
    
    //検出した領域の座標を格納
    for (int i = 0; i < targets.size(); i++){
        cv::Rect rect = targets[i];
        [arr addObject: [NSNumber numberWithInteger: rect.x]];
        [arr addObject: [NSNumber numberWithInteger: rect.y]];
        [arr addObject: [NSNumber numberWithInteger: rect.width]];
        [arr addObject: [NSNumber numberWithInteger: rect.height]];
    }
}
@end
