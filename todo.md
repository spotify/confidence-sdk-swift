# TODO

- [X] Batch-resolve to improve performance
- [ ] Figure out good file naming scheme that has neglible risk of colliding for multiple apps, identifiers etc
- [ ] Figure out lifescycle, should the persistence instead respond to app lifecycle
- [ ] Check how grpc connection state respects NWConnectionPath state
- [ ] Add support for mocked tests from customer side
- [X] Consider whether http might be more convenient for customer than grpc because we get fewer dependencies
- [ ] Figure out how to handle re-installation
- [X] Improve testing around the "apply" being executed by the batch provider
- [ ] Automatically retry "apply" for entries in cached marked as "appliedFailed"
- [X] Don't use the ConfidenceFeatureProvider inside the ConfidenceBatchFeatureProvider, share common logic instead
- [ ] Figure out how to deal with different EvaluationContexts between cache and user input
  - How to separate identifiers and other context properties
  - Store multiple caches for different identifiers
