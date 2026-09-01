import re

html = open("work/report_core/metrics_0.html", "r", encoding="utf-8", errors="ignore").read()

# IMC marks uncovered lines in Block report with class="red" or background-color or similar
# Let's extract the Block report text
block_sec = re.search(r"<A NAME=\"_Blockcov\"></A>(.*?)<A NAME=", html, re.DOTALL)
if block_sec:
    sec_text = block_sec.group(1)
    # find lines with uncovered tags
    lines = sec_text.split("<TR")
    for l in lines:
        if "red" in l.lower() or "uncov" in l.lower() or "0" in l:
            clean = re.sub(r"<[^>]+>", " ", l).strip()
            # print if looks like a source code line
            if clean and any(kw in clean for kw in ["begin", "case", "if", "assign", "else", "state", "wire", "logic"]):
                print("UNCOVERED BLOCK:", clean[:120])
