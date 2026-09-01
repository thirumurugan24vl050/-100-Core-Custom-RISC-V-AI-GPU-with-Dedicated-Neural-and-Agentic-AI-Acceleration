import sys
import os
import re

path = "report_core/metrics_0.html" if os.path.exists("report_core/metrics_0.html") else "work/report_core/metrics_0.html"
html = open(path).read()
idx = html.find("_Blockcov")
if idx != -1:
    content = html[idx:idx+4000]
    clean = re.sub(r"<[^>]+>", "", content)
    print(clean)
