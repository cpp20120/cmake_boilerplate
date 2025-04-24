#!/usr/bin/env python3
import os
import shutil
import subprocess
import sys
import re
from pathlib import Path

def find_source_files(project_root):
    input_dirs = [
        project_root / "include",
        project_root / "src",
        *list((project_root / "lib").glob("*/include")),
        *list((project_root / "lib").glob("*/src"))
    ]

    extensions = ['*.h', '*.hpp', '*.c', '*.cpp', '*.cc', '*.cxx', '*.py', '*.java']
    source_files = []

    for directory in input_dirs:
        if directory.exists():
            for ext in extensions:
                source_files.extend(directory.rglob(ext))

    return sorted(source_files)

def generate_doxygen():
    project_root = Path(__file__).parent.parent.resolve()
    docs_dir = project_root / "docs"
    doxyfile_in = docs_dir / "Doxyfile.in"
    build_docs_dir = docs_dir / "build_docs"

    if build_docs_dir.exists():
        shutil.rmtree(build_docs_dir)
    build_docs_dir.mkdir(parents=True)


    source_files = find_source_files(project_root)
    if not source_files:
        print("Error: No source files found for documentation")
        return 1

    print(f"Found {len(source_files)} source files for documentation")

    with open(doxyfile_in, 'r', encoding='utf-8') as f:
        doxyfile_content = f.read()

    config = {
        'PROJECT_NAME': 'API Documentation',
        'INPUT': ' '.join(f'"{f}"' for f in source_files),
        'RECURSIVE': 'YES',
        'EXTRACT_ALL': 'YES',
        'EXTRACT_PRIVATE': 'YES',
        'EXTRACT_STATIC': 'YES',
        'SOURCE_BROWSER': 'YES',
        'REFERENCED_BY_RELATION': 'YES',
        'REFERENCES_RELATION': 'YES',
        'GENERATE_TREEVIEW': 'YES',
        'FILE_PATTERNS': '*.c *.cc *.cxx *.cpp *.c++ *.h *.hh *.hxx *.hpp *.h++ *.py',
        'ENABLE_PREPROCESSING': 'YES',
        'MACRO_EXPANSION': 'YES',
        'EXPAND_ONLY_PREDEF': 'YES',
        'PREDEFINED': 'DOXYGEN_SHOULD_SKIP_THIS',
        'EXTRACT_PACKAGE': 'YES',
        'HIDE_UNDOC_MEMBERS': 'NO',
        'HIDE_UNDOC_CLASSES': 'NO'
    }

    for key, value in config.items():
        pattern = f"{key}\\s*=.*"
        replacement = f"{key} = {value}"
        lines = []
        for line in doxyfile_content.split('\n'):
            if re.match(pattern, line):
                lines.append(replacement)
            else:
                lines.append(line)
        doxyfile_content = '\n'.join(lines)

    doxyfile = build_docs_dir / "Doxyfile"
    with open(doxyfile, 'w', encoding='utf-8') as f:
        f.write(doxyfile_content)

    try:
        doxygen_exec = 'doxygen.exe' if os.name == 'nt' else 'doxygen'
        result = subprocess.run([doxygen_exec, '--version'],
                                check=True,
                                capture_output=True,
                                text=True)
        print(f"Using Doxygen version: {result.stdout.strip()}")
    except Exception as e:
        print(f"Error: {e}")
        return 1

    print("\nGenerating documentation...")
    try:
        subprocess.run([doxygen_exec, str(doxyfile)],
                       cwd=str(project_root),
                       check=True)
    except subprocess.CalledProcessError as e:
        print(f"Generation failed: {e}")
        return 1

    index_html = build_docs_dir / "html" / "index.html"
    if not index_html.exists():
        print("Error: Documentation was not generated")
        return 1

    print(f"\nDocumentation successfully generated at:\n{index_html}")

    try:
        if sys.platform == "win32":
            os.startfile(index_html)
        elif sys.platform == "darwin":
            subprocess.run(["open", str(index_html)], check=True)
        else:
            subprocess.run(["xdg-open", str(index_html)], check=True)
    except Exception as e:
        print(f"Note: Could not open browser: {e}")

if __name__ == "__main__":
    sys.exit(generate_doxygen())