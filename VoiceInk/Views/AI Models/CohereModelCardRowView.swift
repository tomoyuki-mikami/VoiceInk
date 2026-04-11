import SwiftUI
import AppKit

struct CohereModelCardView: View {
    let model: CohereLocalModel
    let isDownloaded: Bool
    let isCurrent: Bool
    let isPreparing: Bool

    var deleteAction: () -> Void
    var setDefaultAction: () -> Void
    var downloadAction: () -> Void

    private var unsupportedOnThisMac: Bool {
        SystemArchitecture.isIntelMac
    }

    private var languageSummary: String {
        "\(model.supportedLanguages.count) languages"
    }

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
                    Label(languageSummary, systemImage: "globe")
                        .font(.system(size: 11))
                        .foregroundColor(Color(.secondaryLabelColor))
                    Label(model.size, systemImage: "internaldrive")
                        .font(.system(size: 11))
                        .foregroundColor(Color(.secondaryLabelColor))
                    Text(model.ramRequirement)
                        .font(.system(size: 11))
                        .foregroundColor(Color(.secondaryLabelColor))
                }

                Text(model.description)
                    .font(.system(size: 11))
                    .foregroundColor(Color(.secondaryLabelColor))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)

                Text("Auto-detect is not available. Choose the transcription language before recording.")
                    .font(.system(size: 11))
                    .foregroundColor(Color(.secondaryLabelColor))
                    .padding(.top, 2)

                if unsupportedOnThisMac {
                    Text("Cohere Transcribe は Apple Silicon 専用です")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.orange)
                        .padding(.top, 4)
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
                    .disabled(unsupportedOnThisMac)
                } else {
                    Button(action: downloadAction) {
                        HStack(spacing: 4) {
                            if isPreparing {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(isPreparing ? "Preparing..." : "Download")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color(.controlAccentColor)))
                    }
                    .buttonStyle(.plain)
                    .disabled(isPreparing || unsupportedOnThisMac)
                }

                if isDownloaded {
                    Menu {
                        Button(action: deleteAction) {
                            Label("Delete Model", systemImage: "trash")
                        }

                        Button {
                            NSWorkspace.shared.selectFile(model.storageDirectory.path, inFileViewerRootedAtPath: "")
                        } label: {
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
