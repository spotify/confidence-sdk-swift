#if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
import Foundation
import UIKit
import Combine

public class ConfidenceDeviceInfoContextDecorator: ConfidenceContextProducer, ObservableObject {
    public var currentProducedContext: CurrentValueSubject<ConfidenceStruct, Never> = CurrentValueSubject([:])
    private let queue = DispatchQueue(label: "com.confidence.device_info_decorator")

    private init(context: ConfidenceStruct) {
        self.currentProducedContext.send(context)
    }

    public func produceContexts() -> AnyPublisher<ConfidenceStruct, Never> {
        currentProducedContext
            .filter { context in !context.isEmpty }
            .eraseToAnyPublisher()

    }

    private func withLock(callback: @escaping () -> Void) {
        queue.sync {
            callback()
        }
    }

    public static func builder() -> Builder {
        return Builder()
    }

    public class Builder {
        private var initialContext: ConfidenceStruct

        public init() {
            self.initialContext = ConfidenceStruct()
        }

        public func withVersionInfo() -> Builder {
            let currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            let currentBuild: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
            initialContext["app_version"] = .init(string: currentVersion)
            initialContext["app_build"] = .init(string: currentBuild)
            return self
        }

        public func withBundleId() -> Builder {
            let bundleId = Bundle.main.bundleIdentifier ?? ""
            initialContext["bundle_id"] = .init(string: bundleId)
            return self
        }

        public func withDeviceInfo() -> Builder {
            // Fetch device properties
            let device = UIDevice.current

            // Set the context with the desired properties
            initialContext["device_model"] = .init(string: device.model)                 // Device model (e.g., "iPhone")
            initialContext["system_name"] = .init(string: device.systemName)             // OS name (e.g., "iOS")
            initialContext["system_version"] = .init(string: device.systemVersion)       // OS version (e.g., "16.2")
            return self
        }

        public func withLocale() -> Builder {
            let locale = Locale.current
            let preferredLanguages = Locale.preferredLanguages

            initialContext["locale_identifier"] = .init(string: locale.identifier) // Locale identifier (e.g., "en_US")
            initialContext["preferred_languages"] = .init(list: preferredLanguages.map({ l in
                    .init(string: l)
            })) // Preferred languages as a comma-separated string
            return self
        }


        public func build() -> ConfidenceDeviceInfoContextDecorator {
            return ConfidenceDeviceInfoContextDecorator(context: initialContext)
        }
    }

}
#endif
