"""
Sync saved-patches from patches
"""

from json import load, dump
from sys import argv as arg
import glob

localjson = None
        
jsonfile = f'{arg[1]}-patches.json'

def openjson():
    global localjson
    try:
        with open(jsonfile, "r") as patches_file:
            localjson = load(patches_file)
    except Exception as e:
        with open(jsonfile, "w") as patches_file:
            empty_json = [{"appName": None, "versions": [], "patches": []}]
            dump(empty_json, patches_file, indent=4)
        openjson()

openjson()

with open(glob.glob(f'{arg[1]}-patches-*json')[0], "r") as patches:
    remotejson = load(patches)

apps = []
savedPatches = []

try:
    for app in localjson:
        for patch in app['patches']:
            if patch['status'] == "on":
                savedPatches.append(patch['name'])
except:
    pass

localjson = []
for key in remotejson:
    # check app
    
    try:
        appName = key['compatiblePackages'][0]['name']
    except:
        appName = "generic"

    try:
        versions = key['compatiblePackages'][0]['versions']
    except:
        versions = []

    
    patchName = key['name']
    patchDesc = key['description']

    if patchName in savedPatches:
        status = "on"
    else:
        status = "off"


    if appName not in apps:

        apps.append(appName)

        patchkey = [{"name": patchName, "description": patchDesc, "status": status}]
        localjson.append({"appName": appName, "versions": sorted(versions), "patches": patchkey})

    else:
        versions = list(set(versions))
        for app in localjson:
            if app['appName'] == appName:
                previousVersions = app['versions']

                versions = sorted(list(set(versions) | set(previousVersions)))
                patchkey = {"name": patchName, "description": patchDesc, "status": status}
                app['patches'].append(patchkey)


with open(jsonfile, "w") as patchesfile:
    dump(localjson, patchesfile, indent=4)