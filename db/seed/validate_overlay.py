#!/usr/bin/env python3
import re
import sys
from pathlib import Path

try:
    import pglast  # type: ignore
    from pglast import ast, enums, parse_sql  # type: ignore
except ImportError as exc:  # pragma: no cover
    print(f"pglast is required: {exc}", file=sys.stderr)
    sys.exit(1)

MAX_FILE_SIZE = 100_000
META_COMMAND_PATTERN = re.compile(r"^\s*\\(copy|!|i|ir|o|g|set|connect)\b", re.IGNORECASE | re.MULTILINE)
URL_OR_IP_PATTERN = re.compile(
    r"(?:https?://|ftp://|\b(?:\d{1,3}\.){3}\d{1,3}\b|\b[a-z0-9.-]+\.(?:com|net|org|io|dev|app|local)\b)",
    re.IGNORECASE,
)
DOLLAR_QUOTE_PATTERN = re.compile(r"\$[^$]*\$")
COMMENT_OBFUSCATION_PATTERN = re.compile(r"/(?:\*.*?\*/)", re.DOTALL)
DANGEROUS_FUNCTIONS = {
    "pg_read_file",
    "pg_read_binary_file",
    "pg_ls_dir",
    "dblink",
    "dblink_connect",
    "lo_import",
    "lo_export",
    "copy_program",
    "chr",
}
ALLOWED_NODE_TYPES = {
    "InsertStmt",
    "CreateStmt",
    "IndexStmt",
    "AlterTableStmt",
    "RawStmt",
}


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def read_content(path: Path) -> str:
    if not path.exists():
        fail(f"Overlay file not found: {path}")
    if path.stat().st_size > MAX_FILE_SIZE:
        fail("Overlay rejected: file exceeds 100KB limit")
    return path.read_text(encoding="utf-8")


def detect_raw_hazards(sql_text: str) -> None:
    if META_COMMAND_PATTERN.search(sql_text):
        fail("Overlay rejected: psql meta-commands are not allowed")
    if URL_OR_IP_PATTERN.search(sql_text):
        fail("Overlay rejected: URLs and IP-like values are not allowed in overlay data")
    if DOLLAR_QUOTE_PATTERN.search(sql_text):
        fail("Overlay rejected: dollar-quoted strings are not allowed")
    if COMMENT_OBFUSCATION_PATTERN.search(sql_text):
        fail("Overlay rejected: block comments are not allowed due to obfuscation risk")


def iter_nodes(node, seen=None):
    if node is None:
        return

    if seen is None:
        seen = set()

    if isinstance(node, (list, tuple)):
        for item in node:
            yield from iter_nodes(item, seen)
        return

    marker = id(node)
    if marker in seen:
        return
    seen.add(marker)

    yield node

    if hasattr(node, "__dict__"):
        for value in node.__dict__.values():
            yield from iter_nodes(value, seen)
    if hasattr(node, "__slots__"):
        for slot in node.__slots__:
            if slot in {"ancestors"}:
                continue
            try:
                value = getattr(node, slot)
            except AttributeError:
                continue
            yield from iter_nodes(value, seen)


def node_name(node) -> str:
    return type(node).__name__


def validate_insert(stmt) -> None:
    if getattr(stmt, "withClause", None) is not None:
        fail("Overlay rejected: CTEs are not allowed in INSERT statements")
    if getattr(stmt, "returningList", None):
        fail("Overlay rejected: RETURNING is not allowed in INSERT statements")
    if getattr(stmt, "onConflictClause", None) is not None:
        action = getattr(stmt.onConflictClause, "action", None)
        if action not in (None, enums.OnConflictAction.ONCONFLICT_NONE):
            fail("Overlay rejected: ON CONFLICT actions are not allowed")
    select_stmt = getattr(stmt, "selectStmt", None)
    if select_stmt is None:
        fail("Overlay rejected: INSERT statement must provide explicit VALUES")
    if node_name(select_stmt) != "SelectStmt":
        fail("Overlay rejected: unsupported INSERT source")
    if getattr(select_stmt, "withClause", None) is not None:
        fail("Overlay rejected: nested CTEs are not allowed")
    if getattr(select_stmt, "fromClause", None):
        fail("Overlay rejected: INSERT .. SELECT is not allowed")
    values_lists = getattr(select_stmt, "valuesLists", None)
    if not values_lists:
        fail("Overlay rejected: INSERT must use literal VALUES")


def validate_create(stmt) -> None:
    relation = getattr(stmt, "relation", None)
    if relation is None:
        fail("Overlay rejected: malformed CREATE statement")
    if getattr(stmt, "is_select_into", False):
        fail("Overlay rejected: CREATE TABLE AS is not allowed")


def validate_alter(stmt) -> None:
    commands = getattr(stmt, "cmds", []) or []
    for command in commands:
        subtype = getattr(command, "subtype", None)
        if subtype != enums.AlterTableType.AT_AddColumn:
            fail("Overlay rejected: ALTER TABLE only supports ADD COLUMN")


def validate_functions(tree) -> None:
    for node in iter_nodes(tree):
        name = node_name(node)
        if name in {"DropStmt", "DeleteStmt", "UpdateStmt", "TruncateStmt", "CopyStmt"}:
            fail(f"Overlay rejected: {name} is not allowed")
        if name in {"CreateFunctionStmt", "DoStmt"}:
            fail(f"Overlay rejected: {name} is not allowed")
        if name == "FuncCall":
            funcname = getattr(node, "funcname", []) or []
            parts = [getattr(part, "sval", None) for part in funcname]
            normalized = ".".join([part for part in parts if part]).lower()
            if normalized in DANGEROUS_FUNCTIONS:
                fail(f"Overlay rejected: dangerous function '{normalized}' is not allowed")


def validate_ast(sql_text: str) -> None:
    try:
        statements = parse_sql(sql_text)
    except Exception as exc:
        fail(f"Overlay rejected: SQL could not be parsed: {exc}")

    for raw_stmt in statements:
        stmt = getattr(raw_stmt, "stmt", raw_stmt)
        current_type = node_name(stmt)
        if current_type not in ALLOWED_NODE_TYPES:
            fail(f"Overlay rejected: statement type {current_type} is not allowed")
        if current_type == "InsertStmt":
            validate_insert(stmt)
        elif current_type == "CreateStmt":
            validate_create(stmt)
        elif current_type == "AlterTableStmt":
            validate_alter(stmt)

    validate_functions(statements)


def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: validate_overlay.py <overlay.sql>", file=sys.stderr)
        raise SystemExit(1)

    path = Path(sys.argv[1])
    sql_text = read_content(path)
    detect_raw_hazards(sql_text)
    validate_ast(sql_text)
    print("Overlay valid")


if __name__ == "__main__":
    main()


