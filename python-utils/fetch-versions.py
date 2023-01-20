"""
Fetch and format list of versions from apkmirror.com
"""

from bs4 import BeautifulSoup
from re import compile
from sys import argv as arg
from json import load
from requests import get
import glob

versionlist=[]

def fetchurl(url):
    return BeautifulSoup(get(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 6.1; Win64; x64)'}).content, 'html.parser')

with open(glob.glob('*patches-*json')[0], "r") as patches:
            remotejson = load(patches)

try:
    if arg[1] == "YouTube":
        for json in remotejson:
            if json['name'] == 'hide-create-button':
                supportedvers = (((json['compatiblePackages'])[0])['versions'])

        for a in fetchurl("https://www.apkmirror.com/uploads/?appcategory=youtube").find_all(text = compile(".*variants")):
            appver = ((a.parent).parent).parent.find(["a"], class_="fontBlack").string

            if appver.replace("YouTube ", "") in supportedvers:
                print(appver.replace("YouTube ", "") + " [Supported]")
            else:
                print(appver.replace("YouTube ", "").replace(" beta", " [Beta]"))


    elif arg[1] == "YTMusic":
        for json in remotejson:
            if json['name'] == 'background-play':
                supportedvers = (((json['compatiblePackages'])[0])['versions'])

        for a in fetchurl("https://www.apkmirror.com/uploads/?appcategory=youtube-music").find_all(text = compile(".*variants")):
            appver = ((a.parent).parent).parent.find(["a"], class_="fontBlack").string

            if appver.replace("YouTube Music ", "") in supportedvers:
                print(appver.replace("YouTube Music ", "") + " [Supported]")
            else:
                print(appver.replace("YouTube Music ", ""))


    elif arg[1] == "Twitter":
        for a in fetchurl("https://www.apkmirror.com/uploads/?appcategory=twitter").find_all(text = compile(".*variants")):
            appver = ((a.parent).parent).parent.find(["a"], class_="fontBlack").string
            print(appver.replace("Twitter ", ""))


    elif arg[1] == "Reddit":
        for json in remotejson:
            if json['name'] == 'general-reddit-ads':
                supportedvers = (((json['compatiblePackages'])[0])['versions'])
                
        for a in fetchurl("https://www.apkmirror.com/uploads/?appcategory=reddit").find_all(text = compile(".*variants")):
            appver = ((a.parent).parent).parent.find(["a"], class_="fontBlack").string

            if appver.replace("Reddit ", "") in supportedvers:
                print(appver.replace("Reddit ", "") + " [Supported]")
            else:
                print(appver.replace("Reddit ", ""))


    elif arg[1] == "TikTok":
        for a in fetchurl("https://www.apkmirror.com/uploads/?appcategory=tik-tok").find_all(text = compile(".*variants")):
            appver = ((a.parent).parent).parent.find(["a"], class_="fontBlack")
            print(appver.string.replace("TikTok ", ""))


    elif arg[1] == "Twitch":
        for a in fetchurl("https://www.apkmirror.com/uploads/?appcategory=twitch").find_all(text = compile(".*variants")):
            appver = ((a.parent).parent).parent.find(["a"], class_="fontBlack").string
            print(appver.replace("Twitch: Live Game Streaming ", "").replace("_BETA", " [Beta]"))


except Exception as e:
    print("error")
