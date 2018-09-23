//
//  DebugFunc.swift
//  ExCursor2
//
//  Created by 八箇　恭平 on 2018/06/16.
//  Copyright © 2018年 Kyohei Hakka. All rights reserved.
//

import UIKit

func D(_ debug: Any = "",
       _ name: String = "",
       function: String = #function,
       file: String = #file,
       line: Int = #line) {
    
    var filename = file
    if let match = filename.range(of: "[^/]*$", options: .regularExpression) {
        filename = String(filename[match])
    }
    print("\(filename)[\(line)行]: [\(function)], \(name) : \(debug)")
}

func D(_ debug1: Any = "",
       _ debug2: Any = "",
       _ name: String = "",
       function: String = #function,
       file: String = #file,
       line: Int = #line) {
    
    var filename = file
    if let match = filename.range(of: "[^/]*$", options: .regularExpression) {
        filename = String(filename[match])
    }
    print("\(filename)[\(line)行]: [\(function)], \(name) : (\(debug1) , \(debug2))")
}

func D(_ debug1: Any = "",
       _ debug2: Any = "",
       _ debug3: Any = "",
       _ name: String = "",
       function: String = #function,
       file: String = #file,
       line: Int = #line) {
    
    var filename = file
    if let match = filename.range(of: "[^/]*$", options: .regularExpression) {
        filename = String(filename[match])
    }
    print("\(filename)[\(line)行]: [\(function)], \(name) : (\(debug1), \(debug2), \(debug3))")
}
