import Foundation
import OpenFeature

public protocol BatchFeatureProvider {
    func initializeFromContext(ctx: EvaluationContext) throws

    func refresh(ctx: EvaluationContext) throws
}
