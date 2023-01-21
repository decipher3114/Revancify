"""
Fetch and format list of versions from apkmirror.com
"""

from bs4 import BeautifulSoup
from re import compile
from sys import argv as arg
from json import load
from requests import get

versionlist=[]

def version(name):
    for string in name.split():
        if string[0].isdigit():
            return string
            break

version("Some 10.rele.0 hi")

def fetchurl(url):
    return BeautifulSoup(get(url, headers={'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.5414.86 Mobile Safari/537.36'}).content, 'html.parser')

with open(f'{arg[3]}-patches.json', "r") as patches_file:
    json = load(patches_file)

for app in json:
        if app['appName'] == arg[2]:
            supportedvers = list(app['versions'])
            break

try:

    for a in fetchurl(f'https://www.apkmirror.com/uploads/?appcategory={arg[1]}').find_all(text = compile(".*variants")):
        appver = ((a.parent).parent).parent.find(["a"], class_="fontBlack").string

        beta=""
        if "beta" in appver.lower():
            beta=" [BETA]"


        appver = version(appver)
        
        support=""
        if appver in supportedvers:
            support=" [SUPPORTED]"

        
        print(appver + support + beta)
    
except:
    print("error")

