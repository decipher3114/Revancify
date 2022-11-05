"""
Sync saved-patches from patches
"""

from json import load, dump

localjson = None

with open('sources.json', 'r') as sourcesfile:
    sourcesjson = load(sourcesfile)

for source in sourcesjson:
    if source['sourceStatus'] == "on":
        patchesrepo = source['sourceMaintainer']

def openjson():
    global localjson
    try:
        with open("saved-patches.json", "r") as patches_file:
            localjson = load(patches_file)
    except Exception as e:
        with open("saved-patches.json", "w") as patches_file:
            empty_json = [{"patchname": None, "appname": None, "status": None}]
            dump(empty_json, patches_file, indent=4)
        openjson()

openjson()

with open("patches.json", "r") as patches:
    remotejson = load(patches)

patches = [key['name'] for key in remotejson]
saved_patches = [key['patchname'] for key in localjson]
obsoletepatches = []


for index, patchname in enumerate(patches):
    if patchname not in saved_patches:
        newkey = {}
        newkey['patchname'] = patchname
        newkey['appname'] = remotejson[index]['compatiblePackages'][0]['name']
        newkey['description'] = remotejson[index]['description']
        if remotejson[index]['excluded'] == True:
            newkey['status'] = "off"
        elif remotejson[index]['excluded'] == False:
            newkey['status'] = "on"

        localjson.append(newkey)
    else:
        patchindex = saved_patches.index(patchname)
        localjson[patchindex]['patchname'] = remotejson[index]['name']
        localjson[patchindex]['description'] = remotejson[index]['description']
        localjson[patchindex]['appname'] = remotejson[index]['compatiblePackages'][0]['name']

obsoletepatches = [ index for index, patchname in enumerate(saved_patches) if patchname not in patches]

for index in sorted(obsoletepatches, reverse=True):
    del localjson[index]

with open("saved-patches.json", "w") as patchesfile:
    dump(localjson, patchesfile, indent=4)