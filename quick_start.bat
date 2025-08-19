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

REM Check Simulink model - CRITICAL requirement
if not exist "%MAIN_DIR%\simulinkmodel\Microgrid.slx" (
    echo.
    echo ========================================
    echo CRITICAL ERROR: Simulink Model Not Found
    echo ========================================
    echo.
    echo The Simulink model is REQUIRED for DRL training.
    echo Expected location: %MAIN_DIR%\simulinkmodel\Microgrid.slx
    echo.
    echo Without the Simulink model:
    echo - DRL training CANNOT proceed
    echo - The system cannot simulate the microgrid environment
    echo.
    echo Please ensure:
    echo 1. The Simulink model file exists
    echo 2. The file is not corrupted
    echo 3. You have proper access permissions
    echo.
    echo Training will be DISABLED until the model is available.
    echo ========================================
    echo.
    pause
    exit /b 1
)

echo Simulink model check: PASSED
echo.

:menu
echo Choose operation:
echo.
echo === System Check ===
echo 0. Check Simulink Model Status
echo.
echo === Quick Start ===
echo 1. Quick Test (verify functionality)
echo 2. Quick Training (5 episodes, ~3 min)
echo.
echo === Configurable DRL Training ===
echo 3. Quick Training (1 day, 5 episodes, ~5 minutes)
echo 4. Default Training (7 days, 50 episodes, ~30 minutes)
echo 5. Research Training (30 days, 100 episodes, ~2 hours)
echo 6. Extended Training (90 days, 500 episodes, ~1 day)
echo 7. Algorithm Comparison (DDPG vs TD3 vs SAC)
echo.
echo === Analysis and Evaluation ===
echo 8. Analyze DRL Results
echo 9. Run Interactive MATLAB Menu
echo.
echo 10. Exit
echo.

set /p choice="Enter choice (0-10): "

REM Process choice
if "%choice%"=="0" goto checkmodel
if "%choice%"=="1" goto quicktest
if "%choice%"=="2" goto quicktrain
if "%choice%"=="3" goto quicktrain
if "%choice%"=="4" goto defaulttrain
if "%choice%"=="5" goto researchtrain
if "%choice%"=="6" goto extendedtrain
if "%choice%"=="7" goto comparison
if "%choice%"=="8" goto analyze
if "%choice%"=="9" goto interactive
if "%choice%"=="10" goto exit

echo Invalid choice!
pause
goto menu

:checkmodel
echo.
echo === Check Simulink Model Status ===
echo Checking if Simulink model exists and is valid...
echo.
cd /d "%MAIN_DIR%"
matlab -r "setup_project_paths; try; load_system('simulinkmodel/Microgrid.slx'); fprintf('Simulink model loaded successfully\n'); close_system('simulinkmodel/Microgrid.slx', 0); catch ME; fprintf('Error loading model: %s\n', ME.message); end; pause(5); exit;"
echo.
echo If the model is missing, training cannot proceed.
echo Please ensure Microgrid.slx exists in simulinkmodel folder.
echo.
pause
goto menu

:quicktest
echo.
echo === Quick Test ===
echo Checking Simulink model before test...
if not exist "%MAIN_DIR%\simulinkmodel\Microgrid.slx" (
    echo ERROR: Cannot run test - Simulink model not found!
    echo Please ensure Microgrid.slx exists before testing.
    pause
    goto menu
)
echo Running functionality test...
cd /d "%MAIN_DIR%"
matlab -r "setup_project_paths; try; fprintf('Testing core functionality...\n'); load_workspace_data; fprintf('Data loading: OK\n'); fprintf('System test completed successfully\n'); catch ME; fprintf('Test failed: %s\n', ME.message); end; pause(5); exit;"
goto end

:quicktrain
echo.
echo === Quick Training ===
echo Checking Simulink model before training...
if not exist "%MAIN_DIR%\simulinkmodel\Microgrid.slx" (
    echo.
    echo ERROR: Cannot start training - Simulink model not found!
    echo The Simulink model is REQUIRED for DRL training.
    echo Please ensure Microgrid.slx exists in simulinkmodel folder.
    echo.
    pause
    goto menu
)
echo Model check passed. Proceeding with training setup...
echo.
echo Configuration: 1 day, 5 episodes (~5 minutes)
echo Perfect for testing and quick validation
echo.
echo Choose algorithm:
echo 1. DDPG (baseline)
echo 2. TD3 (improved stability)
echo 3. SAC (maximum entropy)
set /p alg="Enter algorithm choice (1-3): "
if "%alg%"=="1" set algorithm=ddpg
if "%alg%"=="2" set algorithm=td3
if "%alg%"=="3" set algorithm=sac
if not defined algorithm set algorithm=ddpg
echo.
set /p confirm="Start quick %algorithm% training? (y/n): "
if /i not "%confirm%"=="y" goto menu
cd /d "%MAIN_DIR%"
matlab -r "setup_project_paths; run_quick_training('%algorithm%');"
goto menu

:defaulttrain
echo.
echo === Default Training ===
echo Configuration: 7 days, 50 episodes (~30 minutes)
echo Balanced configuration for regular use
echo.
echo Choose algorithm:
echo 1. DDPG (baseline)
echo 2. TD3 (improved stability)
echo 3. SAC (maximum entropy)
set /p alg="Enter algorithm choice (1-3): "
if "%alg%"=="1" set algorithm=ddpg
if "%alg%"=="2" set algorithm=td3
if "%alg%"=="3" set algorithm=sac
if not defined algorithm set algorithm=ddpg
echo.
set /p confirm="Start default %algorithm% training? (y/n): "
if /i not "%confirm%"=="y" goto menu
cd /d "%MAIN_DIR%"
matlab -r "setup_project_paths; train_microgrid_drl('default', '%algorithm%');"
goto menu

:researchtrain
echo.
echo === Research Training ===
echo Configuration: 30 days, 100 episodes (~2 hours)
echo Research-grade configuration for publications
echo.
echo Choose algorithm:
echo 1. DDPG (baseline)
echo 2. TD3 (improved stability)
echo 3. SAC (maximum entropy)
set /p alg="Enter algorithm choice (1-3): "
if "%alg%"=="1" set algorithm=ddpg
if "%alg%"=="2" set algorithm=td3
if "%alg%"=="3" set algorithm=sac
if not defined algorithm set algorithm=ddpg
echo.
set /p confirm="Start research %algorithm% training? (y/n): "
if /i not "%confirm%"=="y" goto menu
cd /d "%MAIN_DIR%"
matlab -r "setup_project_paths; train_microgrid_drl('research', '%algorithm%');"
goto menu

:extendedtrain
echo.
echo === Extended Training ===
echo Configuration: 90 days, 500 episodes (~1 day)
echo Extended configuration for comprehensive analysis
echo.
echo Choose algorithm:
echo 1. DDPG (baseline)
echo 2. TD3 (improved stability)
echo 3. SAC (maximum entropy)
set /p alg="Enter algorithm choice (1-3): "
if "%alg%"=="1" set algorithm=ddpg
if "%alg%"=="2" set algorithm=td3
if "%alg%"=="3" set algorithm=sac
if not defined algorithm set algorithm=ddpg
echo.
set /p confirm="Start extended %algorithm% training? (y/n): "
if /i not "%confirm%"=="y" goto menu
cd /d "%MAIN_DIR%"
matlab -r "setup_project_paths; train_microgrid_drl('extended', '%algorithm%');"
goto menu

:comparison
echo.
echo === Algorithm Comparison ===
echo This will train all three algorithms with research configuration
echo for comprehensive performance comparison.
echo.
echo Algorithms to train:
echo 1. DDPG (Deep Deterministic Policy Gradient)
echo 2. TD3 (Twin Delayed DDPG)
echo 3. SAC (Soft Actor-Critic)
echo.
echo Total estimated time: 6-8 hours
set /p confirm="Continue with algorithm comparison? (y/n): "
if /i not "%confirm%"=="y" goto menu
cd /d "%MAIN_DIR%"
echo Starting DDPG training...
matlab -r "setup_project_paths; train_microgrid_drl('comparison', 'ddpg');"
echo Starting TD3 training...
matlab -r "setup_project_paths; train_microgrid_drl('comparison', 'td3');"
echo Starting SAC training...
matlab -r "setup_project_paths; train_microgrid_drl('comparison', 'sac');"
echo All algorithms training completed!
goto menu

:analyze
echo.
echo === Results Analysis ===
echo Analyzing training results and agent performance...
echo This will:
echo - Load all available training results
echo - Analyze performance metrics
echo - Generate comparison plots
echo - Provide performance recommendations
echo.
set /p confirm="Continue with analysis? (y/n): "
if /i not "%confirm%"=="y" goto menu
cd /d "%MAIN_DIR%"
matlab -r "setup_project_paths; analyze_results('all');"
goto menu

:compare
echo.
echo === Algorithm Performance Comparison ===
echo Comparing performance of different DRL algorithms...
echo This will:
echo - Compare DDPG, TD3, and SAC performance
echo - Generate comparative analysis
echo - Create performance comparison plots
echo - Provide algorithm selection recommendations
echo.
set /p confirm="Continue with comparison? (y/n): "
if /i not "%confirm%"=="y" goto end
cd /d "%MAIN_DIR%"
matlab -r "setup_project_paths; compare_algorithms;"
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
matlab -r "setup_project_paths; run_scientific_drl_menu;"
goto end

:exit
echo Goodbye!
exit /b 0

:end
echo.
echo Operation completed!
pause


