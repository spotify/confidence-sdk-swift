import Foundation

internal class TaskManager: @unchecked Sendable {
    // `@unchecked Sendable`: `_currentTask` is only ever accessed through `queue`,
    // making the class safe to share across concurrency domains by design.
    private let queue = DispatchQueue(label: "com.confidence.taskmanager")
    private var _currentTask: Task<Result<Void, Error>, Never>?

    public var currentTask: Task<Result<Void, Error>, Never>? {
        get { queue.sync { _currentTask } }
        set {
            queue.sync {
                if let oldTask = _currentTask {
                    oldTask.cancel()
                }
                _currentTask = newValue
            }
        }
    }

    @discardableResult
    public func awaitReconciliation() async -> Result<Void, Error> {
        while let task = self.currentTask {
            // If current task is cancelled, return
            if task.isCancelled {
                return .failure(CancellationError())
            }
            // Wait for result of current task
            let result = await task.value
            // If current task gets cancelled, check again if a new task was set
            if task.isCancelled {
                continue
            }
            // If current task finished successfully
            // and the set task has not changed, we are done waiting
            if self.currentTask == task {
                return result
            }
        }
        return .success(())
    }
}
