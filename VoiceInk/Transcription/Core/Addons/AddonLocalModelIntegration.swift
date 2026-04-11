import Foundation
import SwiftUI
import Combine

@MainActor
protocol AddonLocalModelIntegration: AnyObject {
    var models: [any AddonLocalModel] { get }
    var recommendedModelNames: [String] { get }
    var objectWillChangePublisher: AnyPublisher<Void, Never> { get }

    var onModelDeleted: ((String) -> Void)? { get set }
    var onModelsChanged: (() -> Void)? { get set }

    func createModelsDirectoryIfNeeded()
    func refreshAvailableModels()
    func handles(_ model: any TranscriptionModel) -> Bool
    func isModelDownloaded(_ model: any AddonLocalModel) -> Bool
    func progressMap(for model: any AddonLocalModel) -> [String: Double]
    func service(for model: any AddonLocalModel) -> TranscriptionService
    func downloadModel(_ model: any AddonLocalModel) async
    func deleteModel(_ model: any AddonLocalModel) async
    func prepareModel(_ model: any AddonLocalModel) async throws
    func unloadModelResources()
    func cleanupResources() async
    func showModelInFinder(_ model: any AddonLocalModel)
    func cardView(
        for model: any AddonLocalModel,
        isDownloaded: Bool,
        isCurrent: Bool,
        deleteAction: @escaping () -> Void,
        setDefaultAction: @escaping () -> Void,
        downloadAction: @escaping () -> Void
    ) -> AnyView
}
