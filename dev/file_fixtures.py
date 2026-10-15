#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Builds the disc images the core's file-reading tests decode, in kotlin/core/src/test/resources/files:
a tiny ISO 9660 image whose SYSTEM.CNF boots SLES_524.95, then the same image as a raw .bin, as CD CHDs
(each codec and track type) and as DVD CHDs, and one whose root directory spans two sectors. Needs genisoimage
and chdman."""
import hashlib
import subprocess
import tempfile
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "kotlin/core/src/test/resources/files"
SERIAL = "SLES_524.95"
SYNC = b"\x00" + b"\xff" * 10 + b"\x00"
PADDED = 128 * 1024
# The runs image: the volume padded to 32 sectors, 40 sectors each filled with its number from 1 (distinct hunks of
# one codec, which the map run-length codes), then 4 sectors of hashes (incompressible: hunks stored as they are).
RUNS = (32, 40, 4)


def iso(folder: Path, empty_files: int = 0) -> bytes:
    (folder / "SYSTEM.CNF").write_text(f"BOOT2 = cdrom0:\\{SERIAL};1\r\nVER = 1.00\r\nVMODE = PAL\r\n")
    # Several files, so the root directory holds more than one record, and one of them large enough to span sectors.
    (folder / "README.TXT").write_text("A disc image for tests, not a game.\n")
    (folder / "DATA.BIN").write_bytes(bytes(range(256)) * 24)
    # Empty files named to come before SYSTEM.CNF: enough records to fill the root directory's first sector.
    for n in range(empty_files):
        (folder / f"A{n:02d}.DAT").write_bytes(b"")
    out = folder / "disc.iso"
    subprocess.run(["genisoimage", "-quiet", "-iso-level", "1", "-no-pad", "-o", str(out), str(folder)], check=True)
    return out.read_bytes()


def crowded() -> None:
    """The volume with 60 more files at its root, before SYSTEM.CNF: a root directory over two sectors."""
    with tempfile.TemporaryDirectory() as temp:
        (OUT / "disc-crowded.iso").write_bytes(iso(Path(temp), empty_files=60))


def frames(data: bytes, mode: int, raw: bool) -> bytes:
    """The image's sectors as a CD writes them: sync, header (minute, second, frame, mode), subheader for mode 2,
    the data, then room for the error codes (zeros: readers only need the mode byte and the data)."""
    out = []
    for n in range(len(data) // 2048):
        sector = data[n * 2048:(n + 1) * 2048]
        head = (SYNC + bytes([0, 2, n, mode]) if raw else b"") + (bytes(8) if mode == 2 else b"")
        out.append((head + sector).ljust(2352 if raw else 2336, b"\0"))
    return b"".join(out)


def hashed(sector: int) -> bytes:
    """2048 bytes no codec shrinks, which the tests compute the same way."""
    return b"".join(hashlib.sha256(f"{sector}.{i}".encode()).digest() for i in range(64))


def runs(data: bytes) -> bytes:
    padded, filled, incompressible = RUNS
    return (data.ljust(padded * 2048, b"\0") + b"".join(bytes([n + 1]) * 2048 for n in range(filled))
            + b"".join(hashed(n) for n in range(incompressible)))


def chd(source: Path, out: Path, *options: str) -> None:
    subprocess.run(["chdman", *options, "-f", "-i", str(source), "-o", str(out)], check=True, capture_output=True)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    crowded()
    with tempfile.TemporaryDirectory() as temp:
        folder = Path(temp)
        volume = iso(folder)
        (OUT / "disc.iso").write_bytes(volume)
        (OUT / "disc.bin").write_bytes(frames(volume, 1, raw=True))
        # chdman 0.242 writes a map it cannot read back for images under about 100 KB; the padding also makes
        # hunks of zeros, which the map stores as references to an earlier hunk.
        data = volume.ljust(PADDED, b"\0")
        (folder / "padded.iso").write_bytes(data)
        chd(folder / "padded.iso", OUT / "cd-cdlz.chd", "createcd", "-c", "cdlz")
        chd(folder / "padded.iso", OUT / "cd-cdzl.chd", "createcd", "-c", "cdzl")
        chd(folder / "padded.iso", OUT / "cd-cdfl.chd", "createcd", "-c", "cdfl")
        for name, mode, raw in (("mode1-raw", 1, True), ("mode2-raw", 2, True), ("mode2", 2, False)):
            kind = f"MODE{mode}/{2352 if raw else 2336}"
            (folder / f"{name}.bin").write_bytes(frames(data, mode, raw))
            (folder / f"{name}.cue").write_text(f'FILE "{name}.bin" BINARY\n  TRACK 01 {kind}\n    INDEX 01 00:00:00\n')
            chd(folder / f"{name}.cue", OUT / f"cd-{name}.chd", "createcd", "-c", "cdlz")
        # A cue sheet cannot name this track type; a cdrdao table of contents can, with the track's length.
        n = len(data) // 2048
        length = f"{n // 4500:02d}:{n // 75 % 60:02d}:{n % 75:02d}"
        (folder / "mode2-form-mix.toc").write_text(f'CD_ROM_XA\nTRACK MODE2_FORM_MIX\nDATAFILE "mode2.bin" {length}\n')
        chd(folder / "mode2-form-mix.toc", OUT / "cd-mode2-form-mix.chd", "createcd", "-c", "cdlz")
        # chdman's createdvd stores 2048-byte sectors with these codecs; createraw makes the same hunks.
        chd(folder / "padded.iso", OUT / "dvd-lzma.chd", "createraw", "-us", "2048", "-hs", "16384", "-c", "lzma")
        chd(folder / "padded.iso", OUT / "dvd-zlib.chd", "createraw", "-us", "2048", "-hs", "16384", "-c", "zlib")
        # One sector per hunk, and the metadata entry `createdvd` writes, which names no track. chdman adds metadata
        # only to an uncompressed image, which its copy then compresses.
        (folder / "runs.iso").write_bytes(runs(volume))
        chd(folder / "runs.iso", folder / "runs.chd", "createraw", "-us", "2048", "-hs", "2048", "-c", "none")
        subprocess.run(["chdman", "addmeta", "-i", str(folder / "runs.chd"), "-t", "DVD ", "-vt", "DVD"], check=True, capture_output=True)
        chd(folder / "runs.chd", OUT / "dvd-runs.chd", "copy", "-c", "lzma")
    for file in sorted(OUT.iterdir()):
        print(f"{file.name}\t{file.stat().st_size}")


if __name__ == "__main__":
    main()
