//
//  URLSessionHTTPClientTests.swift
//  EssentialFeedTests
//
//  Created by Haider Rizvi on 04/02/2024.
//

import Foundation
import XCTest
import EssentialFeed

class  URLSessionHTTPClientTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        
        URLProtocolStub.startInterceptingRequests()
    }
    
    override class func tearDown() {
        super.tearDown()
        
        URLProtocolStub.stopInterceptingRequests()
    }
    
    func test_getFromURL_performGetRequestWithURL() {
        let url = anyURL()
        
        var receivedRequests = [URLRequest]()
        URLProtocolStub.observeRequests{ request in
            receivedRequests.append(request)
        }
        
        let exp = expectation(description: "Wait for request completion")
        
        makeSUT().get(from: url){ _ in exp.fulfill()}
        
        wait(for: [exp], timeout: 1.0)
        
        XCTAssertEqual(receivedRequests.count, 1)
        XCTAssertEqual(receivedRequests.first?.url, url)
        XCTAssertEqual(receivedRequests.first?.httpMethod, "GET")
    }
    
    func test_getFromURL_failsOnRequestError() {
        
        let requestError  = anyNSError()
       let receivedError =  resultErrorFor(data: nil, response: nil, error: requestError)
        
        XCTAssertNotNil(receivedError)
    }
    
    func test_getFromURL_failsOnAllInvalidRepresentationCases() {
        XCTAssertNotNil(resultErrorFor(data:nil, response:nil, error:nil))
        XCTAssertNotNil(resultErrorFor(data:nil, response:nonHTTPURLResponse(), error:nil))
        XCTAssertNotNil(resultErrorFor(data:anyData(), response:nil, error:nil))
        XCTAssertNotNil(resultErrorFor(data:anyData(), response:nil, error:anyNSError()))
        XCTAssertNotNil(resultErrorFor(data:nil, response:nonHTTPURLResponse(), error:anyNSError()))
        XCTAssertNotNil(resultErrorFor(data:nil, response:anyHTTPURLResponse(), error:anyNSError()))
        XCTAssertNotNil(resultErrorFor(data:anyData(), response:nonHTTPURLResponse(), error:anyNSError()))
        XCTAssertNotNil(resultErrorFor(data:anyData(), response:anyHTTPURLResponse(), error:anyNSError()))
        XCTAssertNotNil(resultErrorFor(data:anyData(), response:nonHTTPURLResponse(), error:nil))
        
    }
    
    func test_getFromURL_suceedsOnHTTPURLResposeWithData()  {
        let data = anyData()
        let response = anyHTTPURLResponse()
        
        let receivedValues = resultValuesFor(data: data, response: response, error: nil)
        
        XCTAssertEqual(receivedValues?.data, data)
        XCTAssertEqual(receivedValues?.response.url, response.url)
        XCTAssertEqual(receivedValues?.response.statusCode, response.statusCode)
    }

    func test_getFromURL_suceedsWithEmptyDataOnHTTPURLResposeWithNilData()  {
        let response = anyHTTPURLResponse()
        
        let receivedValues = resultValuesFor(data: nil, response: response, error: nil)
        
        let emptyData = Data()
        XCTAssertEqual(receivedValues?.data, emptyData)
        XCTAssertEqual(receivedValues?.response.url, response.url)
        XCTAssertEqual(receivedValues?.response.statusCode, response.statusCode)
    }
    // Mark: - Helpers
    
    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> HTTPClient  {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        
        let sut = URLSessionHTTPClient(session: session)
        
        trackForMemoryLeaks(sut,file: file, line: line)
        return sut
    }
    
    private func resultErrorFor(data: Data?, response:URLResponse?, error: Error?,file: StaticString = #filePath, line: UInt = #line) -> Error? {
        let result = resultFor(data: data, response: response, error: error, file: file, line: line)
        
        switch result {
        case let .failure(error):
            return error
        default:
            XCTFail("Expected failure got \(result) instead", file:file, line: line)
            return nil
        }
    }
    
    private func resultValuesFor(data: Data?, response:URLResponse?, error: Error?,file: StaticString = #filePath, line: UInt = #line) -> (data: Data, response: HTTPURLResponse)? {
        let result = resultFor(data: data, response: response, error: error, file: file, line: line)
        
        switch result {
        case let .success(data, response):
            return (data, response)
        default:
            XCTFail("Expected success got \(result) instead", file:file, line: line)
            return nil
        }
    }
    
    private func resultFor(data: Data?, response:URLResponse?, error: Error?, file: StaticString = #filePath, line: UInt = #line) -> HTTPClientResult {
        let url = anyURL()
        URLProtocolStub.stub(data: data, response: response, error: error)
        
        let sut = makeSUT(file:file, line: line)
        let exp = expectation(description: "Wait for completion")
        var receivedResult: HTTPClientResult!
        
        sut.get(from: url) {result in
            receivedResult = result
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
        
        return receivedResult
    }
    
    private func anyData() -> Data  {
        return Data(bytes: "any data".utf8)
    }
    
    private  func nonHTTPURLResponse() -> URLResponse {
        return URLResponse(url: anyURL(), mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
    }
    
    
    private func anyHTTPURLResponse() -> HTTPURLResponse {
        return HTTPURLResponse(url: anyURL(), statusCode: 200, httpVersion: nil, headerFields: nil)!
    }
    
    private class URLProtocolStub: URLProtocol {
        
        private static var stub : Stub?
        private static var  requestObserver : ((URLRequest) -> Void)?
        
        private struct Stub {
            let data:  Data?
            let response: URLResponse?
            let error : Error?
        }
        
        static func stub(data: Data?, response: URLResponse?, error: Error? =  nil){
            stub = Stub(data:data, response: response, error: error)
        }
        
        static func observeRequests(observer:@escaping (URLRequest) -> Void){
            requestObserver = observer
        }
        
        static func startInterceptingRequests(){
            URLProtocolStub.registerClass(URLProtocolStub.self)
        }
        
        static func stopInterceptingRequests(){
            URLProtocolStub.unregisterClass(URLProtocolStub.self)
            stub = nil
            requestObserver = nil
        }
        
        override class func canInit(with request: URLRequest) -> Bool {
           return true
        }
        
        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            return request
        }
        
        override func startLoading() {
            if let requestObserver = URLProtocolStub.requestObserver {
                client?.urlProtocolDidFinishLoading(self)
                return requestObserver(request)
            }
            
            if let data = URLProtocolStub.stub?.data {
                client?.urlProtocol(self, didLoad: data)
            }
            
            if let response = URLProtocolStub.stub?.response  {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            
            if let error  = URLProtocolStub.stub?.error {
                client?.urlProtocol(self, didFailWithError: error)
            }
            
            client?.urlProtocolDidFinishLoading(self)
        }
        
        override func stopLoading() {}
        
        
    }
    
}
