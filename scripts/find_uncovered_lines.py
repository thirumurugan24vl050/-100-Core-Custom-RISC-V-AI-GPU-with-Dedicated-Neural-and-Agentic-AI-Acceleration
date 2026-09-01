import re
import sys

filename = sys.argv[1] if len(sys.argv) > 1 else "work/report_core/metrics_0.html"
text = open(filename, "r", encoding="utf-8", errors="ignore").read()

print("Searching for line numbers and uncovered markers in:", filename)
matches = re.findall(r"(<A NAME=\"_line_(\d+)\".*?</A>.*?<BR>)", text, re.DOTALL)
if not matches:
    # Alternative pattern for IMC HTML
    for line in text.split("\n"):
        if "red" in line or "class=\"uncov\"" in line or "uncovered" in line.lower():
            clean = re.sub(r"<[^>]+>", " ", line).strip()
            if clean and len(clean) < 150:
                print("  LINE:", clean)
else:
    for m in matches[:20]:
        print(f"  Line: {m[1]}")
