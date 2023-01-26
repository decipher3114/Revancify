"""
Fetch and format list of versions from apkmirror.com
"""

from bs4 import BeautifulSoup
from re import compile, sub
from sys import argv as arg
from json import load
from requests import get
import re

versionlist=[]

def fetchurl(url):
    return BeautifulSoup(get(url, headers={'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.5414.86 Mobile Safari/537.36'}).content, 'html.parser')

with open(f'{arg[2]}-patches.json', "r") as patches_file:
    json = load(patches_file)

for app in json:
        if app['appName'] == arg[1]:
            supportedvers = list(app['versions'])
            break


try:
    for a in fetchurl(f'https://www.apkmirror.com/uploads/?appcategory={arg[1]}').find(['div'], class_="listWidget").find_all(['a'], class_="fontBlack"):
        appver = a.string

        beta=""
        if "beta" in appver.lower():
            beta=" [BETA]"

        alpha=""
        if "alpha" in appver.lower():
            alpha=" [ALPHA]"


        appver = re.search('(?<=\s)\d.*?(?=\s|\Z)', appver).group()
        
        support=""
        if appver in supportedvers:
            support=" [SUPPORTED]"

        
        print(appver + support + beta + alpha)
        
    print(sub('[^A-Za-z0-9]+', '-', a.parent.parent.find(['a'], class_='byDeveloper').string.replace("by ", "")))
except:
    print("error")
