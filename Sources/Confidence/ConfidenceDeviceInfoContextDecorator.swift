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

        public func withAppInfo() -> Builder {
            let currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            let currentBuild: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
            let bundleId = Bundle.main.bundleIdentifier ?? ""

            initialContext["app"] = .init(structure: [
                "version": .init(string: currentVersion),
                "build": .init(string: currentBuild),
                "namespace": .init(string: bundleId)
            ])
            return self
        }

        public func withDeviceInfo() -> Builder {
            let device = UIDevice.current

            initialContext["device"] = .init(structure: [
                "manufacturer": .init(string: "Apple"),
                "model": .init(string: getDeviceModelIdentifier()),
                "type": .init(string: device.model)
            ])
            return self
        }

        public func withOsInfo() -> Builder {
            let device = UIDevice.current

            initialContext["os"] = .init(structure: [
                "name": .init(string: device.systemName),
                "version": .init(string: device.systemVersion)
            ])
            return self
        }

        public func withLocale() -> Builder {
            let locale = Locale.current
            let preferredLanguages = Locale.preferredLanguages

            // Top level fields
            initialContext["locale"] = .init(string: locale.identifier) // Locale identifier (e.g., "en_US")
            initialContext["preferred_languages"] = .init(list: preferredLanguages.map { lang in
                .init(string: lang)
            })
            return self
        }

        public func build() -> ConfidenceDeviceInfoContextDecorator {
            return ConfidenceDeviceInfoContextDecorator(context: initialContext)
        }
    }

    private static func getDeviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children
            .compactMap { element in element.value as? Int8 }
            .filter { $0 != 0 }
            .map {
                Character(UnicodeScalar(UInt8($0)))
            }
        return String(identifier)
    }
}
#endif
