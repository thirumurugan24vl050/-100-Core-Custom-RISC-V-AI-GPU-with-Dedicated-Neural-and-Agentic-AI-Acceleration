import glob
from bs4 import BeautifulSoup
for filename in sorted(glob.glob('softmax_cov_report/node_*.html')):
    try:
        with open(filename, 'r') as f:
            soup = BeautifulSoup(f.read(), 'html.parser')
        for tr in soup.find_all('tr'):
            cells = [td.get_text(strip=True) for td in tr.find_all(['td', 'th'])]
            if len(cells) >= 3 and 'Verification Metrics' in cells[0]:
                print("====", filename, "====")
            if len(cells) >= 3:
                print(' | '.join(cells))
    except Exception as e:
        pass
