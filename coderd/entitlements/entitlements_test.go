package entitlements_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	"github.com/coder/coder/v2/coderd/entitlements"
	"github.com/coder/coder/v2/codersdk"
	"github.com/coder/coder/v2/testutil"
)

func TestNew_DefaultsFailClosed(t *testing.T) {
	t.Parallel()

	set := entitlements.New()
	require.False(t, set.HasLicense())
	for _, featureName := range codersdk.FeatureNames {
		feature, ok := set.Feature(featureName)
		require.True(t, ok)
		require.False(t, feature.Enabled)
		require.Equal(t, codersdk.EntitlementNotEntitled, feature.Entitlement)
	}
}

func TestNew_BypassEnv(t *testing.T) {
	t.Setenv("CODER_LICENSE_BYPASS", "true")

	set := entitlements.New()
	require.True(t, set.HasLicense())

	appearance, ok := set.Feature(codersdk.FeatureAppearance)
	require.True(t, ok)
	require.True(t, appearance.Enabled)
	require.Equal(t, codersdk.EntitlementEntitled, appearance.Entitlement)

	browserOnly, ok := set.Feature(codersdk.FeatureBrowserOnly)
	require.True(t, ok)
	require.False(t, browserOnly.Enabled)
	require.Equal(t, codersdk.EntitlementEntitled, browserOnly.Entitlement)

	managedAgents, ok := set.Feature(codersdk.FeatureManagedAgentLimit)
	require.True(t, ok)
	require.NotNil(t, managedAgents.Limit)
	require.NotNil(t, managedAgents.SoftLimit)
}

func TestModify(t *testing.T) {
	t.Parallel()

	set := entitlements.New()
	require.False(t, set.Enabled(codersdk.FeatureMultipleOrganizations))

	set.Modify(func(entitlements *codersdk.Entitlements) {
		entitlements.Features[codersdk.FeatureMultipleOrganizations] = codersdk.Feature{
			Enabled:     true,
			Entitlement: codersdk.EntitlementEntitled,
		}
	})
	require.True(t, set.Enabled(codersdk.FeatureMultipleOrganizations))
}

func TestAllowRefresh(t *testing.T) {
	t.Parallel()

	now := time.Now()
	set := entitlements.New()
	set.Modify(func(entitlements *codersdk.Entitlements) {
		entitlements.RefreshedAt = now
	})

	ok, wait := set.AllowRefresh(now)
	require.False(t, ok)
	require.InDelta(t, time.Minute.Seconds(), wait.Seconds(), 5)

	set.Modify(func(entitlements *codersdk.Entitlements) {
		entitlements.RefreshedAt = now.Add(time.Minute * -2)
	})

	ok, wait = set.AllowRefresh(now)
	require.True(t, ok)
	require.Equal(t, time.Duration(0), wait)
}

func TestUpdate(t *testing.T) {
	t.Parallel()
	ctx := testutil.Context(t, testutil.WaitShort)

	set := entitlements.New()
	require.False(t, set.Enabled(codersdk.FeatureMultipleOrganizations))
	fetchStarted := make(chan struct{})
	firstDone := make(chan struct{})
	errCh := make(chan error, 2)
	go func() {
		err := set.Update(ctx, func(_ context.Context) (codersdk.Entitlements, error) {
			close(fetchStarted)
			select {
			case <-firstDone:
				// OK!
			case <-ctx.Done():
				t.Error("timeout")
				return codersdk.Entitlements{}, ctx.Err()
			}
			return codersdk.Entitlements{
				Features: map[codersdk.FeatureName]codersdk.Feature{
					codersdk.FeatureMultipleOrganizations: {
						Enabled: true,
					},
				},
			}, nil
		})
		errCh <- err
	}()
	testutil.TryReceive(ctx, t, fetchStarted)
	require.False(t, set.Enabled(codersdk.FeatureMultipleOrganizations))
	// start a second update while the first one is in progress
	go func() {
		err := set.Update(ctx, func(_ context.Context) (codersdk.Entitlements, error) {
			return codersdk.Entitlements{
				Features: map[codersdk.FeatureName]codersdk.Feature{
					codersdk.FeatureMultipleOrganizations: {
						Enabled: true,
					},
					codersdk.FeatureAppearance: {
						Enabled: true,
					},
				},
			}, nil
		})
		errCh <- err
	}()
	close(firstDone)
	err := testutil.TryReceive(ctx, t, errCh)
	require.NoError(t, err)
	err = testutil.TryReceive(ctx, t, errCh)
	require.NoError(t, err)
	require.True(t, set.Enabled(codersdk.FeatureMultipleOrganizations))
	require.True(t, set.Enabled(codersdk.FeatureAppearance))
}

func TestUpdate_FetchErrorKeepsFailClosedDefaults(t *testing.T) {
	t.Parallel()
	ctx := testutil.Context(t, testutil.WaitShort)

	set := entitlements.New()
	err := set.Update(ctx, func(_ context.Context) (codersdk.Entitlements, error) {
		return codersdk.Entitlements{}, errors.New("boom")
	})
	require.Error(t, err)
	require.False(t, set.HasLicense())
	require.False(t, set.Enabled(codersdk.FeatureAppearance))
}

func TestUpdate_LicenseRequiresTelemetry(t *testing.T) {
	t.Parallel()
	ctx := testutil.Context(t, testutil.WaitShort)
	set := entitlements.New()
	set.Modify(func(entitlements *codersdk.Entitlements) {
		entitlements.Errors = []string{"some error"}
		entitlements.Features[codersdk.FeatureAppearance] = codersdk.Feature{
			Enabled: true,
		}
	})
	err := set.Update(ctx, func(_ context.Context) (codersdk.Entitlements, error) {
		return codersdk.Entitlements{}, entitlements.ErrLicenseRequiresTelemetry
	})
	require.NoError(t, err)
	require.True(t, set.Enabled(codersdk.FeatureAppearance))
	require.Equal(t, []string{entitlements.ErrLicenseRequiresTelemetry.Error()}, set.Errors())
}
