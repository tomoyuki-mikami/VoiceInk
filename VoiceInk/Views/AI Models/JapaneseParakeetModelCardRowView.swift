import SwiftUI

struct JapaneseParakeetModelCardView: View {
    let model: JapaneseParakeetLocalModel
    let isDownloaded: Bool
    let isCurrent: Bool
    let isDownloading: Bool
    let downloadProgress: Double

    var deleteAction: () -> Void
    var setDefaultAction: () -> Void
    var downloadAction: () -> Void
    var showInFinderAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(model.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(.labelColor))

                    if isCurrent {
                        Text("Default")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentColor))
                            .foregroundColor(.white)
                    } else if isDownloaded {
                        Text("Downloaded")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color(.quaternaryLabelColor)))
                            .foregroundColor(Color(.labelColor))
                    }

                    Spacer()
                }

                HStack(spacing: 12) {
                    Label(model.language, systemImage: "globe")
                    Label(model.size, systemImage: "internaldrive")
                    HStack(spacing: 3) {
                        Text("Speed")
                        progressDotsWithNumber(value: model.speed * 10)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    HStack(spacing: 3) {
                        Text("Accuracy")
                        progressDotsWithNumber(value: model.accuracy * 10)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                .font(.system(size: 11))
                .foregroundColor(Color(.secondaryLabelColor))

                Text(model.description)
                    .font(.system(size: 11))
                    .foregroundColor(Color(.secondaryLabelColor))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)

                if isDownloading {
                    ProgressView(value: downloadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                if isCurrent {
                    Text("Default Model")
                        .font(.system(size: 12))
                        .foregroundColor(Color(.secondaryLabelColor))
                } else if isDownloaded {
                    Button(action: setDefaultAction) {
                        Text("Set as Default")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button(action: downloadAction) {
                        HStack(spacing: 4) {
                            Text(isDownloading ? "Downloading..." : "Download")
                            Image(systemName: "arrow.down.circle")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.accentColor))
                    }
                    .buttonStyle(.plain)
                    .disabled(isDownloading)
                }

                if isDownloaded {
                    Menu {
                        Button(action: deleteAction) {
                            Label("Delete Model", systemImage: "trash")
                        }

                        Button(action: showInFinderAction) {
                            Label("Show in Finder", systemImage: "folder")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 14))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 20, height: 20)
                }
            }
        }
        .padding(16)
        .background(CardBackground(isSelected: isCurrent, useAccentGradientWhenSelected: isCurrent))
    }
}
