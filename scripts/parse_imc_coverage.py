import re
import sys
import os

html_file = sys.argv[1] if len(sys.argv) > 1 else "work/report_summary/metrics_0.html"

if not os.path.exists(html_file):
    print(f"File {html_file} not found")
    sys.exit(1)

content = open(html_file, "r", encoding="utf-8", errors="ignore").read()
rows = re.findall(r"<tr[^>]*>(.*?)</tr>", content, re.DOTALL)

print("=" * 85)
print(f" CADENCE IMC COVERAGE SUMMARY REPORT: {html_file}")
print("=" * 85)

for row in rows:
    cols = re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", row, re.DOTALL)
    cleaned = [re.sub(r"<[^>]+>", "", c).strip() for c in cols]
    if cleaned and any(cleaned):
        # Filter out empty spacer rows
        print(" | ".join(c for c in cleaned if c))

print("=" * 85)
