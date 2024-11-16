# Revancify 🛠️
### A TUI wrapper for Revanced CLI with amazing features.

[![TelegramChannel](https://img.shields.io/badge/Telegram_Support_Chat-2CA5E0?style=for-the-badge&logo=Telegram&logoColor=FFFFFF)](https://t.me/revancifychat)

> #### Revancify v1 will be deprecated once Revanced Extended bring support for `.rvp` patches.  
> ReVanced has changed the patches format to `.rvp` in v5.  
> For patching apps with **ReVanced** patches, check [**Revancify v2**](https://github.com/decipher3114/Revancify/tree/bump/v2.0)

## Termux

<table>
  <tr>
    <td colspan="2">Download Link</td>
  </tr>
  <tr>
    <td><a href="https://github.com/termux/termux-app/releases/latest">GitHub</a></td>
    <td><a href="https://play.google.com/store/apps/details?id=com.termux">PlayStore</a></td>
  </tr>
</table>


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

## Installation
> Clear Termux data and delete Revancify folder from Storage, if coming back from **Revancify v2**.
1. Download and Install [Termux](#termux).
2. Open Termux.
3. Copy and paste this command.
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
