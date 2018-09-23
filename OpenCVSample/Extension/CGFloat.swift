//
//  CGFloat.swift
//  OpenCVSample
//
//  Created by 八箇　恭平 on 2018/09/23.
//  Copyright © 2018年 Kyohei Hakka. All rights reserved.
//

import Foundation
extension CGFloat{
    static func getDiff(x1: CGFloat, x2: CGFloat, y1: CGFloat, y2: CGFloat) -> CGFloat{
        let xd = x1 - x2
        let yd = y1 - y2
        let diff = sqrt(xd * xd + yd * yd)
        return diff
    }
}
