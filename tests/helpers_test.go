package tests

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	sf "github.com/snowflakedb/gosnowflake"
	"github.com/stretchr/testify/require"
)

const snowflakeQueryTimeout = 30 * time.Second

func requireEnv(t *testing.T, key string) string {
	t.Helper()
	val := os.Getenv(key)
	require.NotEmptyf(t, val, "environment variable %s must be set for Snowflake view tests", key)
	return val
}

func uniqueSuffix(t *testing.T) string {
	t.Helper()
	buf := make([]byte, 4)
	_, err := rand.Read(buf)
	require.NoError(t, err, "failed to generate random suffix")
	return strings.ToLower(hex.EncodeToString(buf))
}

func buildTerraformOptions(t *testing.T, exampleDir string) *terraform.Options {
	t.Helper()

	suffix := uniqueSuffix(t)
	t.Logf("snowflake-view test suffix: %s", suffix)

	return terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: exampleDir,
		Vars: map[string]interface{}{
			"database": requireEnv(t, "SNOWFLAKE_TEST_DATABASE"),
			"schema":   requireEnv(t, "SNOWFLAKE_TEST_SCHEMA"),
		},
		EnvVars: map[string]string{
			"SNOWFLAKE_ACCOUNT":     requireEnv(t, "SNOWFLAKE_ACCOUNT"),
			"SNOWFLAKE_USER":        requireEnv(t, "SNOWFLAKE_USER"),
			"SNOWFLAKE_PRIVATE_KEY": requireEnv(t, "SNOWFLAKE_PRIVATE_KEY"),
			"SNOWFLAKE_ROLE":        requireEnv(t, "SNOWFLAKE_ROLE"),
			"SNOWFLAKE_WAREHOUSE":   requireEnv(t, "SNOWFLAKE_WAREHOUSE"),
		},
		NoColor: true,
	})
}

func newSnowflakeClient(t *testing.T) *sql.DB {
	t.Helper()

	cfg := &sf.Config{
		Account:       requireEnv(t, "SNOWFLAKE_ACCOUNT"),
		User:          requireEnv(t, "SNOWFLAKE_USER"),
		Role:          requireEnv(t, "SNOWFLAKE_ROLE"),
		Warehouse:     requireEnv(t, "SNOWFLAKE_WAREHOUSE"),
		Database:      requireEnv(t, "SNOWFLAKE_TEST_DATABASE"),
		Schema:        requireEnv(t, "SNOWFLAKE_TEST_SCHEMA"),
		Authenticator: sf.AuthTypeJwt,
		PrivateKey:    nil,
	}

	dsn, err := sf.DSN(cfg)
	require.NoError(t, err, "failed to build Snowflake DSN")

	db, err := sql.Open("snowflake", dsn)
	require.NoError(t, err, "failed to open Snowflake connection")

	ctx, cancel := context.WithTimeout(context.Background(), snowflakeQueryTimeout)
	defer cancel()
	require.NoError(t, db.PingContext(ctx), "failed to ping Snowflake")

	return db
}

func splitFQN(t *testing.T, fqn string) (database, schema, name string) {
	t.Helper()
	parts := strings.Split(fqn, ".")
	require.Lenf(t, parts, 3, "expected fully-qualified view name in DATABASE.SCHEMA.NAME form, got %q", fqn)
	return parts[0], parts[1], parts[2]
}

func assertViewExists(t *testing.T, db *sql.DB, fullyQualifiedName string) {
	t.Helper()

	database, schema, name := splitFQN(t, fullyQualifiedName)

	ctx, cancel := context.WithTimeout(context.Background(), snowflakeQueryTimeout)
	defer cancel()

	const q = `
		SELECT COUNT(*)
		FROM IDENTIFIER(?).INFORMATION_SCHEMA.VIEWS
		WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?
	`

	var count int
	err := db.QueryRowContext(ctx, q, database, schema, name).Scan(&count)
	require.NoErrorf(t, err, "failed to look up snowflake view %s in INFORMATION_SCHEMA.VIEWS", fullyQualifiedName)
	require.Equalf(t, 1, count, "expected snowflake view %s to exist exactly once in INFORMATION_SCHEMA.VIEWS", fullyQualifiedName)
}

func assertViewIsSecure(t *testing.T, db *sql.DB, fullyQualifiedName string, expected bool) {
	t.Helper()

	database, schema, name := splitFQN(t, fullyQualifiedName)

	ctx, cancel := context.WithTimeout(context.Background(), snowflakeQueryTimeout)
	defer cancel()

	const q = `
		SELECT IS_SECURE
		FROM IDENTIFIER(?).INFORMATION_SCHEMA.VIEWS
		WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?
	`

	var isSecure string
	err := db.QueryRowContext(ctx, q, database, schema, name).Scan(&isSecure)
	require.NoErrorf(t, err, "failed to read IS_SECURE for snowflake view %s", fullyQualifiedName)

	expectedStr := "NO"
	if expected {
		expectedStr = "YES"
	}
	require.Equalf(t, expectedStr, strings.ToUpper(isSecure),
		"snowflake view %s IS_SECURE mismatch (expected %s, got %s)", fullyQualifiedName, expectedStr, isSecure)
}

func assertViewDestroyed(t *testing.T, db *sql.DB, fullyQualifiedName string) {
	t.Helper()

	database, schema, name := splitFQN(t, fullyQualifiedName)

	ctx, cancel := context.WithTimeout(context.Background(), snowflakeQueryTimeout)
	defer cancel()

	const q = `
		SELECT COUNT(*)
		FROM IDENTIFIER(?).INFORMATION_SCHEMA.VIEWS
		WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?
	`

	var count int
	err := db.QueryRowContext(ctx, q, database, schema, name).Scan(&count)
	require.NoErrorf(t, err, "failed to look up snowflake view %s in INFORMATION_SCHEMA.VIEWS post-destroy", fullyQualifiedName)
	require.Equalf(t, 0, count, "expected snowflake view %s to be absent after terraform destroy, found %d", fullyQualifiedName, count)
}

// stripSchemaPrefix is a small convenience used in test diagnostics.
func stripSchemaPrefix(fqn string) string {
	parts := strings.Split(fqn, ".")
	if len(parts) == 0 {
		return fqn
	}
	return fmt.Sprintf("%s", parts[len(parts)-1])
}
