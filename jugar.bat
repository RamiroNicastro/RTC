@echo off
rem Abre el juego directamente, sin pasar por el editor de Godot.
rem Sirve cuando el editor quedó desactualizado y el juego no arranca (pantalla gris).
set GODOT=%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe
if not exist "%GODOT%" (
	echo No encuentro Godot en: %GODOT%
	echo Edita este archivo y corregi la ruta de GODOT.
	pause
	exit /b 1
)
start "" "%GODOT%" --path "%~dp0"
