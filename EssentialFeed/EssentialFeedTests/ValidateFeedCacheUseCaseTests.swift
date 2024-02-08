//
//  ValidateFeedCacheUseCaseTests.swift
//  EssentialFeedTests
//
//  Created by Haider Rizvi on 08/02/2024.
//

import Foundation
import XCTest
import EssentialFeed

class ValidateFeedCacheUseCaseTests: XCTestCase {
    
    func test_init_doesNotMessageStoreUponCreation() {
        let (_, store) = makeSUT()
        XCTAssertEqual(store.receivedMessages, [])
    }
    
    func test_validateCache_deletesCacheOnRetrievalError() {
        let (sut,store) = makeSUT()
        
        sut.validateCache()
        
        store.completeRetrieval(with: anyNSError())
        
        XCTAssertEqual(store.receivedMessages, [.retrieve, .deleteCacheFeed])
    }
    
    func test_validateCache_doesNotDeletesCacheOnEmptyCache() {
        let (sut,store) = makeSUT()
        
        sut.validateCache()
        
        store.completeRetrievalWithEmptyCache()
        
        XCTAssertEqual(store.receivedMessages, [.retrieve])
    }
    
    
    func test_validateCache_doesNotDeletesCacheOnLessThanSevenDaysOldCache() {
        let feed = uniqueImageFeed()
        let fixedCurrentDate = Date()
        let lessThanSevenDaysOldTimestamp = fixedCurrentDate.adding(days: -7).adding(seconds: 1)
        let (sut,store) = makeSUT(currentDate: {fixedCurrentDate})

        sut.validateCache()

        store.completeRetrieval(with: feed.local, timestamp: lessThanSevenDaysOldTimestamp)

        XCTAssertEqual(store.receivedMessages, [.retrieve])
    }
    
    // Mark: - Helper
    
    private func makeSUT(currentDate: @escaping () -> Date =  Date.init, file: StaticString = #filePath, line: UInt = #line) -> (sut: LocalFeedLoader, store:FeedStoreSpy) {
        let store = FeedStoreSpy()
        let sut = LocalFeedLoader(store: store, currentDate: currentDate)
        trackForMemoryLeaks(store, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, store)
    }
    
    private func uniqueImage() -> FeedImage {
            return FeedImage(id: UUID(), description: "any", location: "ay", url: anyURL())
        }

        private func uniqueImageFeed() -> (models: [FeedImage], local: [LocalFeedImage]){
            let models  = [uniqueImage(), uniqueImage()];
            let local = models.map{LocalFeedImage(id: $0.id, description: $0.description, location: $0.location, url: $0.url)}
            return (models, local)
        }
    
    private func anyNSError() -> NSError {
        return NSError(domain: "any error", code: 0)
    }
    
    private func anyURL() -> URL {
            return URL(string: "http://any-url.com")!
        }

    }

    private extension Date {

        func adding(days: Int) -> Date {
            return Calendar(identifier: .gregorian).date(byAdding: .day, value:days, to: self)!
        }

        func adding(seconds: TimeInterval) -> Date {
            return self + seconds
        }

    }
