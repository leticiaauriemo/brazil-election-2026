"""Checksum and archive the frozen Ranqia coding handoff.

Input: output/ranqia_handoff prepared by 11_prepare_handoff.R.
Output: SHA256SUMS inside the folder and output/ranqia_handoff.zip.
Only Python's standard library is needed. The processed input is not modified.
"""
from pathlib import Path
import hashlib
import zipfile

# 1. Verify the complete, credential-free file inventory -------------------------
output = Path(__file__).resolve().parent.parent / "output"
folder = output / "ranqia_handoff"
files = ["responses.parquet", "code_responses.py", "codebook.json", "requirements.txt",
         "README.md", "handoff_manifest.json"]
for name in files:
    if not (folder / name).is_file():
        raise FileNotFoundError(folder / name)

# 2. Content hashes let the recipient verify the exact research handoff -----------
checksums = []
for name in files:
    digest = hashlib.sha256()
    with (folder / name).open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(block)
    checksums.append(f"{digest.hexdigest()}  {name}")
(folder / "SHA256SUMS").write_text("\n".join(checksums) + "\n")

# 3. Parquet is already compressed; storing avoids a second compression pass -----
archive = output / "ranqia_handoff.zip"
temporary = archive.with_suffix(".zip.tmp")
with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_STORED) as bundle:
    for name in files + ["SHA256SUMS"]:
        bundle.write(folder / name, arcname=f"ranqia_handoff/{name}")
with zipfile.ZipFile(temporary) as bundle:
    bad = bundle.testzip()
    if bad is not None:
        raise ValueError(f"Archive verification failed: {bad}")
temporary.replace(archive)
print(f"Verified handoff archive: {archive} ({archive.stat().st_size:,} bytes)")
