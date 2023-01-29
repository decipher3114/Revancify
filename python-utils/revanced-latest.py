from requests import get
from sys import argv as arg
import math
from json import load


sourcemaintainer = arg[1]

with open(f'.{sourcemaintainer}latest', 'w') as mainfile:
    try:
        data = []
        for component in ["cli", "patches", "integrations"]:
            json = get(f"https://api.github.com/repos/{sourcemaintainer}/revanced-{component}/releases/latest", headers={'user-agent': "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36" }).json()
            data.append(json['tag_name'])
            for asset in json['assets']:
                data.append(asset['browser_download_url'])
                data.append(str(int(asset['size'])))
        mainfile.write("\n".join(data))
    except:
        mainfile.write("error")
