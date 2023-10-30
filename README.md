# Revancify 🛠️
### A TUI wrapper for Revanced CLI with amazing features.

## Termux
| Android Version | Download Link|
| ---- | ----- |
| Android 8+ | [Termux Monet](https://github.com/HardcodedCat/termux-monet/releases/latest) (Strictly Recommended)
| Android 4+ | [Termux](https://github.com/termux/termux-app/releases/latest)

<details><summary><big>Features</big></summary>
1. Auto updates Patches and CLI
2. Interactive and Easy to use
3. Inbuilt scrapper for [ApkMirror](https://apkmirror.com)
    > Only support apps available on apkmirror. However, you can still download app manually and use the apk file to patch
4. Contains User-friendly Patch-options Editor
5. Conserve selected patches
6. Supports App Version downgrade for devices with Signature Spoof enabled
7. Convenient Installation and usage
6. Lightweight and faster than any other tool
</details>

# Guide

## Installation
1. Open Termux.  
2. Copy and paste this command.  
```
curl -sL "https://raw.githubusercontent.com/cvnertnc/Revancify/main/install.sh" | bash
```

<details>
  <summary>If the above one doesn't work, use this.</summary>

  ```
pkg update -y -o Dpkg::Options::="--force-confnew" && pkg install git -y && git clone --depth=1 https://github.com/cvnertnc/Revancify.git && ./Revancify/revancify
```
</details>

## Usage
After installation, type `revancify` in termux and press enter.  

Or use with arguments. Check them with `revancify -h` or `revancify --help`

# Thanks & Credits
[Revanced](https://github.com/revanced)  
[Revanced Extended](https://github.com/inotia00)  
