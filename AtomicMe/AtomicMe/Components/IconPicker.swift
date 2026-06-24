//
//  IconPicker.swift
//  AtomicMe
//

import SwiftUI

/// Grid of curated SF Symbols. Color is no longer a user choice here —
/// habit color is owned by the category — so this picker only selects
/// an icon and previews it tinted with the category color.
struct IconPicker: View {
    @Binding var selectedIcon: String
    var tint: Color = .accentColor

    private let iconColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                preview
                iconSection
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
    }

    private var preview: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(tint.opacity(0.18))
                Image(systemName: selectedIcon.isEmpty ? "questionmark" : selectedIcon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 2) {
                Text("Preview")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(selectedIcon)
                    .font(.subheadline.monospaced())
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(IconLibrary.groups) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: iconColumns, spacing: 10) {
                        ForEach(group.icons, id: \.self) { icon in
                            iconTile(icon)
                        }
                    }
                }
            }
        }
    }

    private func iconTile(_ icon: String) -> some View {
        let isSelected = icon == selectedIcon
        return Button {
            selectedIcon = icon
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : tint)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? tint : Color(.secondarySystemBackground))
                )
        }
        .buttonStyle(.plain)
    }
}

/// Sheet wrapper used when an inline picker would clutter the form.
struct IconPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIcon: String
    var tint: Color = .accentColor

    var body: some View {
        NavigationStack {
            IconPicker(selectedIcon: $selectedIcon, tint: tint)
                .navigationTitle("Pick an Icon")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .fontWeight(.semibold)
                    }
                }
        }
    }
}

#Preview {
    PickerPreview()
}

private struct PickerPreview: View {
    @State private var icon = "figure.run"
    var body: some View {
        IconPicker(selectedIcon: $icon, tint: .orange)
    }
}
