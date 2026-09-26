"""Read and extend the vault tag taxonomy file (## Allowed and ## Merged tables)."""
HEADER_FIRST_CELLS = {"tag", "old"}


def table_cells(line: str) -> list[str]:
    return [cell.strip().strip("`").lstrip("#") for cell in line.strip().strip("|").split("|")]


def is_separator(line: str) -> bool:
    return set(line.strip()) <= set("|-: ")


def has_sections(text: str) -> bool:
    lowered = text.lower()
    return "## allowed" in lowered and "## merged" in lowered


def parse_taxonomy(text: str) -> tuple[dict[str, str], dict[str, str]]:
    allowed, merged, section = {}, {}, ""
    for line in text.splitlines():
        if line.startswith("## "):
            section = line[3:].strip().lower()
            continue
        if not line.startswith("|") or is_separator(line):
            continue
        cells = table_cells(line)
        if cells[0] in HEADER_FIRST_CELLS:
            continue
        if section == "allowed":
            allowed[cells[0]] = cells[1] if len(cells) > 1 else ""
        elif section == "merged" and len(cells) >= 2:
            merged[cells[0]] = cells[1]
    return allowed, merged


def add_rows(text: str, section: str, rows: list[list[str]]) -> str:
    lines = text.split("\n")
    heading = f"## {section}".lower()
    section_start = next((index for index, line in enumerate(lines) if line.strip().lower() == heading), None)
    if section_start is None:
        raise ValueError(f"taxonomy file has no '## {section}' section")
    insert_at = section_start + 1
    for index in range(section_start + 1, len(lines)):
        if lines[index].startswith("## "):
            break
        if lines[index].startswith("|"):
            insert_at = index + 1
    new_lines = ["| " + " | ".join(row) + " |" for row in rows]
    return "\n".join(lines[:insert_at] + new_lines + lines[insert_at:])
