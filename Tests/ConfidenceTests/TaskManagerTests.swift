import Foundation
import XCTest
@testable import Confidence

class TaskManagerTests: XCTestCase {
    func testAwaitReconciliationCancelTask() async throws {
        let signalManager = SignalManager()
        let reconciliationExpectation = XCTestExpectation(description: "reconciliationExpectation")
        let cancelTaskExpectation = XCTestExpectation(description: "cancelTaskExpectation")
        let taskManager = TaskManager()

        let tenSeconds = Task<Result<Void, Error>, Never> {
            do {
                try await Task.sleep(nanoseconds: 10_000_000_000)
                await signalManager.setSignal1(true)
                return .success(())
            } catch {
                cancelTaskExpectation.fulfill()
                return .failure(error)
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

        let tenSeconds1 = Task<Result<Void, Error>, Never> {
            do {
                try await Task.sleep(nanoseconds: 10_000_000_000)
                await signalManager.setSignal1(true)
                return .success(())
            } catch {
                cancelTaskExpectation.fulfill()
                return .failure(error)
            }
        }
        taskManager.currentTask = tenSeconds1
        // Ensures the currentTask is set and has started
        try await Task.sleep(nanoseconds: 100_000_000)

        let tenSeconds2 = Task<Result<Void, Error>, Never> {
            await signalManager.setSignal2(true)
            secondTaskExpectation.fulfill()
            return .success(())
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
                    let task = Task<Result<Void, Error>, Never> {
                        await Task.yield()
                        return .success(())
                    }
                    taskManager.currentTask = task
                }
            }
        }
        await taskManager.awaitReconciliation()
        // If we reach here without a crash, the test passes
        XCTAssertTrue(true)
    }

    func testStartCancelsPreviousTask() async {
        let taskManager = TaskManager()
        let firstCancelled = XCTestExpectation(description: "first cancelled")
        let first = taskManager.start {
            do {
                try await Task.sleep(nanoseconds: 10_000_000_000)
                return .success(())
            } catch {
                firstCancelled.fulfill()
                return .failure(error)
            }
        }
        XCTAssertTrue(taskManager.isCurrent(first))

        let second = taskManager.start {
            .success(())
        }
        XCTAssertFalse(taskManager.isCurrent(first))
        XCTAssertTrue(taskManager.isCurrent(second))
        _ = await second.value
        await fulfillment(of: [firstCancelled], timeout: 1)
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
