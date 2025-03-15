#!/usr/bin/bash
[ -z "$TERMUX_VERSION" ] && echo -e "Termux not detected !!" && exit 1
BIN="$PREFIX/bin/revancify"
curl -sL "https://github.com/decipher3114/Revancify/raw/refs/heads/main/revancify" -o "$BIN"
[ -e "$BIN" ] && chmod +x "$BIN" && "$BIN"
