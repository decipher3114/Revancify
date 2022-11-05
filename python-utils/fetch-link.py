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

    if argv[1] == "YouTube":

        appurl = f'https://www.apkmirror.com/apk/google-inc/youtube/youtube-{argv[2].replace(".","-")}-release/'

        apppage1= f"https://apkmirror.com{fetchurl(appurl).find(['span'], text='APK').parent.find(['a'], class_='accent_color')['href']}"


    elif argv[1] == "YTMusic":

        appurl = f'https://www.apkmirror.com/apk/google-inc/youtube-music/youtube-music-{argv[2].replace(".","-")}-release/'

        if argv[3] == "arm64":

            apppage1 = f"https://www.apkmirror.com{fetchurl(appurl).find(['div'], text='arm64-v8a').parent.find(['a'], class_='accent_color')['href']}"
        
        elif argv[3] == "armeabi":

            apppage1 = f"https://www.apkmirror.com{fetchurl(appurl).find(['div'], text='armeabi-v7a').parent.find(['a'], class_='accent_color')['href']}"


    elif argv[1] == "Twitter":

        appurl = f'https://www.apkmirror.com/apk/twitter-inc/twitter/twitter-{argv[2].replace(".","-")}-release/'

        apppage1= f"https://apkmirror.com{fetchurl(appurl).find(['span'], text='APK').parent.find(['a'], class_='accent_color')['href']}"


    elif argv[1] == "Reddit":

        appurl = f'https://www.apkmirror.com/apk/reddditinc/reddit/reddit-{argv[2].replace(".","-")}-release/'

        apppage1= f"https://apkmirror.com{fetchurl(appurl).find(['span'], text='APK').parent.find(['a'], class_='accent_color')['href']}"


    elif argv[1] == "TikTok":

        appurl = f'https://www.apkmirror.com/apk/tiktok-pte-ltd/tik-tok/tik-tok-{argv[2].replace(".","-")}-release/'

        apppage1= f"https://apkmirror.com{fetchurl(appurl).find(['span'], text='APK').parent.find(['a'], class_='accent_color')['href']}"


    print(33, flush=True)

    apppage2= f"https://apkmirror.com{fetchurl(apppage1).find(['a'], { 'class' : compile('accent_bg btn btn-flat downloadButton')})['href']}"

    print(66, flush=True)
    appdllink = f"https://apkmirror.com{fetchurl(apppage2).find(rel='nofollow')['href']}"
    print(100, flush=True)

    stderr.write(f'{appdllink}\n')
    stderr.write(get(appdllink, stream=True, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 6.1; Win64; x64)'}).headers['Content-length'])


except Exception as e:
    stderr.write("error")