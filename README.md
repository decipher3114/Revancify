# Revancify 🛠️ ![Hi](https://img.shields.io/github/stars/decipher3114/Revancify?style=flat-square)
### A TUI wrapper for Revanced CLI with amazing features.

[![TelegramChannel](https://img.shields.io/badge/Telegram_Channel-2CA5E0?style=for-the-badge&logo=Telegram&logoColor=FFFFFF)](https://t.me/revancify) [![TelegramChannel](https://img.shields.io/badge/Telegram_Support_Chat-2CA5E0?style=for-the-badge&logo=Telegram&logoColor=FFFFFF)](https://t.me/revancifychat)

## Termux
| Android Version | Download Link|
| ---- | ----- |
| Android 8+ | [Termux Monet](https://github.com/HardcodedCat/termux-monet/releases/latest) (Strictly Recommended)
| Android 4+ | [Termux](https://github.com/termux/termux-app/releases/latest)

# Features
1. Auto updates Patches and CLI
2. Interactive and Easy to use
3. Inbuilt scrapper for [ApkMirror](https://apkmirror.com)
    > Only support apps available on apkmirror. However, you can still download app manually and use the apk file to patch
4. Contains User-friendly Patch-options Editor
5. Conserve selected patches
6. Supports App Version downgrade for devices with Signature Spoof enabled
7. Convenient Installation and usage
6. Lightweight and faster than any other tool

# Guide

[![VideoGuide](https://img.shields.io/badge/Video_Guide_(Telegram_Channel)-2CA5E0?style=for-the-badge&logo=Telegram&logoColor=FFFFFF)](https://t.me/revancify/422)


## Installation
1. Open Termux.  
2. Copy and paste this command.  
```
curl -sL "https://raw.githubusercontent.com/decipher3114/Revancify/main/install.sh" | bash
```

<details>
  <summary>If the above one doesn't work, use this.</summary>

  ```
pkg update -y -o Dpkg::Options::="--force-confnew" && pkg install git -y && git clone --depth=1 https://github.com/decipher3114/Revancify.git && ./Revancify/revancify
```
</details>

## Usage
After installation, type `revancify` in termux and press enter.  

Or use with arguments. Check them with `revancify -h` or `revancify --help`

# Thanks & Credits
[Revanced](https://github.com/revanced)  
[Revanced Extended](https://github.com/inotia00)  
