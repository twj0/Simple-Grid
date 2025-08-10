function analyze_30day_results()
% ANALYZE_30DAY_RESULTS - 分析和评估30天训练结果
% 
% 加载并分析30天GPU/CPU训练的结果，生成详细的性能报告

fprintf('=========================================================================\n');
fprintf('                30天仿真结果分析与评估\n');
fprintf('                30-Day Simulation Results Analysis\n');
fprintf('=========================================================================\n');
fprintf('分析时间: %s\n', string(datetime('now')));
fprintf('=========================================================================\n\n');

%% 1. 搜索和加载训练结果
fprintf('步骤1: 搜索和加载训练结果...\n');

% 搜索30天训练结果文件
gpu_files = dir('trained_agent_30day_gpu_*.mat');
cpu_files = dir('trained_agent_30day_cpu_*.mat');
stats_gpu_files = dir('training_stats_30day_gpu_*.mat');
stats_cpu_files = dir('training_stats_30day_cpu_*.mat');

fprintf('发现训练结果文件:\n');
fprintf('  GPU智能体文件: %d 个\n', length(gpu_files));
fprintf('  CPU智能体文件: %d 个\n', length(cpu_files));
fprintf('  GPU统计文件: %d 个\n', length(stats_gpu_files));
fprintf('  CPU统计文件: %d 个\n', length(stats_cpu_files));

if isempty(gpu_files) && isempty(cpu_files)
    fprintf('? 未找到30天训练结果文件\n');
    fprintf('请先运行30天训练:\n');
    fprintf('  - train_30day_gpu_simulation (GPU训练)\n');
    fprintf('  - train_30day_cpu_simulation (CPU训练)\n');
    return;
end

%% 2. 加载最新的训练结果
fprintf('\n步骤2: 加载最新的训练结果...\n');

results = struct();
analysis_count = 0;

% 加载GPU结果
if ~isempty(gpu_files)
    % 选择最新的GPU文件
    [~, idx] = max([gpu_files.datenum]);
    latest_gpu_file = gpu_files(idx).name;
    
    try
        gpu_data = load(latest_gpu_file);
        results.gpu = gpu_data;
        analysis_count = analysis_count + 1;
        fprintf('? GPU训练结果加载成功: %s\n', latest_gpu_file);
        
        % 加载对应的统计文件
        stats_file = strrep(latest_gpu_file, 'trained_agent_', 'training_stats_');
        if exist(stats_file, 'file')
            gpu_stats = load(stats_file);
            results.gpu_stats = gpu_stats;
            fprintf('? GPU训练统计加载成功: %s\n', stats_file);
        end
        
    catch ME
        fprintf('?? GPU结果加载失败: %s\n', ME.message);
    end
end

% 加载CPU结果
if ~isempty(cpu_files)
    % 选择最新的CPU文件
    [~, idx] = max([cpu_files.datenum]);
    latest_cpu_file = cpu_files(idx).name;
    
    try
        cpu_data = load(latest_cpu_file);
        results.cpu = cpu_data;
        analysis_count = analysis_count + 1;
        fprintf('? CPU训练结果加载成功: %s\n', latest_cpu_file);
        
        % 加载对应的统计文件
        stats_file = strrep(latest_cpu_file, 'trained_agent_', 'training_stats_');
        if exist(stats_file, 'file')
            cpu_stats = load(stats_file);
            results.cpu_stats = cpu_stats;
            fprintf('? CPU训练统计加载成功: %s\n', stats_file);
        end
        
    catch ME
        fprintf('?? CPU结果加载失败: %s\n', ME.message);
    end
end

if analysis_count == 0
    fprintf('? 无法加载任何训练结果\n');
    return;
end

%% 3. 训练性能分析
fprintf('\n步骤3: 训练性能分析...\n');

fprintf('\n=== 训练性能对比 ===\n');

% 分析GPU结果
if isfield(results, 'gpu_stats')
    analyze_training_performance('GPU', results.gpu_stats);
end

% 分析CPU结果
if isfield(results, 'cpu_stats')
    analyze_training_performance('CPU', results.cpu_stats);
end

%% 4. 智能体性能评估
fprintf('\n步骤4: 智能体性能评估...\n');

% 设置项目路径
try
    setup_project_paths();
catch ME
    fprintf('?? 路径设置警告: %s\n', ME.message);
end

% 创建30天评估环境
fprintf('创建30天评估环境...\n');
try
    model_cfg = model_config();
    simulation_config = model_cfg;
    simulation_config.simulation.simulation_days = 30;
    simulation_config.simulation.sample_time_hours = 1;
    
    [env, ~, ~] = create_30day_simulation_environment(simulation_config);
    fprintf('? 评估环境创建成功\n');
    
    % 评估GPU智能体
    if isfield(results, 'gpu')
        fprintf('\n--- GPU智能体性能评估 ---\n');
        gpu_performance = evaluate_agent_performance(results.gpu.agent, env, 'GPU');
        results.gpu_performance = gpu_performance;
    end
    
    % 评估CPU智能体
    if isfield(results, 'cpu')
        fprintf('\n--- CPU智能体性能评估 ---\n');
        cpu_performance = evaluate_agent_performance(results.cpu.agent, env, 'CPU');
        results.cpu_performance = cpu_performance;
    end
    
catch ME
    fprintf('?? 智能体评估失败: %s\n', ME.message);
end

%% 5. 生成对比报告
fprintf('\n步骤5: 生成对比报告...\n');

generate_comparison_report(results);

%% 6. 生成可视化图表
fprintf('\n步骤6: 生成可视化图表...\n');

try
    generate_analysis_plots(results);
    fprintf('? 可视化图表生成完成\n');
catch ME
    fprintf('?? 图表生成失败: %s\n', ME.message);
end

%% 7. 保存分析结果
fprintf('\n步骤7: 保存分析结果...\n');

try
    timestamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    analysis_filename = sprintf('30day_analysis_results_%s.mat', timestamp);
    
    save(analysis_filename, 'results');
    assignin('base', 'analysis_results_30day', results);
    
    fprintf('? 分析结果保存完成\n');
    fprintf('   文件: %s\n', analysis_filename);
    fprintf('   工作空间变量: analysis_results_30day\n');
    
catch ME
    fprintf('?? 结果保存失败: %s\n', ME.message);
end

%% 总结
fprintf('\n=========================================================================\n');
fprintf('=== 30天仿真结果分析完成 ===\n');
fprintf('=========================================================================\n');

fprintf('? 分析统计:\n');
fprintf('   分析的训练结果: %d 个\n', analysis_count);
if isfield(results, 'gpu_stats')
    fprintf('   GPU训练回合: %d\n', length(results.gpu_stats.trainingStats.EpisodeReward));
end
if isfield(results, 'cpu_stats')
    fprintf('   CPU训练回合: %d\n', length(results.cpu_stats.trainingStats.EpisodeReward));
end

fprintf('\n? 主要发现:\n');
if isfield(results, 'gpu_performance') && isfield(results, 'cpu_performance')
    gpu_reward = results.gpu_performance.total_reward;
    cpu_reward = results.cpu_performance.total_reward;
    if gpu_reward > cpu_reward
        fprintf('   ? GPU智能体性能更优 (总奖励: %.2f vs %.2f)\n', gpu_reward, cpu_reward);
    else
        fprintf('   ? CPU智能体性能更优 (总奖励: %.2f vs %.2f)\n', cpu_reward, gpu_reward);
    end
elseif isfield(results, 'gpu_performance')
    fprintf('   ? GPU智能体总奖励: %.2f\n', results.gpu_performance.total_reward);
elseif isfield(results, 'cpu_performance')
    fprintf('   ? CPU智能体总奖励: %.2f\n', results.cpu_performance.total_reward);
end

fprintf('\n? 建议:\n');
fprintf('   1. 查看生成的可视化图表了解详细性能\n');
fprintf('   2. 根据分析结果调整训练超参数\n');
fprintf('   3. 考虑进行更长时间的训练以获得更好性能\n');
fprintf('   4. 尝试不同的奖励函数设计\n');

fprintf('\n? 输出文件:\n');
if exist('analysis_filename', 'var')
    fprintf('   分析结果: %s\n', analysis_filename);
end
fprintf('   可视化图表: 查看当前目录中的图片文件\n');

fprintf('\n? 30天仿真结果分析完成！\n');
fprintf('=========================================================================\n');

end

function analyze_training_performance(device_type, stats_data)
% 分析训练性能

fprintf('\n--- %s训练性能 ---\n', device_type);

if isfield(stats_data, 'trainingStats')
    training_stats = stats_data.trainingStats;
    
    if ~isempty(training_stats.EpisodeReward)
        total_episodes = length(training_stats.EpisodeReward);
        final_reward = training_stats.EpisodeReward(end);
        avg_reward = mean(training_stats.EpisodeReward);
        best_reward = max(training_stats.EpisodeReward);
        
        fprintf('  总训练回合: %d\n', total_episodes);
        fprintf('  最终奖励: %.2f\n', final_reward);
        fprintf('  平均奖励: %.2f\n', avg_reward);
        fprintf('  最佳奖励: %.2f\n', best_reward);
        
        % 收敛性分析
        if total_episodes >= 20
            early_avg = mean(training_stats.EpisodeReward(1:10));
            late_avg = mean(training_stats.EpisodeReward(end-9:end));
            improvement = late_avg - early_avg;
            
            fprintf('  训练改进: %.2f (前10回合: %.2f → 后10回合: %.2f)\n', ...
                    improvement, early_avg, late_avg);
            
            if improvement > 0
                fprintf('  ? 训练收敛良好\n');
            else
                fprintf('  ?? 训练可能需要更多回合\n');
            end
        end
    end
    
    if isfield(stats_data, 'training_time')
        training_time = stats_data.training_time;
        fprintf('  训练时间: %.1f 分钟 (%.2f 小时)\n', training_time/60, training_time/3600);
        
        if ~isempty(training_stats.EpisodeReward)
            time_per_episode = training_time / length(training_stats.EpisodeReward);
            fprintf('  每回合时间: %.1f 秒\n', time_per_episode);
        end
    end
end

end

function performance = evaluate_agent_performance(agent, env, device_type)
% 评估智能体性能

fprintf('运行30天性能评估...\n');

try
    obs = reset(env);
    total_reward = 0;
    episode_length = 24 * 30; % 30天
    
    rewards_daily = zeros(30, 1);
    soc_history = zeros(episode_length, 1);
    soh_history = zeros(episode_length, 1);
    
    for step = 1:episode_length
        % 使用智能体选择动作
        action = getAction(agent, obs);
        [obs, reward, done, info] = env.step(action);
        
        total_reward = total_reward + reward;
        soc_history(step) = obs(3);
        soh_history(step) = obs(4);
        
        % 记录每日奖励
        day = ceil(step / 24);
        if day <= 30
            rewards_daily(day) = rewards_daily(day) + reward;
        end
        
        if mod(step, 24*5) == 0 % 每5天显示一次
            fprintf('   第%d天: 累计奖励=%.2f, SOC=%.2f, SOH=%.3f\n', ...
                    step/24, total_reward, obs(3), obs(4));
        end
        
        if done
            fprintf('   评估在第%d步提前结束\n', step);
            break;
        end
    end
    
    % 计算性能指标
    performance = struct();
    performance.device_type = device_type;
    performance.total_reward = total_reward;
    performance.average_daily_reward = mean(rewards_daily);
    performance.final_soc = soc_history(end);
    performance.final_soh = soh_history(end);
    performance.soc_variance = var(soc_history);
    performance.soh_degradation = 1.0 - soh_history(end);
    performance.rewards_daily = rewards_daily;
    performance.soc_history = soc_history;
    performance.soh_history = soh_history;
    
    fprintf('? %s智能体评估完成\n', device_type);
    fprintf('   总奖励: %.2f\n', total_reward);
    fprintf('   平均日奖励: %.2f\n', performance.average_daily_reward);
    fprintf('   最终SOC: %.2f\n', performance.final_soc);
    fprintf('   最终SOH: %.3f\n', performance.final_soh);
    fprintf('   SOH退化: %.3f%%\n', performance.soh_degradation * 100);
    
catch ME
    fprintf('? %s智能体评估失败: %s\n', device_type, ME.message);
    performance = struct('device_type', device_type, 'error', ME.message);
end

end

function generate_comparison_report(results)
% 生成对比报告

fprintf('\n=== 30天训练对比报告 ===\n');

if isfield(results, 'gpu_performance') && isfield(results, 'cpu_performance')
    gpu_perf = results.gpu_performance;
    cpu_perf = results.cpu_performance;
    
    fprintf('\n性能对比:\n');
    fprintf('                    GPU智能体    CPU智能体    差异\n');
    fprintf('  总奖励:          %8.2f    %8.2f    %+8.2f\n', ...
            gpu_perf.total_reward, cpu_perf.total_reward, ...
            gpu_perf.total_reward - cpu_perf.total_reward);
    fprintf('  平均日奖励:      %8.2f    %8.2f    %+8.2f\n', ...
            gpu_perf.average_daily_reward, cpu_perf.average_daily_reward, ...
            gpu_perf.average_daily_reward - cpu_perf.average_daily_reward);
    fprintf('  最终SOC:         %8.2f    %8.2f    %+8.2f\n', ...
            gpu_perf.final_soc, cpu_perf.final_soc, ...
            gpu_perf.final_soc - cpu_perf.final_soc);
    fprintf('  最终SOH:         %8.3f    %8.3f    %+8.3f\n', ...
            gpu_perf.final_soh, cpu_perf.final_soh, ...
            gpu_perf.final_soh - cpu_perf.final_soh);
    fprintf('  SOH退化(%%):       %8.2f    %8.2f    %+8.2f\n', ...
            gpu_perf.soh_degradation*100, cpu_perf.soh_degradation*100, ...
            (gpu_perf.soh_degradation - cpu_perf.soh_degradation)*100);
    
    % 确定优胜者
    if gpu_perf.total_reward > cpu_perf.total_reward
        fprintf('\n? GPU智能体性能更优\n');
    elseif cpu_perf.total_reward > gpu_perf.total_reward
        fprintf('\n? CPU智能体性能更优\n');
    else
        fprintf('\n? GPU和CPU智能体性能相当\n');
    end
    
elseif isfield(results, 'gpu_performance')
    fprintf('\n仅有GPU训练结果:\n');
    fprintf('  总奖励: %.2f\n', results.gpu_performance.total_reward);
    fprintf('  平均日奖励: %.2f\n', results.gpu_performance.average_daily_reward);
    
elseif isfield(results, 'cpu_performance')
    fprintf('\n仅有CPU训练结果:\n');
    fprintf('  总奖励: %.2f\n', results.cpu_performance.total_reward);
    fprintf('  平均日奖励: %.2f\n', results.cpu_performance.average_daily_reward);
end

end

function generate_analysis_plots(results)
% 生成分析图表

fprintf('生成可视化图表...\n');

% 创建图表
figure('Position', [100, 100, 1200, 800]);

% 训练曲线对比
if (isfield(results, 'gpu_stats') && isfield(results, 'cpu_stats'))
    subplot(2, 2, 1);
    hold on;
    
    if isfield(results.gpu_stats, 'trainingStats')
        plot(results.gpu_stats.trainingStats.EpisodeReward, 'b-', 'LineWidth', 2, 'DisplayName', 'GPU');
    end
    
    if isfield(results.cpu_stats, 'trainingStats')
        plot(results.cpu_stats.trainingStats.EpisodeReward, 'r-', 'LineWidth', 2, 'DisplayName', 'CPU');
    end
    
    xlabel('训练回合');
    ylabel('回合奖励');
    title('训练曲线对比');
    legend('show');
    grid on;
end

% 性能对比柱状图
if isfield(results, 'gpu_performance') && isfield(results, 'cpu_performance')
    subplot(2, 2, 2);
    
    metrics = [results.gpu_performance.total_reward, results.cpu_performance.total_reward];
    bar(metrics);
    set(gca, 'XTickLabel', {'GPU', 'CPU'});
    ylabel('总奖励');
    title('总奖励对比');
    grid on;
    
    % SOC历史对比
    subplot(2, 2, 3);
    hold on;
    plot(results.gpu_performance.soc_history, 'b-', 'LineWidth', 1.5, 'DisplayName', 'GPU SOC');
    plot(results.cpu_performance.soc_history, 'r-', 'LineWidth', 1.5, 'DisplayName', 'CPU SOC');
    xlabel('时间步 (小时)');
    ylabel('SOC');
    title('SOC历史对比');
    legend('show');
    grid on;
    
    % SOH历史对比
    subplot(2, 2, 4);
    hold on;
    plot(results.gpu_performance.soh_history, 'b-', 'LineWidth', 1.5, 'DisplayName', 'GPU SOH');
    plot(results.cpu_performance.soh_history, 'r-', 'LineWidth', 1.5, 'DisplayName', 'CPU SOH');
    xlabel('时间步 (小时)');
    ylabel('SOH');
    title('SOH历史对比');
    legend('show');
    grid on;
end

% 保存图表
timestamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
saveas(gcf, sprintf('30day_analysis_plots_%s.png', timestamp));

end
