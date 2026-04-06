const appUrl = (process.argv[2] || process.env.APP_URL || 'http://untrusted-app:8080').replace(/\/$/, '');
const expectIdor = String(process.env.EXPECT_IDOR || 'true').toLowerCase() === 'true';

async function login(email) {
  const response = await fetch(`${appUrl}/api/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email, password: 'Test123!' }),
  });

  const body = await response.text();
  if (!response.ok) {
    throw new Error(`Unable to authenticate ${email}: ${body}`);
  }

  let parsed;
  try {
    parsed = JSON.parse(body);
  } catch {
    throw new Error(`Unable to parse login response for ${email}: ${body}`);
  }

  if (!parsed.token) {
    throw new Error(`Login response missing token for ${email}: ${body}`);
  }

  return parsed.token;
}

async function request(path, options = {}) {
  const response = await fetch(`${appUrl}${path}`, options);
  await response.text();
  return response.status;
}

function recordResult(name, status, counters) {
  if (status === 200 || status === 204) {
    console.log(`IDOR detected: ${name} returned HTTP ${status}`);
    counters.detected += 1;
    if (!expectIdor) {
      counters.failures += 1;
    }
  } else {
    console.log(`Protected as expected for ${name}: HTTP ${status}`);
    if (expectIdor) {
      counters.failures += 1;
    }
  }
}

async function main() {
  const counters = { detected: 0, failures: 0 };
  const aliceToken = await login('alice@test.local');
  const bobToken = await login('bob@test.local');

  recordResult(
    'Alice reads Bob private document',
    await request('/api/documents/4', {
      headers: { Authorization: `Bearer ${aliceToken}` },
    }),
    counters,
  );

  recordResult(
    'Bob deletes Alice document',
    await request('/api/documents/1', {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${bobToken}` },
    }),
    counters,
  );

  recordResult(
    'Bob updates Alice profile',
    await request('/api/users/1', {
      method: 'PUT',
      headers: {
        Authorization: `Bearer ${bobToken}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({ name: 'Tampered Alice' }),
    }),
    counters,
  );

  console.log(`AuthZ detections: ${counters.detected}`);
  if (expectIdor && counters.detected === 0) {
    console.warn('WARNING: No IDOR detected; demo app may have been hardened unexpectedly');
  }

  if (counters.failures > 0) {
    process.exit(1);
  }
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
