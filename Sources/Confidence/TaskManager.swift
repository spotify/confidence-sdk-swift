import Foundation

internal class TaskManager {
    public var currentTask: Task<(), Never>? {
        didSet {
            if let oldTask = oldValue {
                oldTask.cancel()
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
