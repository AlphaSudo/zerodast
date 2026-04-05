import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = ROOT / "db" / "seed" / "validate_overlay.py"


def run_validator(sql_text: str):
    with tempfile.NamedTemporaryFile("w", suffix=".sql", delete=False, encoding="utf-8") as handle:
        handle.write(sql_text)
        temp_path = Path(handle.name)
    try:
        return subprocess.run(
            [sys.executable, str(VALIDATOR), str(temp_path)],
            capture_output=True,
            text=True,
            check=False,
        )
    finally:
        temp_path.unlink(missing_ok=True)


def test_valid_insert_passes():
    result = run_validator("INSERT INTO documents (user_id, title, content, visibility) VALUES (1, 'a', 'b', 'private');")
    assert result.returncode == 0, result.stderr


def test_valid_create_table_passes():
    result = run_validator("CREATE TABLE safe_fixture (id integer, note text);")
    assert result.returncode == 0, result.stderr


def test_valid_create_index_passes():
    result = run_validator("CREATE INDEX idx_safe_fixture_id ON safe_fixture (id);")
    assert result.returncode == 0, result.stderr


def test_insert_select_is_rejected():
    result = run_validator("INSERT INTO users SELECT * FROM pg_shadow;")
    assert result.returncode == 1


def test_insert_with_cte_is_rejected():
    result = run_validator("WITH seeded AS (SELECT 1) INSERT INTO users (email, name, password_hash, role) VALUES ('a@test.local', 'a', 'b', 'user');")
    assert result.returncode == 1


def test_create_function_is_rejected():
    result = run_validator("CREATE FUNCTION evil() RETURNS void AS $$ SELECT 1; $$ LANGUAGE sql;")
    assert result.returncode == 1


def test_dollar_quoting_is_rejected():
    result = run_validator("INSERT INTO documents (user_id, title, content, visibility) VALUES (1, $$x$$, 'b', 'private');")
    assert result.returncode == 1


def test_chr_obfuscation_is_rejected():
    result = run_validator("INSERT INTO documents (user_id, title, content, visibility) VALUES (1, CHR(65), 'b', 'private');")
    assert result.returncode == 1


def test_comment_obfuscation_is_rejected():
    result = run_validator("IN/*noise*/SERT INTO documents (user_id, title, content, visibility) VALUES (1, 'a', 'b', 'private');")
    assert result.returncode == 1


def test_insert_returning_is_rejected():
    result = run_validator("INSERT INTO documents (user_id, title, content, visibility) VALUES (1, 'a', 'b', 'private') RETURNING id;")
    assert result.returncode == 1


def test_on_conflict_do_update_is_rejected():
    result = run_validator("INSERT INTO users (email, name, password_hash, role) VALUES ('a@test.local', 'a', 'b', 'user') ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name;")
    assert result.returncode == 1


def test_psql_meta_commands_are_rejected():
    result = run_validator("\\copy users FROM '/tmp/users.csv';")
    assert result.returncode == 1


def test_urls_in_data_are_rejected():
    result = run_validator("INSERT INTO documents (user_id, title, content, visibility) VALUES (1, 'a', 'https://example.com', 'private');")
    assert result.returncode == 1


def test_large_file_is_rejected():
    payload = "INSERT INTO documents (user_id, title, content, visibility) VALUES (1, 'a', '" + ("x" * 101000) + "', 'private');"
    result = run_validator(payload)
    assert result.returncode == 1


def test_drop_table_is_rejected():
    result = run_validator("DROP TABLE users;")
    assert result.returncode == 1
