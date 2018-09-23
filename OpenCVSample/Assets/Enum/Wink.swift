//
//  Wink.swift
//  OpenCVSample
//
//  Created by 八箇　恭平 on 2018/09/23.
//  Copyright © 2018年 Kyohei Hakka. All rights reserved.
//

import Foundation
enum Wink: String {
    case right = "RIGHT"
    case left = "LEFT"
    case close = "CLOSE"
    case doubleEye = "DOUBLE"
    func isWink() -> Bool{
        switch self {
        case .right,.left:
            return true
        default:
            return false
        }
    }
}
