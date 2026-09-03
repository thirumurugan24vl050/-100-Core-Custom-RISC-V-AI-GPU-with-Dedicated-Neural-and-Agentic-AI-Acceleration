import re
import os

path = "work/report_nmu/metrics_0.html" if os.path.exists("work/report_nmu/metrics_0.html") else "report_nmu/metrics_0.html"
text = open(path).read()

# Extract summary table
for line in re.findall(r"<TR>(.*?)</TR>", text, re.DOTALL):
    cols = re.findall(r"<T[DH][^>]*>(.*?)</T[DH]>", line, re.DOTALL)
    clean = [re.sub(r"<[^>]+>", "", c).strip() for c in cols]
    if any(clean) and any("%" in c for c in clean):
        print(" | ".join(clean))
