"""
Fetch latest version from the github of the corresponding source repository.
"""

from requests import get, Session
from json import load

with open('sources.json', 'r') as sourcesfile:
    sourcesjson = load(sourcesfile)

for source in sourcesjson:
    if source['sourceStatus'] == "on":
        sourcemaintainer = source['sourceMaintainer']

components = ["cli", "patches", "integrations"]
for component in components:
    json = get(f"https://api.github.com/repos/{sourcemaintainer}/revanced-{component}/releases/latest").json()
    print(json['tag_name'].replace("v", ""))
    size = 0
    for i in json['assets']:
        size += int(i['size'])
    print(size)