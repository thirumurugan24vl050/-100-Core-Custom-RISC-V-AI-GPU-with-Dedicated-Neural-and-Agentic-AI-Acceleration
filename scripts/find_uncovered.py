import re
import sys

filename = sys.argv[1] if len(sys.argv) > 1 else "work/report_core/metrics_0.html"
text = open(filename, "r", encoding="utf-8", errors="ignore").read()

print("Analyzing uncovered sections in:", filename)
# Look for block coverage section
block_match = re.search(r"Covered\+Uncovered Block Detail Report.*?</PRE>", text, re.DOTALL)
if block_match:
    lines = block_match.group(0).split("\n")
    for l in lines:
        if "Uncovered" in l or "-->" in l or "/*" in l:
            clean = re.sub(r"<[^>]+>", "", l).strip()
            if clean:
                print("  BLOCK:", clean[:100])

expr_match = re.search(r"Covered\+Uncovered Expression Detail Report.*?</PRE>", text, re.DOTALL)
if expr_match:
    lines = expr_match.group(0).split("\n")
    for l in lines:
        if "Uncovered" in l or "-->" in l or "/*" in l or "!" in l:
            clean = re.sub(r"<[^>]+>", "", l).strip()
            if clean:
                print("  EXPR:", clean[:100])
