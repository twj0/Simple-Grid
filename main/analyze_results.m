function analyze_results(varargin)
% ANALYZE_RESULTS - Simple results analysis for trained agents
%
% This function provides basic analysis of training results and agent performance.
% It replaces the complex scripts directory with a simple, unified analysis tool.
%
% Usage:
%   analyze_results()                    % Analyze latest results
%   analyze_results('agent_file.mat')    % Analyze specific agent file
%   analyze_results('all')               % Analyze all available results

fprintf('=========================================================================\n');
fprintf('                    Microgrid DRL Results Analysis\n');
fprintf('=========================================================================\n');
fprintf('Start time: %s\n', string(datetime('now')));
fprintf('=========================================================================\n\n');

%% 1. Find and Load Results
fprintf('Step 1: Finding training results...\n');

if nargin == 0 || (nargin == 1 && strcmp(varargin{1}, 'all'))
    % Find all result files
    agent_files = [dir('main/trained_*.mat'); dir('main/results/trained_*.mat')];
    stats_files = [dir('main/*_training_stats*.mat'); dir('main/results/*_training_stats*.mat')];
    
    if isempty(agent_files)
        fprintf('INFO: No training results found.\n');
        fprintf('Please run training first using train_microgrid_drl() or quick_start.bat\n');
        return;
    end
    
    fprintf('INFO: Found %d agent files and %d statistics files.\n', length(agent_files), length(stats_files));
    
elseif nargin == 1
    % Analyze specific file
    filename = varargin{1};
    if ~exist(filename, 'file')
        fprintf('ERROR: File not found: %s\n', filename);
        return;
    end
    agent_files = dir(filename);
    stats_files = [];
    fprintf('INFO: Analyzing specific file: %s\n', filename);
end

%% 2. Analyze Each Result
fprintf('\nStep 2: Analyzing results...\n');

for i = 1:length(agent_files)
    fprintf('\n--- Analysis %d/%d ---\n', i, length(agent_files));
    
    try
        % Load agent file
        agent_data = load(fullfile(agent_files(i).folder, agent_files(i).name));
        
        fprintf('File: %s\n', agent_files(i).name);
        fprintf('Date: %s\n', string(datetime(agent_files(i).datenum, 'ConvertFrom', 'datenum')));
        
        % Extract information
        if isfield(agent_data, 'config')
            config = agent_data.config;
            fprintf('Configuration: %s\n', config.meta.config_name);
            fprintf('Algorithm: %s\n', upper(config.training.algorithm));
            fprintf('Simulation: %d days, %d episodes\n', config.simulation.days, config.simulation.episodes);
        end
        
        if isfield(agent_data, 'training_time')
            fprintf('Training time: %.1f minutes (%.2f hours)\n', ...
                    agent_data.training_time/60, agent_data.training_time/3600);
        end
        
        if isfield(agent_data, 'trainingStats') && ~isempty(agent_data.trainingStats.EpisodeReward)
            stats = agent_data.trainingStats;
            
            fprintf('Training Performance:\n');
            fprintf('  Episodes completed: %d\n', length(stats.EpisodeReward));
            fprintf('  Final reward: %.2f\n', stats.EpisodeReward(end));
            fprintf('  Best reward: %.2f\n', max(stats.EpisodeReward));
            fprintf('  Average reward: %.2f\n', mean(stats.EpisodeReward));
            
            % Convergence analysis
            if length(stats.EpisodeReward) >= 40
                early_avg = mean(stats.EpisodeReward(1:20));
                late_avg = mean(stats.EpisodeReward(end-19:end));
                improvement = late_avg - early_avg;
                fprintf('  Learning improvement: %.2f\n', improvement);
                
                if improvement > 0
                    fprintf('  - Agent showed learning improvement.\n');
                  else
                      fprintf('  - WARNING: Agent may need more training or hyperparameter tuning.\n');
                end
            end
        end
        
        fprintf('INFO: Analysis completed for %s\n', agent_files(i).name);
        
    catch ME
        fprintf('ERROR: Failed to analyze %s: %s\n', agent_files(i).name, ME.message);
    end
end

%% 3. Generate Comparison Plot (if multiple results)
if length(agent_files) > 1
    fprintf('\nStep 3: Generating comparison plot...\n');
    
    try
        figure('Position', [100, 100, 1200, 600], 'Name', 'Training Results Comparison');
        
        colors = {'b', 'r', 'g', 'm', 'c', 'k'};
        legend_entries = {};
        
        for i = 1:min(length(agent_files), 6) % Limit to 6 for readability
            try
                agent_data = load(fullfile(agent_files(i).folder, agent_files(i).name));
                
                if isfield(agent_data, 'trainingStats') && ~isempty(agent_data.trainingStats.EpisodeReward)
                    stats = agent_data.trainingStats;
                    
                    % Plot training curve
                    plot(stats.EpisodeReward, colors{i}, 'LineWidth', 2);
                    hold on;
                    
                    % Create legend entry
                    if isfield(agent_data, 'config')
                        legend_entries{end+1} = sprintf('%s (%s)', ...
                            upper(agent_data.config.training.algorithm), ...
                            agent_data.config.meta.config_name);
                    else
                        legend_entries{end+1} = sprintf('Result %d', i);
                    end
                end
                
            catch
                % Skip problematic files
                continue;
            end
        end
        
        if ~isempty(legend_entries)
            title('Training Progress Comparison');
            xlabel('Episode');
            ylabel('Episode Reward');
            legend(legend_entries, 'Location', 'best');
            grid on;
            
            % Save plot
            timestamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
            plot_filename = sprintf('training_comparison_%s.png', timestamp);
            saveas(gcf, plot_filename);
            
            fprintf('INFO: Comparison plot saved as %s\n', plot_filename);
        else
            close(gcf);
            fprintf('WARNING: No valid training data found for plotting.\n');
        end
        
    catch ME
        fprintf('ERROR: Plot generation failed: %s\n', ME.message);
    end
else
    fprintf('\nStep 3: Skipping comparison plot (only one result file)\n');
end

%% 4. Performance Recommendations
fprintf('\nStep 4: Performance recommendations...\n');

if length(agent_files) >= 1
    try
        % Load the most recent result
        [~, newest_idx] = max([agent_files.datenum]);
        latest_data = load(fullfile(agent_files(newest_idx).folder, agent_files(newest_idx).name));
        
        if isfield(latest_data, 'trainingStats') && ~isempty(latest_data.trainingStats.EpisodeReward)
            stats = latest_data.trainingStats;
            final_reward = stats.EpisodeReward(end);
            
            fprintf('Recommendations based on latest training:\n');
            
            if final_reward > -5000
                fprintf('  - Good performance achieved (Final Reward > -5000).\n');
                fprintf('  - Recommendation: Consider testing with longer simulation durations.\n');
            elseif final_reward > -10000
                fprintf('  - Moderate performance (Final Reward > -10000).\n');
                fprintf('  - Recommendation: Try a different algorithm like TD3 or SAC for potentially better results.\n');
                fprintf('  - Recommendation: Increase the number of training episodes.\n');
            else
                fprintf('  - WARNING: Performance requires improvement.\n');
                fprintf('  - Recommendation: Review and adjust configuration parameters.\n');
                fprintf('  - Recommendation: Try the SAC algorithm, which often provides better exploration.\n');
                fprintf('  - Recommendation: Increase the simulation time or the number of training episodes.\n');
            end
            
            % Algorithm-specific recommendations
            if isfield(latest_data, 'config')
                algorithm = latest_data.config.training.algorithm;
                fprintf('\n  Algorithm-specific tips for %s:\n', upper(algorithm));
                
                switch lower(algorithm)
                    case 'ddpg'
                        fprintf('    - DDPG is a deterministic algorithm, making it a good baseline.\n');
                        fprintf('    - For improved stability, consider using the TD3 algorithm.\n');
                    case 'td3'
                        fprintf('    - TD3 offers better stability compared to DDPG.\n');
                        fprintf('    - It provides a good balance between performance and reliability.\n');
                    case 'sac'
                        fprintf('    - SAC is known for its excellent exploration capabilities.\n');
                        fprintf('    - It is often the best choice for complex optimization problems.\n');
                end
            end
        end
        
    catch ME
        fprintf('ERROR: Could not generate recommendations: %s\n', ME.message);
    end
end

%% Summary
fprintf('\n=========================================================================\n');
fprintf('=== Analysis Summary ===\n');
fprintf('=========================================================================\n');

fprintf('INFO: Analyzed %d training result(s).\n', length(agent_files));

if length(agent_files) > 0
    fprintf('INFO: Results are located in main/ and main/results/.\n');
    fprintf('INFO: The most recent result is: %s\n', agent_files(end).name);
end

fprintf('\nRecommended Next Steps:\n');
fprintf('  - Use train_microgrid_drl() to conduct further training sessions.\n');
fprintf('  - Experiment with different configurations (e.g., quick, research, extended).\n');
fprintf('  - Compare the performance of different DRL algorithms (DDPG, TD3, SAC).\n');
fprintf('  - Use the quick_start.bat script for a convenient way to initiate training.\n');

fprintf('\nINFO: Results analysis completed!\n');
fprintf('=========================================================================\n');

end
