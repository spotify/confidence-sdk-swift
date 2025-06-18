import Foundation
import XCTest
@testable import Confidence

class TaskManagerTests: XCTestCase {
    func testAwaitReconciliationCancelTask() async throws {
        let signalManager = SignalManager()
        let reconciliationExpectation = XCTestExpectation(description: "reconciliationExpectation")
        let cancelTaskExpectation = XCTestExpectation(description: "cancelTaskExpectation")
        let taskManager = TaskManager()

        let tenSeconds = Task {
            do {
                try await Task.sleep(nanoseconds: 10_000_000_000)
                await signalManager.setSignal1(true)
            } catch {
                cancelTaskExpectation.fulfill()
            }
        }
        taskManager.currentTask = tenSeconds
        // Ensures the currentTask is set and has started
        try await Task.sleep(nanoseconds: 100_000_000)

        Task {
            await taskManager.awaitReconciliation()
            reconciliationExpectation.fulfill()
        }
        tenSeconds.cancel()
        await fulfillment(of: [cancelTaskExpectation, reconciliationExpectation], timeout: 1)

        let finalSignal1 = await signalManager.getSignal1()

        XCTAssertEqual(finalSignal1, false)
    }

    func testOverrideTask() async throws {
        let signalManager = SignalManager()
        let cancelTaskExpectation = XCTestExpectation(description: "cancelTaskExpectation")
        let secondTaskExpectation = XCTestExpectation(description: "secondTaskExpectation")
        let taskManager = TaskManager()

        let tenSeconds1 = Task {
            do {
                try await Task.sleep(nanoseconds: 10_000_000_000)
                await signalManager.setSignal1(true)
            } catch {
                cancelTaskExpectation.fulfill()
            }
        }
        taskManager.currentTask = tenSeconds1
        // Ensures the currentTask is set and has started
        try await Task.sleep(nanoseconds: 100_000_000)

        let tenSeconds2 = Task {
            await signalManager.setSignal2(true)
            secondTaskExpectation.fulfill()
        }
        taskManager.currentTask = tenSeconds2
        // Ensures the currentTask is set and has started
        try await Task.sleep(nanoseconds: 100_000_000)
        await taskManager.awaitReconciliation()
        await fulfillment(of: [cancelTaskExpectation, secondTaskExpectation], timeout: 1)

        let finalSignal1 = await signalManager.getSignal1()
        let finalSignal2 = await signalManager.getSignal2()

        XCTAssertEqual(finalSignal1, false)
        XCTAssertEqual(finalSignal2, true)
    }

    func testConcurrentSetCurrentTask() async {
        let taskManager = TaskManager()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10000 {
                group.addTask {
                    let task = Task { await Task.yield() }
                    taskManager.currentTask = task
                }
            }
        }
        await taskManager.awaitReconciliation()
        // If we reach here without a crash, the test passes
        XCTAssertTrue(true)
    }

    private actor SignalManager {
        private var _signal1 = false
        private var _signal2 = false

        // Functions to access and mutate `signal1` and `signal2`
        func setSignal1(_ value: Bool) {
            _signal1 = value
        }

        func setSignal2(_ value: Bool) {
            _signal2 = value
        }

        func getSignal1() -> Bool {
            return _signal1
        }

        func getSignal2() -> Bool {
            return _signal2
        }
    }
}
