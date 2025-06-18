import Foundation

internal class TaskManager {
    private let queue = DispatchQueue(label: "com.confidence.taskmanager")
    private var _currentTask: Task<(), Never>?

    public var currentTask: Task<(), Never>? {
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
    public func awaitReconciliation() async {
        while let task = self.currentTask {
            // If current task is cancelled, return
            if task.isCancelled {
                return
            }
            // Wait for result of current task
            await task.value
            // If current task gets cancelled, check again if a new task was set
            if task.isCancelled {
                continue
            }
            // If current task finished successfully
            // and the set task has not changed, we are done waiting
            if self.currentTask == task {
                return
            }
        }
    }
}
