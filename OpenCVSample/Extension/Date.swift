//
//  DateExtension.swift
//  OpenCVSample
//
//  Created by 八箇　恭平 on 2018/09/21.
//  Copyright © 2018年 Kyohei Hakka. All rights reserved.
//

import Foundation
extension DateFormatter {
    // テンプレートの定義(例)
    enum Template: String {
        case date = "yMd"     // 2017/1/1
        case time = "Hms"     // 12:39:22
        case full = "yMdkHms" // 2017/1/1 12:39:22
        case onlyHour = "k"   // 17時
        case era = "GG"       // "西暦" (default) or "平成" (本体設定で和暦を指定している場合)
        case weekDay = "EEEE" // 日曜日
    }
    // 冗長な関数のためラップ
    func setTemplate(_ template: Template) {
        // optionsは拡張のためにあるが使用されていない引数
        // localeは省略できないがほとんどの場合currentを指定する
        dateFormat = DateFormatter.dateFormat(fromTemplate: template.rawValue, options: 0, locale: .current)
    }
}

extension Date{
    func getText(template: DateFormatter.Template) -> String{
        let f = DateFormatter()
        f.setTemplate(template)
        let now = Date()
        return f.string(from: now)
    }
    
    func isSameDay(date: Date) -> Bool{
        let calendar = Calendar.current
        return calendar.isDate(self, inSameDayAs: date)
    }
}
