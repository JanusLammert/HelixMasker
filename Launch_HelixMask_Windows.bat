@echo off
:: HelixMask — Windows Launcher
:: Double-click this file to start HelixMask in your browser.
:: On first run it will create the conda/mamba environment automatically.

title HelixMask — Cryo-EM Masking Tool
cls
echo.
echo  +================================================+
echo  ^|      HelixMask -- Cryo-EM Masking Tool        ^|
echo  +================================================+
echo.

set ENV_NAME=helixmask
set PORT=5173
set APPDIR=%~dp0

:: ── Find conda / mamba ──────────────────────────────────────
set CONDA_EXE=

for %%C in (
    "%USERPROFILE%\mambaforge\Scripts\mamba.exe"
    "%USERPROFILE%\miniforge3\Scripts\mamba.exe"
    "%USERPROFILE%\Miniforge3\Scripts\mamba.exe"
    "%USERPROFILE%\anaconda3\Scripts\conda.exe"
    "%USERPROFILE%\miniconda3\Scripts\conda.exe"
    "%ProgramData%\mambaforge\Scripts\mamba.exe"
    "%ProgramData%\miniforge3\Scripts\mamba.exe"
    "%ProgramData%\Miniforge3\Scripts\mamba.exe"
    "%ProgramData%\anaconda3\Scripts\conda.exe"
    "%ProgramData%\miniconda3\Scripts\conda.exe"
) do (
    if exist %%C (
        set CONDA_EXE=%%~C
        goto :found_conda
    )
)

:: Try PATH
where mamba >nul 2>&1 && set CONDA_EXE=mamba && goto :found_conda
where conda >nul 2>&1 && set CONDA_EXE=conda && goto :found_conda

echo  ERROR: Could not find conda, mamba, or micromamba.
echo.
echo  Please install Miniforge (recommended):
echo  https://github.com/conda-forge/miniforge/releases/latest
echo.
echo  Or run manually in a terminal:
echo    pip install -r requirements.txt
echo    python app.py
echo.
pause
exit /b 1

:found_conda
echo  Found: %CONDA_EXE%

:: ── Initialise conda ────────────────────────────────────────
call "%~dp0..\condabin\conda.bat" activate 2>nul
for %%F in ("%CONDA_EXE%") do call "%%~dpFactivate.bat" 2>nul

:: ── Create environment if needed ────────────────────────────
%CONDA_EXE% env list 2>nul | findstr /B "%ENV_NAME%" >nul
if errorlevel 1 (
    echo.
    echo  Creating '%ENV_NAME%' environment (first run only, ~1-2 min)...
    %CONDA_EXE% env create -f "%APPDIR%environment.yml" -y
    if errorlevel 1 (
        echo.
        echo  ERROR: Environment creation failed.
        pause
        exit /b 1
    )
    echo  Environment created successfully.
)

:: ── Check port ──────────────────────────────────────────────
netstat -an 2>nul | findstr ":%PORT% " | findstr "LISTENING" >nul
if not errorlevel 1 (
    echo  Port %PORT% is already in use -- opening existing session.
    start "" "http://localhost:%PORT%"
    pause
    exit /b 0
)

:: ── Launch ──────────────────────────────────────────────────
echo.
echo  Starting HelixMask on http://localhost:%PORT%
echo  (Close this window to stop the server)
echo.

:: Open browser after 2s
start "" /min cmd /c "timeout /t 2 /nobreak >nul && start http://localhost:%PORT%"

%CONDA_EXE% run -n %ENV_NAME% python "%APPDIR%app.py"

echo.
echo  Server stopped.
pause
