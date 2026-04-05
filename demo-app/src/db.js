const { Pool } = require("pg");

const DEFAULT_DATABASE_URL =
  "postgresql://testuser:throwaway_ci_test_pass@localhost:5432/testdb";

const pool = new Pool({
  connectionString: process.env.DATABASE_URL || DEFAULT_DATABASE_URL,
});

async function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForDatabase(maxRetries = 10, intervalMs = 2000) {
  let lastError;

  for (let attempt = 1; attempt <= maxRetries; attempt += 1) {
    try {
      await pool.query("SELECT 1");
      return;
    } catch (error) {
      lastError = error;
      if (attempt < maxRetries) {
        await sleep(intervalMs);
      }
    }
  }

  throw new Error(
    `Database connection failed after ${maxRetries} attempts: ${lastError?.message || "unknown error"}`
  );
}

module.exports = {
  pool,
  waitForDatabase,
};
