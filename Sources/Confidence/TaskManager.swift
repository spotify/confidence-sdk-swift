import Foundation

internal class TaskManager {
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

    /// Cancels any in-flight task, optionally applies state, then starts `operation` as the current generation.
    @discardableResult
    func start(
        applying: (() -> Void)? = nil,
        operation: @escaping () async -> Result<Void, Error>
    ) -> Task<Result<Void, Error>, Never> {
        queue.sync {
            if let oldTask = _currentTask {
                oldTask.cancel()
            }
            applying?()
            let task = Task<Result<Void, Error>, Never> {
                await operation()
            }
            _currentTask = task
            return task
        }
    }

    func isCurrent(_ task: Task<Result<Void, Error>, Never>) -> Bool {
        queue.sync { _currentTask == task }
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
