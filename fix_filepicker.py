import re
import glob
import os

files_to_check = glob.glob('lib/**/*.dart', recursive=True)

for filepath in files_to_check:
    with open(filepath, 'r') as f:
        content = f.read()

    modified = False
    if 'FilePicker.saveFile' in content:
        content = content.replace('FilePicker.saveFile', 'FilePicker.platform.saveFile')
        modified = True
    if 'FilePicker.pickFiles' in content:
        content = content.replace('FilePicker.pickFiles', 'FilePicker.platform.pickFiles')
        modified = True

    if modified:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Fixed {filepath}")
