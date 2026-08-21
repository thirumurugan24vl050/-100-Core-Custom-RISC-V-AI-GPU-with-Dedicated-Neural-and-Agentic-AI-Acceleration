#!/bin/bash
#=============================================================================
# Parse All Subsystems from Cadence IMC Metrics
#=============================================================================
cd /mnt/rl-home/THIRU/syn_workshop/riscv_ai_gpu/work || exit 1

echo "================================================================================"
echo " [CADENCE IMC FULL HIERARCHY COVERAGE BREAKDOWN]"
echo "================================================================================"
python3 -c "
from bs4 import BeautifulSoup
import glob

visited = set()
for filename in sorted(glob.glob('coverage_summary/node_*.html')):
    try:
        with open(filename, 'r') as f:
            soup = BeautifulSoup(f.read(), 'html.parser')
        for tr in soup.find_all('tr'):
            cells = [td.get_text(strip=True) for td in tr.find_all(['td', 'th'])]
            if len(cells) >= 5 and ('%' in cells[3] or 'Grade' in cells[3]):
                name = cells[2]
                grade = cells[3]
                covered = cells[4]
                if name not in visited and name not in ['Name', 'Types', 'Instances', 'Verification Metrics']:
                    visited.add(name)
                    print(f'{name:<35} | Grade: {grade:<10} | Covered: {covered}')
    except Exception as e:
        pass
"
echo "================================================================================"
