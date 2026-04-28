package tests

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestSnowflakeViewBasic exercises the examples/basic configuration end-to-end:
// applies it against a real Snowflake account, asserts the module's output
// maps and the view's actual state in INFORMATION_SCHEMA.VIEWS, verifies
// idempotency, and tears the view down on exit.
func TestSnowflakeViewBasic(t *testing.T) {
	t.Parallel()

	opts := buildTerraformOptions(t, "../examples/basic")
	defer terraform.Destroy(t, opts)

	terraform.InitAndApply(t, opts)

	viewIDs := terraform.OutputMap(t, opts, "view_ids")
	viewFQNs := terraform.OutputMap(t, opts, "view_fully_qualified_names")
	viewNames := terraform.OutputMap(t, opts, "view_names")
	viewIsSecure := terraform.OutputMap(t, opts, "view_is_secure")

	const expectedKey = "customer_basic"
	require.Containsf(t, viewIDs, expectedKey, "expected snowflake view output map to contain key %q", expectedKey)
	require.ElementsMatch(t, []string{expectedKey}, keys(viewIDs))
	require.ElementsMatch(t, []string{expectedKey}, keys(viewFQNs))
	require.ElementsMatch(t, []string{expectedKey}, keys(viewNames))
	require.ElementsMatch(t, []string{expectedKey}, keys(viewIsSecure))

	assert.NotEmptyf(t, viewIDs[expectedKey], "snowflake view id for %q should be non-empty", expectedKey)
	assert.NotEmptyf(t, viewFQNs[expectedKey], "snowflake view fully-qualified name for %q should be non-empty", expectedKey)
	assert.NotEmptyf(t, viewNames[expectedKey], "snowflake view name for %q should be non-empty", expectedKey)
	assert.Equalf(t, "false", strings.ToLower(viewIsSecure[expectedKey]),
		"snowflake view %q should be standard (is_secure = false), got %q", expectedKey, viewIsSecure[expectedKey])

	db := newSnowflakeClient(t)
	defer db.Close()

	for k, fqn := range viewFQNs {
		assertViewExists(t, db, fqn)
		assertViewIsSecure(t, db, fqn, false)
		t.Logf("verified snowflake view %s (%s) exists and is_secure=NO", k, fqn)
	}

	planExitCode := terraform.PlanExitCode(t, opts)
	assert.Equalf(t, 0, planExitCode, "expected idempotent plan (exit 0) for snowflake view %q, got %d", expectedKey, planExitCode)

	terraform.Destroy(t, opts)
	for _, fqn := range viewFQNs {
		assertViewDestroyed(t, db, fqn)
	}
}

func keys(m map[string]string) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	return out
}
