@echo off
echo ========================================
echo Microgrid DRL Framework - Main Launcher
echo ========================================
echo.

REM Get directories
set "PROJECT_DIR=%~dp0"
set "MAIN_DIR=%PROJECT_DIR%main"

echo Project Directory: %PROJECT_DIR%
echo Main Directory: %MAIN_DIR%
echo.

REM Check main directory
if not exist "%MAIN_DIR%" (
    echo ERROR: main directory not found
    echo Please ensure script is run from project root directory
    echo.
    echo Current directory contents:
    dir "%PROJECT_DIR%" /b
    pause
    exit /b 1
)

REM Check Simulink model
if not exist "%MAIN_DIR%\simulinkmodel\Microgrid.slx" (
    echo ERROR: Microgrid.slx file not found in simulinkmodel folder
    echo Please ensure Simulink model file exists at: %MAIN_DIR%\simulinkmodel\Microgrid.slx
    pause
    exit /b 1
)

echo Files check passed!
echo.

echo Choose operation:
echo.
echo === Troubleshooting ===
echo 0. Fix Model (solve Simulink issues)
echo.
echo === Quick Start ===
echo 1. Quick Test (verify functionality)
echo 2. Quick Training (5 episodes, ~3 min)
echo.
echo === High-Performance 30-Day Physical Simulation ===
echo 3. 30-Day GPU Simulation (1000 episodes, 30 days each, ~2-4 hours)
echo 4. 30-Day CPU Simulation (500 episodes, 30 days each, ~4-8 hours)
echo 5. 30-Day Analysis & Evaluation (analyze trained agents)
echo.
echo === Evaluation ===
echo 6. Evaluate Trained Agent
echo 7. Interactive MATLAB Menu
echo.
echo 8. Exit
echo.

set /p choice="Enter choice (0-8): "

REM Process choice
if "%choice%"=="0" goto fixmodel
if "%choice%"=="1" goto quicktest
if "%choice%"=="2" goto quicktrain
if "%choice%"=="3" goto gpu30day
if "%choice%"=="4" goto cpu30day
if "%choice%"=="5" goto analyze30day
if "%choice%"=="6" goto evaluate
if "%choice%"=="7" goto interactive
if "%choice%"=="8" goto exit

echo Invalid choice!
pause
exit /b 1

:fixmodel
echo.
echo === Fix Model ===
echo Running comprehensive framework fix...
echo This will automatically fix common issues:
echo - Generate and fix data variables
echo - Fix model configuration
echo - Fix variable name mismatches
echo - Fix From Workspace block settings
echo - Find and verify RL Agent blocks
echo - Test basic simulation
echo.
cd /d "%MAIN_DIR%"
matlab -r "setup_project_paths; complete_fix;"
goto end

:quicktest
echo.
echo === Quick Test ===
echo Running functionality test...
cd /d "%MAIN_DIR%"
matlab -r "setup_project_paths; addpath('../tools/matlab_scripts'); system_test;"
goto end

:quicktrain
echo.
echo === Quick Training ===
echo Starting 5-episode DDPG training test...
cd /d "%MAIN_DIR%"
matlab -r "setup_project_paths; quick_train_test;"
goto end

:gpu30day
echo.
echo === 30-Day GPU High-Performance Simulation ===
echo Starting 30-day physical world simulation with GPU acceleration...
echo This is a comprehensive training with:
echo - 30 days physical simulation per episode
echo - 1000 training episodes
echo - GPU acceleration (if available)
echo - Real-time step: 1 hour
echo - Expected duration: 2-4 hours
echo.
echo WARNING: This is a long-running process!
echo Make sure your computer can run uninterrupted for several hours.
echo.
set /p confirm="Continue with 30-day GPU simulation? (y/n): "
if /i not "%confirm%"=="y" goto end
cd /d "%MAIN_DIR%"
matlab -r "setup_project_paths; train_30day_gpu_simulation;"
goto end

:cpu30day
echo.
echo === 30-Day CPU High-Performance Simulation ===
echo Starting 30-day physical world simulation with CPU...
echo This is a comprehensive training with:
echo - 30 days physical simulation per episode
echo - 500 training episodes (reduced for CPU)
echo - CPU-only training
echo - Real-time step: 1 hour
echo - Expected duration: 4-8 hours
echo.
echo WARNING: This is a very long-running process!
echo Make sure your computer can run uninterrupted for many hours.
echo.
set /p confirm="Continue with 30-day CPU simulation? (y/n): "
if /i not "%confirm%"=="y" goto end
cd /d "%MAIN_DIR%"
matlab -r "setup_project_paths; train_30day_cpu_simulation;"
goto end

:analyze30day
echo.
echo === 30-Day Simulation Analysis & Evaluation ===
echo Analyzing and evaluating 30-day trained agents...
echo This will:
echo - Load trained 30-day agents
echo - Run comprehensive evaluation
echo - Generate performance plots
echo - Compare different training results
echo - Export analysis reports
echo.
cd /d "%MAIN_DIR%"
matlab -r "setup_project_paths; analyze_30day_results;"
goto end

:evaluate
echo.
echo === Evaluate Agent ===
echo Evaluating trained agent performance...
cd /d "%MAIN_DIR%"
matlab -r "setup_project_paths; evaluate_trained_agent;"
goto end

:interactive
echo.
echo === Interactive Menu ===
echo Starting MATLAB interactive menu...
cd /d "%MAIN_DIR%"
matlab -r "setup_project_paths; run_microgrid_framework;"
goto end

:exit
echo Goodbye!
exit /b 0

:end
echo.
echo Operation completed!
pause


