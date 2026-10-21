@echo off
title Anti-GDl32
rem Starts the cleaner; the script asks for Administrator rights (UAC) by itself.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Anti-GDl32.ps1"
