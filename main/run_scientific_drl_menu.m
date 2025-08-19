function run_scientific_drl_menu()
% RUN_SCIENTIFIC_DRL_MENU - Interactive menu for scientific DRL research
%
% This function provides a user-friendly interface for conducting scientific
% research in microgrid energy management using deep reinforcement learning.
% All configurations are designed for academic rigor and SCI publication.

clc;
fprintf('\n');
fprintf('=========================================================================\n');
fprintf('    SCIENTIFIC MICROGRID DRL RESEARCH SYSTEM\n');
fprintf('    Version 2.0 - Academic Research Edition\n');
fprintf('    Suitable for SCI Journal Publication\n');
fprintf('=========================================================================\n');

% Setup project environment
setup_project_paths();

while true
    fprintf('\n=== CONFIGURABLE DRL TRAINING ===\n');
    fprintf('3. Quick Training (1 day, 5 episodes, ~5 minutes)\n');
    fprintf('4. Default Training (7 days, 50 episodes, ~30 minutes)\n');
    fprintf('5. Research Training (30 days, 100 episodes, ~2 hours)\n');
    fprintf('6. Extended Training (90 days, 500 episodes, ~1 day)\n');
    fprintf('7. Algorithm Comparison (DDPG vs TD3 vs SAC)\n');
    fprintf('\n=== ANALYSIS AND EVALUATION ===\n');
    fprintf('8. Analyze DRL Results\n');
    fprintf('9. Run Interactive MATLAB Menu\n');
    fprintf('\n10. Exit\n');
    fprintf('\n=========================================================================\n');
    
    choice = input('Select option (3-10): ');
    
    switch choice
        case 3
            % Quick Training
            fprintf('\n=== QUICK TRAINING (1-DAY VALIDATION) ===\n');
            fprintf('Purpose: Algorithm validation and parameter testing\n');
            fprintf('Duration: ~5 minutes\n');
            algorithm = select_algorithm();
            if ~isempty(algorithm)
                try
                    [stats, agent, config] = train_microgrid_drl('quick_1day', algorithm);
                    fprintf('? Quick training completed successfully!\n');
                    save_training_results(stats, agent, config, 'quick_1day', algorithm);
                catch ME
                    fprintf('? Training failed: %s\n', ME.message);
                end
            end
            
        case 4
            % Default Training
            fprintf('\n=== DEFAULT TRAINING (7-DAY BASELINE) ===\n');
            fprintf('Purpose: Weekly pattern analysis and baseline evaluation\n');
            fprintf('Duration: ~30 minutes\n');
            algorithm = select_algorithm();
            if ~isempty(algorithm)
                try
                    [stats, agent, config] = train_microgrid_drl('default_7day', algorithm);
                    fprintf('? Default training completed successfully!\n');
                    save_training_results(stats, agent, config, 'default_7day', algorithm);
                catch ME
                    fprintf('? Training failed: %s\n', ME.message);
                end
            end
            
        case 5
            % Research Training
            fprintf('\n=== RESEARCH TRAINING (30-DAY STUDY) ===\n');
            fprintf('Purpose: Primary research configuration for academic publication\n');
            fprintf('Duration: ~2 hours\n');
            algorithm = select_algorithm();
            if ~isempty(algorithm)
                try
                    [stats, agent, config] = train_microgrid_drl('research_30day', algorithm);
                    fprintf('? Research training completed successfully!\n');
                    save_training_results(stats, agent, config, 'research_30day', algorithm);
                catch ME
                    fprintf('? Training failed: %s\n', ME.message);
                end
            end
            
        case 6
            % Extended Training
            fprintf('\n=== EXTENDED TRAINING (90-DAY SEASONAL) ===\n');
            fprintf('Purpose: Seasonal analysis and long-term degradation studies\n');
            fprintf('Duration: ~1 day\n');
            fprintf('??  WARNING: This is a long training session!\n');
            confirm = input('Continue? (y/n): ', 's');
            if strcmpi(confirm, 'y')
                algorithm = select_algorithm();
                if ~isempty(algorithm)
                    try
                        [stats, agent, config] = train_microgrid_drl('extended_90day', algorithm);
                        fprintf('? Extended training completed successfully!\n');
                        save_training_results(stats, agent, config, 'extended_90day', algorithm);
                    catch ME
                        fprintf('? Training failed: %s\n', ME.message);
                    end
                end
            end
            
        case 7
            % Algorithm Comparison
            fprintf('\n=== ALGORITHM COMPARISON STUDY ===\n');
            fprintf('Purpose: Comparative analysis of DDPG, TD3, and SAC\n');
            fprintf('Duration: ~6 hours (3 algorithms ?? 2 hours each)\n');
            fprintf('??  WARNING: This will run multiple long training sessions!\n');
            confirm = input('Continue? (y/n): ', 's');
            if strcmpi(confirm, 'y')
                run_algorithm_comparison();
            end
            
        case 8
            % Analyze Results
            fprintf('\n=== RESULT ANALYSIS ===\n');
            analyze_drl_results();
            
        case 9
            % Interactive MATLAB Menu
            fprintf('\n=== INTERACTIVE MATLAB MENU ===\n');
            fprintf('Switching to interactive MATLAB command mode...\n');
            fprintf('Type "return" to come back to this menu.\n');
            keyboard;
            
        case 10
            % Exit
            fprintf('\nThank you for using the Scientific Microgrid DRL Research System!\n');
            fprintf('For questions or support, please refer to the documentation.\n');
            break;
            
        otherwise
            fprintf('? Invalid choice. Please select 3-10.\n');
    end
end

end

function algorithm = select_algorithm()
% Select algorithm with scientific justification
fprintf('\nSelect Algorithm:\n');
fprintf('1. DDPG (Deep Deterministic Policy Gradient) - Baseline continuous control\n');
fprintf('2. TD3 (Twin Delayed DDPG) - Improved stability with twin critics\n');
fprintf('3. SAC (Soft Actor-Critic) - Entropy-regularized for exploration\n');
fprintf('4. Use optimized configuration (recommended)\n');

choice = input('Algorithm choice (1-4): ');
switch choice
    case 1
        algorithm = 'ddpg';
    case 2
        algorithm = 'td3';
    case 3
        algorithm = 'sac';
    case 4
        fprintf('\nOptimized configurations available:\n');
        fprintf('1. DDPG Optimized (tuned hyperparameters)\n');
        fprintf('2. TD3 Optimized (tuned hyperparameters)\n');
        fprintf('3. SAC Optimized (tuned hyperparameters)\n');
        opt_choice = input('Optimized algorithm (1-3): ');
        switch opt_choice
            case 1
                algorithm = 'ddpg_optimized';
            case 2
                algorithm = 'td3_optimized';
            case 3
                algorithm = 'sac_optimized';
            otherwise
                fprintf('Invalid choice. Using DDPG optimized.\n');
                algorithm = 'ddpg_optimized';
        end
    otherwise
        fprintf('Invalid choice. Cancelling.\n');
        algorithm = '';
end
end

function run_algorithm_comparison()
% Run comprehensive algorithm comparison study
algorithms = {'ddpg_optimized', 'td3_optimized', 'sac_optimized'};
results = cell(length(algorithms), 1);

fprintf('\nStarting algorithm comparison study...\n');
fprintf('This will train %d algorithms sequentially.\n', length(algorithms));

for i = 1:length(algorithms)
    fprintf('\n--- Training %d/%d: %s ---\n', i, length(algorithms), upper(algorithms{i}));
    try
        [stats, agent, config] = train_microgrid_drl('research_30day', algorithms{i});
        results{i} = struct('stats', stats, 'agent', agent, 'config', config, 'algorithm', algorithms{i});
        fprintf('? %s training completed!\n', upper(algorithms{i}));
    catch ME
        fprintf('? %s training failed: %s\n', upper(algorithms{i}), ME.message);
        results{i} = [];
    end
end

% Save comparison results
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
filename = sprintf('results/algorithm_comparison_%s.mat', timestamp);
save(filename, 'results', 'algorithms');
fprintf('\n? Algorithm comparison completed!\n');
fprintf('Results saved to: %s\n', filename);

% Generate comparison analysis
try
    generate_comparison_analysis(results, algorithms);
    fprintf('? Comparison analysis generated!\n');
catch ME
    fprintf('??  Analysis generation failed: %s\n', ME.message);
end
end

function save_training_results(stats, agent, config, config_name, algorithm)
% Save training results with scientific metadata
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
filename = sprintf('results/%s_%s_%s.mat', config_name, algorithm, timestamp);

% Create results directory if it doesn't exist
if ~exist('results', 'dir')
    mkdir('results');
end

% Save with comprehensive metadata
metadata = struct();
metadata.timestamp = timestamp;
metadata.config_name = config_name;
metadata.algorithm = algorithm;
metadata.matlab_version = version;
metadata.system_info = computer;
metadata.training_duration = stats.TrainingTime;

save(filename, 'stats', 'agent', 'config', 'metadata');
fprintf('? Results saved to: %s\n', filename);
end

function analyze_drl_results()
% Analyze existing DRL training results
fprintf('Searching for result files...\n');

if ~exist('results', 'dir')
    fprintf('? No results directory found. Please run training first.\n');
    return;
end

result_files = dir('results/*.mat');
if isempty(result_files)
    fprintf('? No result files found. Please run training first.\n');
    return;
end

fprintf('Found %d result files:\n', length(result_files));
for i = 1:length(result_files)
    fprintf('%d. %s\n', i, result_files(i).name);
end

choice = input('Select file to analyze (number): ');
if choice >= 1 && choice <= length(result_files)
    filename = fullfile('results', result_files(choice).name);
    fprintf('Loading %s...\n', filename);
    
    try
        data = load(filename);
        generate_analysis_report(data);
        fprintf('? Analysis completed!\n');
    catch ME
        fprintf('? Analysis failed: %s\n', ME.message);
    end
else
    fprintf('? Invalid selection.\n');
end
end

function generate_analysis_report(data)
% Generate comprehensive analysis report
fprintf('\n=== TRAINING ANALYSIS REPORT ===\n');
if isfield(data, 'metadata')
    fprintf('Configuration: %s\n', data.metadata.config_name);
    fprintf('Algorithm: %s\n', upper(data.metadata.algorithm));
    fprintf('Training Date: %s\n', data.metadata.timestamp);
    fprintf('Training Duration: %.2f minutes\n', data.metadata.training_duration);
end

if isfield(data, 'stats')
    fprintf('\nTraining Statistics:\n');
    fprintf('Episodes Completed: %d\n', length(data.stats.EpisodeReward));
    fprintf('Final Episode Reward: %.2f\n', data.stats.EpisodeReward(end));
    fprintf('Average Reward (last 10): %.2f\n', mean(data.stats.EpisodeReward(end-9:end)));
    fprintf('Best Episode Reward: %.2f\n', max(data.stats.EpisodeReward));
end

% Generate plots if possible
try
    figure('Name', 'Training Analysis', 'Position', [100, 100, 1200, 800]);
    
    subplot(2,2,1);
    plot(data.stats.EpisodeReward);
    title('Episode Rewards');
    xlabel('Episode');
    ylabel('Reward');
    grid on;
    
    subplot(2,2,2);
    plot(movmean(data.stats.EpisodeReward, 10));
    title('Moving Average Rewards (10 episodes)');
    xlabel('Episode');
    ylabel('Average Reward');
    grid on;
    
    if isfield(data.stats, 'EpisodeQ0')
        subplot(2,2,3);
        plot(data.stats.EpisodeQ0);
        title('Q-Value Evolution');
        xlabel('Episode');
        ylabel('Q0 Value');
        grid on;
    end
    
    if isfield(data.stats, 'EpisodeSteps')
        subplot(2,2,4);
        plot(data.stats.EpisodeSteps);
        title('Episode Steps');
        xlabel('Episode');
        ylabel('Steps');
        grid on;
    end
    
    fprintf('? Analysis plots generated!\n');
catch ME
    fprintf('??  Plot generation failed: %s\n', ME.message);
end
end

function generate_comparison_analysis(results, algorithms)
% Generate comparative analysis of multiple algorithms
fprintf('\n=== ALGORITHM COMPARISON ANALYSIS ===\n');

valid_results = ~cellfun(@isempty, results);
if sum(valid_results) < 2
    fprintf('? Need at least 2 successful training runs for comparison.\n');
    return;
end

figure('Name', 'Algorithm Comparison', 'Position', [100, 100, 1400, 1000]);

% Plot comparison
subplot(2,2,1);
hold on;
colors = {'b', 'r', 'g'};
for i = 1:length(results)
    if ~isempty(results{i})
        plot(results{i}.stats.EpisodeReward, colors{i}, 'LineWidth', 1.5);
    end
end
legend(algorithms(valid_results), 'Location', 'best');
title('Episode Rewards Comparison');
xlabel('Episode');
ylabel('Reward');
grid on;

% Moving average comparison
subplot(2,2,2);
hold on;
for i = 1:length(results)
    if ~isempty(results{i})
        plot(movmean(results{i}.stats.EpisodeReward, 10), colors{i}, 'LineWidth', 2);
    end
end
legend(algorithms(valid_results), 'Location', 'best');
title('Moving Average Comparison (10 episodes)');
xlabel('Episode');
ylabel('Average Reward');
grid on;

fprintf('? Comparison analysis completed!\n');
end
