import glob
import re
import os

files = sorted(glob.glob("work/report_summary/*.html"))
print("=" * 80)
print(" CADENCE IMC MULTI-METRIC DETAILED COVERAGE BREAKDOWN")
print("=" * 80)

for filepath in files:
    filename = os.path.basename(filepath)
    content = open(filepath, "r", encoding="utf-8", errors="ignore").read()
    
    # Extract Type/Module name
    type_match = re.search(r"Type name:\s*</B>\s*(\w+)", content)
    type_name = type_match.group(1) if type_match else filename
    
    # Find all table rows
    rows = re.findall(r"<tr[^>]*>(.*?)</tr>", content, re.DOTALL)
    scored_rows = []
    for r in rows:
        cells = re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", r, re.DOTALL)
        clean_cells = [re.sub(r"<[^>]+>", "", c).strip() for c in cells]
        if any("%" in c for c in clean_cells):
            scored_rows.append(" | ".join(c for c in clean_cells if c))
            
    if scored_rows:
        print(f"\n[MODULE/SCOPE: {type_name}] ({filename})")
        for s in scored_rows[:5]:
            print(f"  {s}")

print("\n" + "=" * 80)
