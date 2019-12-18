# Configuration Controller功能解析

## 根据Configuration资源的Spec创建Revision资源

```
// Configuration Controller Master Reconcile
func (c *Reconciler) reconcile(ctx context.Context, config *v1alpha1.Configuration) error {
	logger := logging.FromContext(ctx)
	if config.GetDeletionTimestamp() != nil {
		return nil
	}

	// We may be reading a version of the object that was stored at an older version
	// and may not have had all of the assumed defaults specified.  This won't result
	// in this getting written back to the API Server, but lets downstream logic make
	// assumptions about defaulting.
	config.SetDefaults(v1.WithUpgradeViaDefaulting(ctx))
	config.Status.InitializeConditions()

	if err := config.ConvertUp(ctx, &v1beta1.Configuration{}); err != nil {
		if ce, ok := err.(*v1alpha1.CannotConvertError); ok {
			config.Status.MarkResourceNotConvertible(ce)
		}
		return err
	}

	// Bump observed generation to denote that we have processed this
	// generation regardless of success or failure.
	config.Status.ObservedGeneration = config.Generation

	// First, fetch the revision that should exist for the current generation.
	lcr, err := c.latestCreatedRevision(config)
	if errors.IsNotFound(err) {
		lcr, err = c.createRevision(ctx, config)
		if err != nil {
			c.Recorder.Eventf(config, corev1.EventTypeWarning, "CreationFailed", "Failed to create Revision: %v", err)

			// Mark the Configuration as not-Ready since creating
			// its latest revision failed.
			config.Status.MarkRevisionCreationFailed(err.Error())

			return fmt.Errorf("failed to create Revision: %w", err)
		}
	} else if errors.IsAlreadyExists(err) {
		// If we get an already-exists error from latestCreatedRevision it means
		// that the Revision name already exists for another Configuration or at
		// the wrong generation of this configuration.
		config.Status.MarkRevisionCreationFailed(err.Error())
		return nil
	} else if err != nil {
		return fmt.Errorf("failed to get Revision: %w", err)
	}

	revName := lcr.Name

	// Second, set this to be the latest revision that we have created.
	config.Status.SetLatestCreatedRevisionName(revName)

	// Last, determine whether we should set LatestReadyRevisionName to our
	// LatestCreatedRevision based on its readiness.
	rc := lcr.Status.GetCondition(v1alpha1.RevisionConditionReady)
	switch {
	case rc == nil || rc.Status == corev1.ConditionUnknown:
		logger.Infof("Revision %q of configuration is not ready", revName)

	case rc.Status == corev1.ConditionTrue:
		logger.Infof("Revision %q of configuration is ready", revName)
		if config.Status.LatestReadyRevisionName == "" {
			// Surface an event for the first revision becoming ready.
			c.Recorder.Event(config, corev1.EventTypeNormal, "ConfigurationReady",
				"Configuration becomes ready")
		}

	case rc.Status == corev1.ConditionFalse:
		logger.Infof("Revision %q of configuration has failed", revName)
		// TODO(mattmoor): Only emit the event the first time we see this.
		config.Status.MarkLatestCreatedFailed(lcr.Name, rc.Message)
		c.Recorder.Eventf(config, corev1.EventTypeWarning, "LatestCreatedFailed",
			"Latest created revision %q has failed", lcr.Name)

	default:
		return fmt.Errorf("unrecognized condition status: %v on revision %q", rc.Status, revName)
	}

	if err = c.findAndSetLatestReadyRevision(config); err != nil {
		return fmt.Errorf("failed to find and set latest ready revision: %w", err)
	}
	return nil
}
```