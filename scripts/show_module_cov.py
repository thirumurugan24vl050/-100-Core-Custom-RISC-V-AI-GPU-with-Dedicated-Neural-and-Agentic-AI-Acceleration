import re
import sys
import os

folder = sys.argv[1] if len(sys.argv) > 1 else "work/report_postproc"
path = os.path.join(folder, "metrics_0.html")
if not os.path.exists(path):
    path = os.path.join("work", folder, "metrics_0.html")

if not os.path.exists(path):
    print(f"Error: {path} not found")
    sys.exit(1)

text = open(path).read()

for line in re.findall(r"<TR>(.*?)</TR>", text, re.DOTALL):
    cols = re.findall(r"<T[DH][^>]*>(.*?)</T[DH]>", line, re.DOTALL)
    clean = [re.sub(r"<[^>]+>", "", c).strip() for c in cols]
    if any(clean) and any("%" in c for c in clean):
        print(" | ".join(clean))
