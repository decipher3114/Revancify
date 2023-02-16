from requests import post
from json import load, dump
from sys import argv
import glob
from re import sub
        
jsonFile = f'{argv[1]}-patches.json'

try:
    with open(jsonFile, "r") as patchesFile:
        localJson = load(patchesFile)
except Exception as e:
    localJson = {"appName": None, "link": None, "versions": [], "patches": []}


with open(glob.glob(f'{argv[1]}-patches-*json')[0], "r") as patches:
    remotejson = load(patches)

pkgs = []
savedPatches = []
appNames = {}

try:
    for app in localJson:
        for patch in localJson[app]['patches']:
            if patch['status'] == "on":
                savedPatches.append(f"{patch['name']}({app})")
            appNames[app] = {"appName": localJson[app]['appName'], "appLink": localJson[app]['link']}
except:
    pass


localJson = {}
generic = []

for key in remotejson:

    if len(key['compatiblePackages']) != 0:
        for pkg in key['compatiblePackages']:
            pkgName = pkg['name']

            try:
                versions = key['compatiblePackages'][0]['versions']
            except:
                versions = []

            
            patchName = key['name']
            patchDesc = key['description']
            

            if f"{patchName}({pkgName})" in savedPatches or not key['excluded']:
                status = "on"
            else:
                status = "off"

            if pkgName not in pkgs:
                pkgs.append(pkgName)
                try:
                    appName = appNames[pkgName]['appName']
                    link = appNames[pkgName]['appLink']
                except:
                    appName = None
                    link = None
                localJson[pkgName] = {"appName": appName, "link": link, "versions": [], "patches": []}

            previousVersions = localJson[pkgName]['versions']

            localJson[pkgName]['versions'] = sorted(list(set(versions) | set(previousVersions)))

            patchkey = {"name": patchName, "description": patchDesc, "status": status, "excluded": key['excluded']}
            localJson[pkgName]['patches'].append(patchkey)
    else:
        generic.append({"name": key['name'], "description": key['description'], "status": "off", "excluded": key['excluded']})

for app in localJson:
    for key in generic:
        patch = key.copy()
        if f"{key['name']}({app})" in savedPatches:
            patch['status'] = "on"
            localJson[app]['patches'].append(patch)
        else:
            patch['status'] = "off"
            localJson[app]['patches'].append(patch)

try:
    fetchType = argv[2]
except:
    fetchType = None

if fetchType == "online":
    try:
        headers = {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                'Authorization': 'Basic YXBpLXRvb2xib3gtZm9yLWdvb2dsZS1wbGF5OkNiVVcgQVVMZyBNRVJXIHU4M3IgS0s0SCBEbmJL',
                'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.5414.86 Mobile Safari/537.36'
            }

        body = {"pnames": pkgs}

        response = post('https://www.apkmirror.com/wp-json/apkm/v1/app_exists/',json=body , headers=headers)

        apps = []

        for data in response.json()['data']:
            if data['exists']:
                appName = sub(" \(.*\)", '', data['app']['name']).replace("&amp;", "&")
                localJson[data['pname']]['appName'] = sub('[^0-9a-zA-Z]+', '-', appName)
                localJson[data['pname']]['link'] = data['app']['link'].replace("-wear-os","")
    except:
        print("error")


with open(jsonFile, "w") as patchesfile:
    dump(localJson, patchesfile, indent = 4)