/// Return from user defaults if there is a value, otherwise return from Optimizely

public func featureCommentFlaggingIsEnabled() -> Bool {
  return AppEnvironment.current.userDefaults
    .optimizelyFeatureFlags[OptimizelyFeature.commentFlaggingEnabled.rawValue] ??
    (AppEnvironment.current.optimizelyClient?
      .isFeatureEnabled(featureKey: OptimizelyFeature.commentFlaggingEnabled.rawValue) ?? false)
}

public func featureProjectPageStoryTabEnabled() -> Bool {
  return AppEnvironment.current.userDefaults
    .optimizelyFeatureFlags[OptimizelyFeature.projectPageStoryTabEnabled.rawValue] ??
    (AppEnvironment.current.optimizelyClient?
      .isFeatureEnabled(featureKey: OptimizelyFeature.projectPageStoryTabEnabled.rawValue) ?? false)
}

public func featurePaymentSheetEnabled() -> Bool {
  return AppEnvironment.current.userDefaults
    .optimizelyFeatureFlags[OptimizelyFeature.paymentSheetEnabled.rawValue] ??
    (AppEnvironment.current.optimizelyClient?
      .isFeatureEnabled(featureKey: OptimizelyFeature.paymentSheetEnabled.rawValue) ?? false)
}

public func featureSettingsPaymentSheetEnabled() -> Bool {
  return AppEnvironment.current.userDefaults
    .optimizelyFeatureFlags[OptimizelyFeature.settingsPaymentSheetEnabled.rawValue] ??
    (AppEnvironment.current.optimizelyClient?
      .isFeatureEnabled(featureKey: OptimizelyFeature.settingsPaymentSheetEnabled.rawValue) ?? false)
}

public func featureFacebookLoginDeprecationEnabled() -> Bool {
  return AppEnvironment.current.userDefaults
    .optimizelyFeatureFlags[OptimizelyFeature.facebookLoginDeprecationEnabled.rawValue] ??
    (AppEnvironment.current.optimizelyClient?
      .isFeatureEnabled(featureKey: OptimizelyFeature.facebookLoginDeprecationEnabled.rawValue) ?? false)
}

public func featureConsentManagementDialogEnabled() -> Bool {
  return AppEnvironment.current.userDefaults
    .optimizelyFeatureFlags[OptimizelyFeature.consentManagementDialogEnabled.rawValue] ??
    (AppEnvironment.current.optimizelyClient?
      .isFeatureEnabled(featureKey: OptimizelyFeature.consentManagementDialogEnabled.rawValue) ?? false)
}

public func featureFacebookConversionsAPIEnabled() -> Bool {
  return AppEnvironment.current.userDefaults
    .optimizelyFeatureFlags[OptimizelyFeature.facebookConversionsAPI.rawValue] ??
    (AppEnvironment.current.optimizelyClient?
      .isFeatureEnabled(featureKey: OptimizelyFeature.facebookConversionsAPI.rawValue) ?? false)
}
