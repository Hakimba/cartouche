#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Fails when README.md or docs/ cite something the code no longer has: a link to a missing page or heading,
a `path` that is not in the repository, or a `ClassName`, `member` or `method_name` that no source file names;
and when docs/INVARIANTS.md and the tests disagree: an id with no test named after it, or a row whose Tests column
does not list exactly the files holding a test named after its id.

    dev/check_docs.py        prints each stale citation as file:line and exits 1 when there is one
"""
import fnmatch
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# Written at run time, never tracked: cited in the docs as what a run produces.
GENERATED = ("build/", "app/addons/gdUnit4", "kotlin/local.properties", "user://")
RUNTIME_FILES = {"snapshot.json", "start.pck", "start_next.pck", "console-variants.json"}
EXTENSIONS = ("gd tscn tres kt kts json tsv py sh gdshader gdshaderinc md svg glb png cfg godot toml properties xml "
              "txt wav ogg html pck").split()
SOURCES = ("*.gd", "*.kt", "*.c", "*.kts", "*.tscn", "*.tres", "*.json", "*.py", "*.sh", "*.cfg", "*.godot", "*.gdshader",
           "*.gdshaderinc", "*.toml", "*.properties", "*.xml", "*.import")

tracked = subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True, text=True, check=True).stdout.split()
known = set(tracked) | {str(p) for f in tracked for p in Path(f).parents if str(p) != "."}
names = set()
for source in subprocess.run(["git", "ls-files", "--", *SOURCES, ":!app/data/titles", ":!app/data/art"], cwd=ROOT,
                             capture_output=True, text=True, check=True).stdout.split():
    names.update(re.findall(r"\w+", (ROOT / source).read_text(errors="ignore")))


def slug(heading: str) -> str:
    return re.sub(r"[^\w\- ]", "", heading.strip().lower()).replace(" ", "-")


def path_problem(token: str) -> str | None:
    token = token.lstrip("(").rstrip(".,;:)")
    token = "app/" + token.removeprefix("res://") if token.startswith("res://") else token
    if token.startswith(("./", "../", "http", "ws://")) or token.startswith(GENERATED) or token in RUNTIME_FILES:
        return None
    pattern = re.sub(r"<[^>]+>", "*", token.rstrip("/"))
    if "/" not in token:
        return None if any(fnmatch.fnmatch(Path(f).name, pattern) for f in tracked) else f"no file named {token}"
    return None if pattern in known or fnmatch.filter(known, pattern) else f"no path {token}"


def looks_like_path(token: str) -> bool:
    if "://" in token and not token.startswith("res://") or "." in token.split("/")[0] and "/" in token:
        return False
    named_file = "." in token and token.rsplit(".", 1)[-1] in EXTENSIONS
    return bool(re.fullmatch(r"[\w./<>*-]+", token)) and ("/" in token or named_file)


def unknown_names(span: str) -> list[str]:
    """The names a code span cites that no source holds; a name ending in `…` or `*` is a prefix."""
    words = " ".join(t for t in span.split() if not looks_like_path(t))
    words = re.sub(r"\"[^\"]*\"|'[^']*'|--\S+", "", words)
    return [f"no source names {word}" for word, prefix in re.findall(r"(?<![\w-])([A-Za-z_]\w*)([…*]?)", words)
            if (word[0].isupper() or "_" in word or re.search(r"[a-z][A-Z]", word)) and word not in names
            and not (prefix and any(name.startswith(word) for name in names))]


def problems(doc: Path) -> list[str]:
    found = []
    fenced = None
    for number, line in enumerate(doc.read_text().splitlines(), 1):
        if line.startswith("```"):
            fenced = None if fenced is not None else line[3:].strip()
            continue
        if fenced not in (None, "sh"):
            continue
        spans = [line.split(" #")[0]] if fenced == "sh" else re.findall(r"`([^`]+)`", line)
        for span in spans:
            found += [(number, p) for t in span.split() if looks_like_path(t) and (p := path_problem(t))]
            if fenced is None:
                found += [(number, p) for p in unknown_names(span)]
        if fenced is None:
            targets = re.findall(r"\]\(([^)\s]+)\)", line)
            found += [(number, p) for target in targets for p in link_problems(doc, target)]
    return [f"{doc.relative_to(ROOT)}:{number}: {problem}" for number, problem in found]


def link_problems(doc: Path, target: str) -> list[str]:
    if target.startswith(("http://", "https://", "mailto:")):
        return []
    page, _, anchor = target.partition("#")
    page_path = (doc.parent / page).resolve() if page else doc
    if not page_path.exists():
        return [f"broken link {target}"]
    if anchor and page_path.suffix == ".md":
        headings = {slug(h) for h in re.findall(r"^#+ (.+)$", page_path.read_text(), re.M)}
        if anchor not in headings:
            return [f"no heading #{anchor} in {page or doc.name}"]
    return []


def invariant_problems() -> list[str]:
    """A test carries ids at the start of its name: Kotlin `INV-03 INV-09 …`, GDScript test_inv_03_inv_09_…."""
    tagged: dict[str, set[str]] = {}
    for test in [f for f in tracked if re.search(r"(/src/test/.*Test\.kt|^app/test/.*_test\.gd)$", f)]:
        text = (ROOT / test).read_text()
        heads = re.findall(r"fun `((?:INV-\d\d )+)", text) + re.findall(r"func test_((?:inv_\d\d_)+)", text)
        name = Path(test).stem if test.endswith(".kt") else Path(test).name
        for invariant in {i for head in heads for i in re.findall(r"\d\d", head)}:
            tagged.setdefault(f"INV-{invariant}", set()).add(name)
    doc = ROOT / "docs/INVARIANTS.md"
    rows = {m[1]: (number, set(re.findall(r"`([^`]+)`", m[2])))
            for number, line in enumerate(doc.read_text().splitlines(), 1)
            if (m := re.match(r"\| (INV-\d\d) \|.*\|([^|]*)\|$", line))}
    found = [f"docs/INVARIANTS.md:{number}: {invariant} names {', '.join(sorted(listed - tagged.get(invariant, set())))}"
             f" without a test named {invariant}" for invariant, (number, listed) in rows.items()
             if listed - tagged.get(invariant, set())]
    found += [f"docs/INVARIANTS.md:{rows[invariant][0] if invariant in rows else 1}: {invariant} does not list "
              f"{', '.join(sorted(files - rows.get(invariant, (0, set()))[1]))}, which holds a test named after it"
              for invariant, files in tagged.items() if files - rows.get(invariant, (0, set()))[1]]
    return found + [f"docs/INVARIANTS.md:{number}: {invariant} has no test named after it"
                    for invariant, (number, _) in rows.items() if invariant not in tagged]


docs = [ROOT / "README.md", *sorted((ROOT / "docs").rglob("*.md"))]
stale = [p for doc in docs for p in problems(doc)] + invariant_problems()
print("\n".join(stale) or f"docs: {len(docs)} pages, every path, name and link found")
sys.exit(1 if stale else 0)
