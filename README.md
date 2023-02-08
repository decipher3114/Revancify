# Revancify
A simple and direct Revanced Installer script.  
It uses Revanced CLI to build Revanced Apps.


### Note:  
Download Termux from Github or FDroid. Termux app available on playstore is not maintained.

# Installation
1. Open Termux.  
2. Copy and paste this code.  
```
pkg update -y && pkg install git -y && git clone https://github.com/decipher3114/Revancify.git && ./Revancify/revancify
```

# Usage

After installation, type `revancify` in termux and press enter.  
   
Or use with arguments  
```
revancify  
  
Usage: revancify [OPTION] 

Options:  
-n         Run revancify as non root in rooted device  
-f         Force update check for resources on startup  
-r         Reinstall revancify  
-u         Uninstall or remove revancify    
-h,--help  Prints help statement  
```  
  
# Thanks & Credits
[Revanced](https://github.com/revanced) 
## Contributors  
<a href="https://github.com/decipher3114/Revancify/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=decipher3114/Revancify" />
</a>

