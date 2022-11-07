"""
Fetch latest version from the github of the corresponding source repository.
"""

from httpx import AsyncClient
import asyncio
import math
from json import load

with open('sources.json', 'r') as sourcesfile:
    sourcesjson = load(sourcesfile)

for source in sourcesjson:
    if source['sourceStatus'] == "on":
        sourcemaintainer = source['sourceMaintainer']

async def fetch():
    async with AsyncClient() as client:
        jsonresponses = [client.get(f"https://api.github.com/repos/{sourcemaintainer}/revanced-{component}/releases/latest", headers={'user-agent': "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36" }) for component in ["cli", "patches", "integrations"]]
        for jsonresponse in await asyncio.gather(*jsonresponses):
            json = jsonresponse.json()
            print(json['tag_name'].replace("v", ""))
            print(int(math.fsum(asset['size'] for asset in json['assets'])))

asyncio.run(fetch())
