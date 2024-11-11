#!/usr/bin/bash
[ -z "$TERMUX_VERSION" ] && echo -e "Termux not detected !!" && exit 1
BIN="$PREFIX/bin/revancify"
curl -sL "https://raw.githubusercontent.com/decipher3114/Revancify/main/revancify" -O "$BIN"
[ -e "$BIN" ] && chmod +x "$BIN" && "$BIN"