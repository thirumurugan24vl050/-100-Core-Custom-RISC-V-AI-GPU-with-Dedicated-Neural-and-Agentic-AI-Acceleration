import re

html = open("work/report_postproc/metrics_0.html").read()
blocks = re.findall(r'<TD[^>]*>(.*?)</TD>\s*<TD[^>]*class="uncovered"[^>]*>(.*?)</TD>\s*<TD[^>]*>(.*?)</TD>\s*<TD[^>]*>(.*?)</TD>', html, re.IGNORECASE)
for b in blocks:
    clean = [re.sub(r'<[^>]+>', '', x).strip() for x in b]
    print(' | '.join(clean))
