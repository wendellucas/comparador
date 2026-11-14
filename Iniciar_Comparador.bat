@echo off
chcp 65001 >nul
title Comparador de Arquivos por Hash
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0ComparadorHash.ps1"
exit
