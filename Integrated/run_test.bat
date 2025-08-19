@echo off
cd /d "%~dp0"
matlab -nosplash -nodesktop -r "try; run_drl_experiment; catch ME; fprintf('Error: %s\n', ME.message); end" -wait
pause
