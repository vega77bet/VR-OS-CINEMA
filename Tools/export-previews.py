"""Export the actual native SceneKit scene, never a separately drawn mock-up."""
import json
from pathlib import Path
import shutil
import subprocess
import sys

result, output = Path(sys.argv[1]), Path(sys.argv[2])
output.mkdir(parents=True, exist_ok=True)
simulators = Path.home() / "Library/Developer/CoreSimulator/Devices"
for source in sorted(simulators.glob("*/data/Containers/Data/Application/*/Documents/CinemaPreviews/*.png")):
    shutil.copyfile(source, output / source.name)

attachments = output / "TestAttachments"
if result.exists():
    process = subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", str(result),
                              "--output-path", str(attachments)], capture_output=True, text=True)
    if process.returncode:
        print(process.stderr, file=sys.stderr)
    elif (attachments / "manifest.json").exists():
        manifest = json.loads((attachments / "manifest.json").read_text())

        def visit(item):
            if isinstance(item, list):
                for child in item:
                    visit(child)
            elif isinstance(item, dict):
                filename = item.get("exportedFileName")
                name = item.get("suggestedHumanReadableName", "")
                if filename and name.startswith(("06-", "07-")):
                    source = attachments / filename
                    if source.exists():
                        shutil.copyfile(source, output / (name.removesuffix(".png") + ".png"))
                for child in item.values():
                    visit(child)
        visit(manifest)

files = sorted(output.glob("*.png"))
if len(files) < 5:
    raise SystemExit(f"Expected five native scene previews; found {len(files)}")
for path in files:
    print(path)
