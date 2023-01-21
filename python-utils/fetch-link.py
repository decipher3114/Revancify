"""
Fetch the link for the app and version specified by the arguments passed.
"""

from re import compile
from sys import argv, stderr
from requests import get, Session
from bs4 import BeautifulSoup


def fetchurl(url):
    return BeautifulSoup(Session().get(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 6.1; Win64; x64)'}).content, 'html.parser')


try:

    version = argv[2].replace(".","-")

    if argv[1] == "YouTube":

        appurl = f'https://www.apkmirror.com/apk/google-inc/youtube/youtube-{version}-release/'



    elif argv[1] == "YouTube-Music":

        appurl = f'https://www.apkmirror.com/apk/google-inc/youtube-music/youtube-music-{version}-release/'



    elif argv[1] == "Twitter":

        appurl = f'https://www.apkmirror.com/apk/twitter-inc/twitter/twitter-{version}-release/'


    elif argv[1] == "Reddit":

        appurl = f'https://www.apkmirror.com/apk/reddditinc/reddit/reddit-{version}-release/'


    elif argv[1] == "TikTok":

        appurl = f'https://www.apkmirror.com/apk/tiktok-pte-ltd/tik-tok/tik-tok-{version}-release/'



    elif argv[1] == "Twitch":

        appurl = f'https://www.apkmirror.com/apk/twitch-interactive-inc/twitch/twitch-{version}-release/'



    data = fetchurl(appurl).find(['div'], class_='variants-table').find_all(['div'], text=compile(f'{argv[3]}|universal'))

    for element in data:
        if element.parent.find(['span']).string == "APK":
            appurl2 = f"https://apkmirror.com{element.parent.find(['a'], class_='accent_color')['href']}"
            break

    print(33, flush=True)

    appurl3= f"https://apkmirror.com{fetchurl(appurl2).find(['a'], { 'class' : compile('accent_bg btn btn-flat downloadButton')})['href']}"

    print(66, flush=True)
    appdllink = f"https://apkmirror.com{fetchurl(appurl3).find(rel='nofollow')['href']}"
    print(100, flush=True)

    stderr.write(f'{appdllink}\n')
    stderr.write(get(appdllink, stream=True, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 6.1; Win64; x64)'}).headers['Content-length'])

except NameError:
    stderr.write("noapk")
    exit()

except:
    stderr.write("error")