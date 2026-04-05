TRUNCATE TABLE api_tokens, organizations, documents, users RESTART IDENTITY CASCADE;

INSERT INTO users (email, name, password_hash, role) VALUES
  ('alice@test.local', 'Alice Example', crypt('Test123!', gen_salt('bf', 10)), 'user'),
  ('bob@test.local', 'Bob Example', crypt('Test123!', gen_salt('bf', 10)), 'user'),
  ('admin@test.local', 'Admin Example', crypt('Test123!', gen_salt('bf', 10)), 'admin');

INSERT INTO documents (user_id, title, content, visibility) VALUES
  (1, 'Alice Payroll Notes', 'Quarterly payroll workbook draft.', 'private'),
  (1, 'Alice Product Roadmap', 'Roadmap covering Q3 feature delivery.', 'private'),
  (1, 'Alice Public FAQ', 'Public FAQ for customer onboarding.', 'public'),
  (2, 'Bob M&A Draft', 'Highly sensitive acquisition planning notes.', 'private'),
  (2, 'Bob Incident Review', 'Detailed postmortem with internal timestamps.', 'private'),
  (2, 'Bob Public Release Notes', 'Release notes safe for public distribution.', 'public');

INSERT INTO organizations (name, owner_id) VALUES
  ('Alice Labs', 1),
  ('Bob Ventures', 2);

INSERT INTO api_tokens (user_id, token, scope, expires_at) VALUES
  (1, 'token_alice_valid_demo', 'read:documents', NOW() + INTERVAL '7 days'),
  (2, 'token_bob_expired_demo', 'read:documents', NOW() - INTERVAL '1 day'),
  (3, 'token_admin_all_demo', 'admin:*', NOW() + INTERVAL '30 days');
