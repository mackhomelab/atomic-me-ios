//
//  CustomCategory.swift
//  AtomicMe
//

import Foundation
import SwiftData
import SwiftUI

/// User-created category. Persists name + color so habits sharing the
/// category always render with the same tint (the "category memory").
@Model
final class CustomCategory {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#8E8E93"
    var iconSystemName: String = "sparkles"
    var createdAt: Date = Date()

    init(name: String, colorHex: String, iconSystemName: String = "sparkles") {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.iconSystemName = iconSystemName
        self.createdAt = Date()
    }

    var color: Color {
        Color(hex: colorHex) ?? .gray
    }
}
