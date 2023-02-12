from bs4 import BeautifulSoup
from re import compile, sub
from sys import argv
from json import load
from requests import get
import re

versionlist=[]

def fetchurl(url):
    return BeautifulSoup(get(url, headers={'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.5414.86 Mobile Safari/537.36'}).content, 'html.parser')

with open(f'{argv[3]}-patches.json', "r") as patches_file:
    supportedvers = list(load(patches_file)[argv[2]]['versions'])


try:
    for a in fetchurl(f'https://www.apkmirror.com/uploads/?appcategory={argv[1]}').find(['div'], class_="listWidget").find_all(['div'], class_="appRow"):

        appver = a.find(['a'], class_="fontBlack")

        if appver != None:
            appver = appver.string
            status = "[STABLE]"
            if "beta" in appver.lower():
                status = "[BETA]"
                appver = appver.replace(" beta", "")
            elif "alpha" in appver.lower():
                status = "[ALPHA]"

            appver = re.search('(?<=\s)\w*[0-9].*\w*[0-9]\w*', appver).group()
            if appver in supportedvers:
                status = "[SUPPORTED]"

            
            print(f'{appver}\n{status}')
        else:
            pass

except:
    print("error")