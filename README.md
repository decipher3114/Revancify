# Revancify
A simple and direct Revanced Installer script.  
It uses Revanced CLI to build Revanced Apps.

Apps Supported:
1. YouTube
2. YouTube Music
3. Twitter
4. Reddit
5. TikTok


### Note:  
Download Termux from their github or FDroid

# Installation
1. Open Termux.  
2. Copy and paste this code.  
```
termux-setup-storage && pkg update -y && pkg install git -y && cd storage && git clone https://github.com/decipher3114/Revancify && cd Revancify && bash revancify
```
### Dependencies:  
**packages**: python, openjdk-17, wget, ncurses-utils, jq  
**python modules**: requests, wheel, bs4  

# Usage
1. Open Termux.  
2. Type `revancify`  


# Support

For help and support, Join [Telegram Channel](https://t.me/revancify)  

# Troubleshoot

## Command 1: 
Use this command in case of any fatal error
```
cd storage/Revancify && git checkout .; git pull
```  
## Command 2:  
if command 1 fails, use this command, this will delete and reinitialize the repo.
```
cd storage && rm -rf Revancify && rm ~/../usr/bin/revancify && git clone https://github.com/decipher3114/Revancify && cd Revancify && bash revancify
```
# Uninstallation
1. Open Termux.  
2. Type `rm -rf ~/storage/Revancify && rm ~/../usr/bin/revancify`   

# Thanks & Credits
[Revanced](https://github.com/revanced) 
## Contributors  
<a href="https://github.com/decipher3114/Revancify/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=decipher3114/Revancify" />
</a>

