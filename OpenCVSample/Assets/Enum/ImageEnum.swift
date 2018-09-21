//
//  ImageEnum.swift
//  OpenCVSample
//
//  Created by 八箇　恭平 on 2018/09/21.
//  Copyright © 2018年 Kyohei Hakka. All rights reserved.
//

import Foundation
enum ImageName: String{
    case recordBtn = "img_playButton"
    case stopBtn = "img_stopButton"
    
    func toUIImage() -> UIImage{
        return UIImage.init(named: self.rawValue)!
    }
}
