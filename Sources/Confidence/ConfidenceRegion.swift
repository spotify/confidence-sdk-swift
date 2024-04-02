import Foundation

/// Sets the region for the network request to the Confidence backend.
/// This is applied for both sending events as well as fetching flag's data.
public enum ConfidenceRegion {
    case global
    case europe
    case usa
}
