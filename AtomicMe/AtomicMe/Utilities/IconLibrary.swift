//
//  IconLibrary.swift
//  AtomicMe
//

import Foundation

/// Curated SF Symbol library and color palette used by the icon picker.
enum IconLibrary {
    struct IconGroup: Identifiable, Hashable {
        let id: String
        let name: String
        let icons: [String]
    }

    static let groups: [IconGroup] = [
        IconGroup(id: "activity", name: "Activity", icons: [
            "figure.run", "figure.walk", "figure.flexibility", "figure.strengthtraining.traditional",
            "dumbbell.fill", "bicycle", "figure.pool.swim", "figure.yoga",
            "figure.mind.and.body", "figure.boxing", "figure.dance", "figure.hiking",
            "figure.outdoor.cycle", "figure.jumprope", "figure.cooldown", "sportscourt.fill",
        ]),
        IconGroup(id: "mind", name: "Mind", icons: [
            "brain.head.profile", "book.fill", "book.closed.fill", "books.vertical.fill",
            "heart.text.square.fill", "sparkles", "moon.stars.fill", "wind",
            "lightbulb.fill", "graduationcap.fill", "pencil.and.scribble", "character.book.closed.fill",
            "quote.bubble.fill", "ear.fill",
        ]),
        IconGroup(id: "health", name: "Health", icons: [
            "heart.fill", "drop.fill", "bed.double.fill", "pills.fill",
            "cross.case.fill", "stethoscope", "lungs.fill", "mouth.fill",
            "thermometer.medium", "waveform.path.ecg", "bandage.fill", "eyes.inverse",
        ]),
        IconGroup(id: "food", name: "Food", icons: [
            "fork.knife", "leaf.fill", "carrot.fill", "fish.fill",
            "cup.and.saucer.fill", "wineglass.fill", "takeoutbag.and.cup.and.straw.fill", "frying.pan.fill",
            "birthday.cake.fill", "popcorn.fill",
        ]),
        IconGroup(id: "work", name: "Work", icons: [
            "checkmark.circle.fill", "calendar", "timer", "tray.fill",
            "briefcase.fill", "laptopcomputer", "doc.text.fill", "list.bullet.clipboard.fill",
            "envelope.fill", "phone.fill", "chart.bar.fill", "dollarsign.circle.fill",
        ]),
        IconGroup(id: "lifestyle", name: "Lifestyle", icons: [
            "house.fill", "sun.max.fill", "moon.fill", "music.note",
            "headphones", "gamecontroller.fill", "tv.fill", "camera.fill",
            "globe", "airplane", "car.fill", "leaf.arrow.circlepath",
            "tree.fill", "pawprint.fill",
        ]),
        IconGroup(id: "misc", name: "Misc", icons: [
            "star.fill", "flame.fill", "bolt.fill", "gift.fill",
            "trophy.fill", "medal.fill", "flag.fill", "tag.fill",
            "crown.fill", "diamond.fill", "hands.sparkles.fill", "hand.thumbsup.fill",
        ]),
    ]

    /// Display palette used everywhere a habit color is picked.
    static let palette: [String] = [
        "#FF453A", // red
        "#FF9F0A", // orange
        "#FFD60A", // yellow
        "#34C759", // green
        "#30D158", // mint
        "#0A84FF", // blue
        "#64D2FF", // cyan
        "#5E5CE6", // indigo
        "#BF5AF2", // purple
        "#FF375F", // pink
        "#FF6482", // rose
        "#AC8E68", // brown
        "#8E8E93", // gray
    ]
}
