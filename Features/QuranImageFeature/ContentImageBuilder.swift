//
//  ContentImageBuilder.swift
//  Quran
//
//  Created by Afifi, Mohamed on 9/16/19.
//  Copyright © 2019 Quran.com. All rights reserved.
//

import AppDependencies
import Caching
import Foundation
import ImageService
import NoorUI
import QuranGeometry
import QuranKit
import QuranPagesFeature
import ReadingService
import UIKit
import Utilities
import VLogging

@MainActor
public struct ContentImageBuilder: PageDataSourceBuilder {
    // MARK: Lifecycle

    public init(container: AppDependencies) {
        self.container = container
    }

    // MARK: Public

    public func build(actions: PageDataSourceActions, pages: [Page]) -> PageDataSource {
        let reading = ReadingPreferences.shared.reading
        let readingDirectory = readingDirectory(reading)

        let imageService = ImageDataService(
            ayahInfoDatabase: reading.ayahInfoDatabase(in: readingDirectory),
            imagesURL: reading.images(in: readingDirectory),
            cropInsets: reading.cropInsets
        )

        let cacheableImageService = createCahceableImageService(imageService: imageService, pages: pages)
        let cacheablePageMarkers = createPageMarkersService(imageService: imageService, reading: reading, pages: pages)
        return PageDataSource(actions: actions) { page in
            let controller = ContentImageViewController(
                page: page,
                dataService: cacheableImageService,
                pageMarkerService: cacheablePageMarkers
            )
            return controller
        }
    }

    // MARK: Private

    private let container: AppDependencies

    private func readingDirectory(_ reading: Reading) -> URL {
        let remoteResource = container.remoteResources?.resource(for: reading)
        let remotePath = remoteResource?.downloadDestination.url
        let bundlePath = { Bundle.main.url(forResource: reading.localPath, withExtension: nil) }
        logger.info("Images: Use \(remoteResource != nil ? "remote" : "bundle") For reading \(reading)")
        return remotePath ?? bundlePath()!
    }

    private func createCahceableImageService(imageService: ImageDataService, pages: [Page]) -> PagesCacheableService<Page, ImagePage> {
        let cache = Cache<Page, ImagePage>()
        cache.countLimit = 5

        let operation = { @Sendable (page: Page) in
            try await imageService.imageForPage(page)
        }
        let dataService = PagesCacheableService(
            cache: cache,
            previousPagesCount: 1,
            nextPagesCount: 2,
            pages: pages,
            operation: operation
        )
        return dataService
    }

    private func createPageMarkersService(
        imageService: ImageDataService,
        reading: Reading,
        pages: [Page]
    ) -> PagesCacheableService<Page, PageMarkers>? {
        // Only hafs 1421 supports page markers
        guard reading == .hafs_1421 else {
            return nil
        }

        let cache = Cache<Page, PageMarkers>()
        cache.countLimit = 5

        let operation = { @Sendable (page: Page) in
            try await imageService.pageMarkers(page)
        }
        let dataService = PagesCacheableService(
            cache: cache,
            previousPagesCount: 1,
            nextPagesCount: 2,
            pages: pages,
            operation: operation
        )
        return dataService
    }
}

private extension Reading {
    func ayahInfoDatabase(in directory: URL) -> URL {
        switch self {
        case .hafs_1405:
            return directory.appendingPathComponent("images_1920/databases/ayahinfo_1920.db")
        case .hafs_1421:
            return directory.appendingPathComponent("images_1120/databases/ayahinfo_1120.db")
        case .hafs_1440:
            return directory.appendingPathComponent("images_1352/databases/ayahinfo_1352.db")
        case .tajweed:
            return directory.appendingPathComponent("images_1280/databases/ayahinfo_1280.db")
        }
    }

    func images(in directory: URL) -> URL {
        switch self {
        case .hafs_1405:
            return directory.appendingPathComponent("images_1920/width_1920")
        case .hafs_1421:
            return directory.appendingPathComponent("images_1120/width_1120")
        case .hafs_1440:
            return directory.appendingPathComponent("images_1352/width_1352")
        case .tajweed:
            return directory.appendingPathComponent("images_1280/width_1280")
        }
    }

    var cropInsets: UIEdgeInsets {
        switch self {
        case .hafs_1405:
            return UIEdgeInsets(top: 10, left: 34, bottom: 40, right: 24)
        case .hafs_1421:
            return .zero
        case .hafs_1440:
            return .zero
        case .tajweed:
            return .zero
        }
    }
}
