#!/usr/bin/env python3
"""PostToolUse hook: after Edit/Write on a .gd file, run gdformat then
gdlint, and feed any lint warnings back into Claude's context.

Reads the hook payload (Claude Code tool-call JSON) from stdin.
Silent on success; prints a JSON hookSpecificOutput block only when
gdlint has something to say.
"""

import json
import subprocess
import sys


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0

    file_path = (payload.get("tool_input") or {}).get("file_path") or ""
    if not file_path.endswith(".gd"):
        return 0

    subprocess.run(["gdformat", file_path], capture_output=True, text=True)
    lint = subprocess.run(["gdlint", file_path], capture_output=True, text=True)

    lint_output = (lint.stdout + lint.stderr).strip()
    if lint_output:
        print(
            json.dumps(
                {
                    "hookSpecificOutput": {
                        "hookEventName": "PostToolUse",
                        "additionalContext": f"gdlint warnings in {file_path}:\n{lint_output}",
                    }
                }
            )
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
