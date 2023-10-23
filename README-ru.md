<a href="https://github.com/decipher3114/Revancify">English</a>
&nbsp;&nbsp;| &nbsp;&nbsp;
Русский

# Revancify 🛠️
### Оболочка TUI для Revanced CLI с невероятными возможностями.

[![TelegramChannel](https://img.shields.io/badge/Telegram_Support_Chat-2CA5E0?style=for-the-badge&logo=Telegram&logoColor=FFFFFF)](https://t.me/revancifychat)

## Termux
| Версия Android | Ссылка на скачивание|
| ---- | ----- |
| Android 8+ | [Termux Monet](https://github.com/HardcodedCat/termux-monet/releases/latest) (Строго рекомендовано)
| Android 4+ | [Termux](https://github.com/termux/termux-app/releases/latest)

# Возможности
1. Автоматически обновляет патчи и CLI
2. Интерактивный и простой в использовании
3. Встроенный выниматель для [ApkMirror](https://apkmirror.com)
    > Поддерживает только приложения, которые доступны на apkmirror. Также вы можете использовать apk файл, скаченный вами для патчинга
4. Содержит простой в использовании редактор опций патчей
5. Сохраняет набор выбранных патчей
6. Поддерживает установку более старой версии для устройств с включенной подменой сигнатуры
7. Удобная установка и использование
6. Легче и быстрее любого другого инструмента

# Гайд

## Установка
1. Откройте Termux.  
2. Скопируйте и вставьте эту команду.  
```
curl -sL "https://raw.githubusercontent.com/decipher3114/Revancify/main/install.sh" | bash
```

<details>
  <summary>Если команда выше не работает, пользуйтесь этой.</summary>

  ```
pkg update -y -o Dpkg::Options::="--force-confnew" && pkg install git -y && git clone --depth=1 https://github.com/decipher3114/Revancify.git && ./Revancify/revancify
```
</details>

## Использование
Вводите `revancify` в termux после установки и нажмите enter.  

Или используйте с аргументами. Вы можете увидеть их, введя `revancify -h` или `revancify --help`

# Благодарности & Уважение
[Revanced](https://github.com/revanced)  
[Revanced Extended](https://github.com/inotia00)  
