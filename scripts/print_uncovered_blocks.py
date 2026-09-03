import re
import sys

html = open("work/report_postproc/metrics_0.html").read()
tables = re.findall(r'<TABLE[^>]*_Blockcov[^>]*>(.*?)</TABLE>', html, re.DOTALL)
if tables:
    for row in re.findall(r'<TR>(.*?)</TR>', tables[0], re.DOTALL):
        if 'uncovered' in row:
            clean = [re.sub(r'<[^>]+>', '', td).strip() for td in re.findall(r'<T[DH][^>]*>(.*?)</T[DH]>', row, re.DOTALL)]
            print(' | '.join(clean))
