//
//  WXWeatherText.swift
//  SkyShowCase
//
//  Created by 植村詩苑 on 2025/12/23.
//

import Foundation

enum WXWeatherText {
    static func shortLabel(for code: Int) -> String {
        WXWeatherCode.shortLabel(for: code)
    }
}
