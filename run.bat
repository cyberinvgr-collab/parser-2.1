@echo off
chcp 65001 >nul
rem ============================================================
rem  Запуск: Транспортные закупки — ЕИС и ТЭК-Торг
rem
rem  Двойной щелчок по этому файлу:
rem    1) находит установленный Python 3.10+ (py-лаунчер или python в PATH);
rem    2) при первом запуске создаёт окружение .venv рядом с программой
rem       и ставит в него библиотеки из requirements.txt
rem       (requests, beautifulsoup4, openpyxl, playwright);
rem    3) запускает программу. Если она упала — окно НЕ закроется,
rem       ошибка останется на экране (и запишется в error.log).
rem ============================================================
setlocal EnableExtensions DisableDelayedExpansion
title Транспортные закупки — ЕИС и ТЭК-Торг
cd /d "%~dp0"

set "VENV_DIR=%~dp0.venv"
set "VENV_PY=%VENV_DIR%\Scripts\python.exe"
set "STAMP=%VENV_DIR%\requirements.installed"
set "PY_CMD="
set "PIP_USER="

rem --- 1. Ищем Python 3.10+: сначала py-лаунчер, затем python в PATH ------
where py >nul 2>nul
if not errorlevel 1 (
    py -3 -c "import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)" >nul 2>nul
    if not errorlevel 1 set "PY_CMD=py -3"
)
if not defined PY_CMD (
    where python >nul 2>nul
    if not errorlevel 1 (
        python -c "import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)" >nul 2>nul
        if not errorlevel 1 set "PY_CMD=python"
    )
)
if not defined PY_CMD goto :no_python

rem --- 2. Проверяем, что в этом Python есть Tkinter -------------------------
%PY_CMD% -c "import tkinter" >nul 2>nul
if errorlevel 1 goto :no_tkinter

rem --- 3. Окружение .venv (создаётся при первом запуске) --------------------
if exist "%VENV_PY%" (
    "%VENV_PY%" -c "import sys" >nul 2>nul
    if errorlevel 1 (
        echo  Окружение .venv повреждено ^(например, после переустановки Python^). Пересоздаю...
        rmdir /s /q "%VENV_DIR%" >nul 2>nul
    )
)
if not exist "%VENV_PY%" (
    echo  Первый запуск: создаю окружение .venv ...
    %PY_CMD% -m venv "%VENV_DIR%"
)
if exist "%VENV_PY%" (
    set RUN_PY="%VENV_PY%"
) else (
    echo.
    echo  [ПРЕДУПРЕЖДЕНИЕ] Не удалось создать .venv. Библиотеки будут установлены
    echo  в профиль пользователя ^(pip install --user^).
    echo.
    set RUN_PY=%PY_CMD%
    set "PIP_USER=--user"
    set "STAMP=%~dp0.requirements.installed"
)

rem --- 4. Библиотеки: ставим, если их нет или requirements.txt изменился ----
set "NEED_INSTALL=0"
if not exist "%STAMP%" (
    set "NEED_INSTALL=1"
) else (
    fc /b requirements.txt "%STAMP%" >nul 2>nul
    if errorlevel 1 set "NEED_INSTALL=1"
)
%RUN_PY% -c "import requests, bs4, openpyxl, playwright.sync_api" >nul 2>nul
if errorlevel 1 set "NEED_INSTALL=1"
if "%NEED_INSTALL%"=="1" call :install_deps
if errorlevel 1 exit /b 1

rem --- 5. Запуск ------------------------------------------------------------
echo  Запускаю программу...
%RUN_PY% transport_tenders_parser.py
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
    echo.
    echo  Программа завершилась с ошибкой ^(код %RC%^). Текст ошибки выше.
    echo  Подробный журнал: %LOCALAPPDATA%\TransportTenderParser\error.log
    echo.
    pause
)
endlocal & exit /b %RC%


:install_deps
echo  Устанавливаю библиотеки из requirements.txt ^(нужен Интернет, 1-3 минуты^) ...
%RUN_PY% -m pip install %PIP_USER% --upgrade pip >nul 2>nul
%RUN_PY% -m pip install %PIP_USER% -r requirements.txt
if errorlevel 1 (
    echo.
    echo  Повторяю установку ^(бывают временные сбои сети^)...
    %RUN_PY% -m pip install %PIP_USER% -r requirements.txt
)
if errorlevel 1 (
    echo.
    echo  [ОШИБКА] Не удалось установить библиотеки.
    echo  Проверьте подключение к Интернету / настройки прокси и повторите запуск.
    echo  Если в сети используется прокси, задайте переменную HTTPS_PROXY, например:
    echo      set HTTPS_PROXY=http://proxy.company.ru:3128
    echo.
    pause
    exit /b 1
)
rem Контрольная проверка: все модули должны импортироваться.
%RUN_PY% -c "import requests, bs4, openpyxl, playwright.sync_api" >nul 2>nul
if errorlevel 1 (
    echo.
    echo  [ОШИБКА] Библиотеки установлены, но не импортируются. Удалите папку .venv
    echo  и запустите run.bat снова. Подробности: %LOCALAPPDATA%\TransportTenderParser\error.log
    echo.
    pause
    exit /b 1
)
copy /y requirements.txt "%STAMP%" >nul
echo  Библиотеки установлены: requests, beautifulsoup4, openpyxl, playwright.
echo  Браузер для ТЭК-Торг отдельно не нужен: используется Яндекс Браузер / Edge / Chrome.
exit /b 0


:no_python
echo.
echo  [ОШИБКА] Не найден Python 3.10 или новее.
echo.
echo  Установите Python с сайта  https://www.python.org/downloads/windows/
echo  В установщике обязательно отметьте:
echo     [x] Add python.exe to PATH
echo     [x] tcl/tk and IDLE   ^(вкладка Optional Features, включено по умолчанию^)
echo  После установки запустите run.bat ещё раз.
echo.
echo  Если Python установлен из Microsoft Store и всё равно не находится -
echo  удалите его и поставьте версию с python.org.
echo.
pause
exit /b 1


:no_tkinter
echo.
echo  [ОШИБКА] В установленном Python нет Tkinter ^(оконная библиотека^).
echo  Запустите установщик Python повторно -^> Modify -^> отметьте "tcl/tk and IDLE".
echo.
pause
exit /b 1
