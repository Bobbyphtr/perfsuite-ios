//
//  FramesMeterTests.swift
//  PerformanceSuite
//
//  Created by Gleb Tarasov on 07/07/2021.
//

import XCTest

@testable import PerformanceSuite

//swiftlint:disable force_unwrapping

class FramesMeterTests: XCTestCase, FramesMeterReceiver {
    func frameTicked(frameDuration: CFTimeInterval, refreshRateDuration: CFTimeInterval) {
        lastDuration = frameDuration
        lastRefreshRateDuration = refreshRateDuration

        expectation?.fulfill()
        expectation = nil
    }

    private var lastDuration: CFTimeInterval?
    private var lastRefreshRateDuration: CFTimeInterval?
    private var expectation: XCTestExpectation?

    func testTicks() throws {
        let framesMeter = DefaultFramesMeter()
        framesMeter.subscribe(receiver: self)

        func oneTick() {
            self.expectation = self.expectation(description: "wait for the next frame")
            waitForExpectations(timeout: 1, handler: nil)

            if self.lastDuration == nil {
                XCTFail("Check if your simulator is launched during this test run")
                return
            }

            XCTAssertGreaterThan(self.lastDuration!, 0.015)
            XCTAssertLessThan(self.lastDuration!, 0.5)

            XCTAssertGreaterThan(self.lastRefreshRateDuration!, 0.015)
            XCTAssertLessThan(self.lastRefreshRateDuration!, 0.017)
        }


        oneTick()
        oneTick()
        oneTick()
    }

    func testNoTicksInBackground() {
        let appStateObserver = AppStateObserverStub()
        appStateObserver.isInBackground = true

        let framesMeter = DefaultFramesMeter(appStateObserver: appStateObserver)
        framesMeter.subscribe(receiver: self)

        self.expectation = self.expectation(description: "no frame should be reported, we are in background")
        self.expectation?.isInverted = true

        waitForExpectations(timeout: 0.2, handler: nil)
        XCTAssertNil(lastDuration)

        appStateObserver.isInBackground = false
        PerformanceSuite.queue.async {
            appStateObserver.didChange()
        }

        self.expectation = self.expectation(description: "frame should be reported, we are active")

        waitForExpectations(timeout: 0.2, handler: nil)
        XCTAssertNotNil(lastDuration)
        XCTAssertGreaterThan(lastDuration!, 0.015)
        XCTAssertLessThan(lastDuration!, 0.5)
        lastDuration = nil

        appStateObserver.isInBackground = true
        PerformanceSuite.queue.async {
            appStateObserver.didChange()
        }

        self.expectation = self.expectation(description: "no frame should be reported, we are in background again")
        self.expectation?.isInverted = true

        waitForExpectations(timeout: 0.2, handler: nil)
        XCTAssertNil(lastDuration)
    }
}

class AppStateObserverStub: AppStateObserver {
    var wasInBackground: Bool = false
    var isInBackground: Bool = false
    var didChange: () -> Void = {}
}
