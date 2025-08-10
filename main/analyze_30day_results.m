function analyze_30day_results()
% ANALYZE_30DAY_RESULTS - ����������30��ѵ�����
% 
% ���ز�����30��GPU/CPUѵ���Ľ����������ϸ�����ܱ���

fprintf('=========================================================================\n');
fprintf('                30�����������������\n');
fprintf('                30-Day Simulation Results Analysis\n');
fprintf('=========================================================================\n');
fprintf('����ʱ��: %s\n', string(datetime('now')));
fprintf('=========================================================================\n\n');

%% 1. �����ͼ���ѵ�����
fprintf('����1: �����ͼ���ѵ�����...\n');

% ����30��ѵ������ļ�
gpu_files = dir('trained_agent_30day_gpu_*.mat');
cpu_files = dir('trained_agent_30day_cpu_*.mat');
stats_gpu_files = dir('training_stats_30day_gpu_*.mat');
stats_cpu_files = dir('training_stats_30day_cpu_*.mat');

fprintf('����ѵ������ļ�:\n');
fprintf('  GPU�������ļ�: %d ��\n', length(gpu_files));
fprintf('  CPU�������ļ�: %d ��\n', length(cpu_files));
fprintf('  GPUͳ���ļ�: %d ��\n', length(stats_gpu_files));
fprintf('  CPUͳ���ļ�: %d ��\n', length(stats_cpu_files));

if isempty(gpu_files) && isempty(cpu_files)
    fprintf('? δ�ҵ�30��ѵ������ļ�\n');
    fprintf('��������30��ѵ��:\n');
    fprintf('  - train_30day_gpu_simulation (GPUѵ��)\n');
    fprintf('  - train_30day_cpu_simulation (CPUѵ��)\n');
    return;
end

%% 2. �������µ�ѵ�����
fprintf('\n����2: �������µ�ѵ�����...\n');

results = struct();
analysis_count = 0;

% ����GPU���
if ~isempty(gpu_files)
    % ѡ�����µ�GPU�ļ�
    [~, idx] = max([gpu_files.datenum]);
    latest_gpu_file = gpu_files(idx).name;
    
    try
        gpu_data = load(latest_gpu_file);
        results.gpu = gpu_data;
        analysis_count = analysis_count + 1;
        fprintf('? GPUѵ��������سɹ�: %s\n', latest_gpu_file);
        
        % ���ض�Ӧ��ͳ���ļ�
        stats_file = strrep(latest_gpu_file, 'trained_agent_', 'training_stats_');
        if exist(stats_file, 'file')
            gpu_stats = load(stats_file);
            results.gpu_stats = gpu_stats;
            fprintf('? GPUѵ��ͳ�Ƽ��سɹ�: %s\n', stats_file);
        end
        
    catch ME
        fprintf('?? GPU�������ʧ��: %s\n', ME.message);
    end
end

% ����CPU���
if ~isempty(cpu_files)
    % ѡ�����µ�CPU�ļ�
    [~, idx] = max([cpu_files.datenum]);
    latest_cpu_file = cpu_files(idx).name;
    
    try
        cpu_data = load(latest_cpu_file);
        results.cpu = cpu_data;
        analysis_count = analysis_count + 1;
        fprintf('? CPUѵ��������سɹ�: %s\n', latest_cpu_file);
        
        % ���ض�Ӧ��ͳ���ļ�
        stats_file = strrep(latest_cpu_file, 'trained_agent_', 'training_stats_');
        if exist(stats_file, 'file')
            cpu_stats = load(stats_file);
            results.cpu_stats = cpu_stats;
            fprintf('? CPUѵ��ͳ�Ƽ��سɹ�: %s\n', stats_file);
        end
        
    catch ME
        fprintf('?? CPU�������ʧ��: %s\n', ME.message);
    end
end

if analysis_count == 0
    fprintf('? �޷������κ�ѵ�����\n');
    return;
end

%% 3. ѵ�����ܷ���
fprintf('\n����3: ѵ�����ܷ���...\n');

fprintf('\n=== ѵ�����ܶԱ� ===\n');

% ����GPU���
if isfield(results, 'gpu_stats')
    analyze_training_performance('GPU', results.gpu_stats);
end

% ����CPU���
if isfield(results, 'cpu_stats')
    analyze_training_performance('CPU', results.cpu_stats);
end

%% 4. ��������������
fprintf('\n����4: ��������������...\n');

% ������Ŀ·��
try
    setup_project_paths();
catch ME
    fprintf('?? ·�����þ���: %s\n', ME.message);
end

% ����30����������
fprintf('����30����������...\n');
try
    model_cfg = model_config();
    simulation_config = model_cfg;
    simulation_config.simulation.simulation_days = 30;
    simulation_config.simulation.sample_time_hours = 1;
    
    [env, ~, ~] = create_30day_simulation_environment(simulation_config);
    fprintf('? �������������ɹ�\n');
    
    % ����GPU������
    if isfield(results, 'gpu')
        fprintf('\n--- GPU�������������� ---\n');
        gpu_performance = evaluate_agent_performance(results.gpu.agent, env, 'GPU');
        results.gpu_performance = gpu_performance;
    end
    
    % ����CPU������
    if isfield(results, 'cpu')
        fprintf('\n--- CPU�������������� ---\n');
        cpu_performance = evaluate_agent_performance(results.cpu.agent, env, 'CPU');
        results.cpu_performance = cpu_performance;
    end
    
catch ME
    fprintf('?? ����������ʧ��: %s\n', ME.message);
end

%% 5. ���ɶԱȱ���
fprintf('\n����5: ���ɶԱȱ���...\n');

generate_comparison_report(results);

%% 6. ���ɿ��ӻ�ͼ��
fprintf('\n����6: ���ɿ��ӻ�ͼ��...\n');

try
    generate_analysis_plots(results);
    fprintf('? ���ӻ�ͼ���������\n');
catch ME
    fprintf('?? ͼ������ʧ��: %s\n', ME.message);
end

%% 7. ����������
fprintf('\n����7: ����������...\n');

try
    timestamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    analysis_filename = sprintf('30day_analysis_results_%s.mat', timestamp);
    
    save(analysis_filename, 'results');
    assignin('base', 'analysis_results_30day', results);
    
    fprintf('? ��������������\n');
    fprintf('   �ļ�: %s\n', analysis_filename);
    fprintf('   �����ռ����: analysis_results_30day\n');
    
catch ME
    fprintf('?? �������ʧ��: %s\n', ME.message);
end

%% �ܽ�
fprintf('\n=========================================================================\n');
fprintf('=== 30�������������� ===\n');
fprintf('=========================================================================\n');

fprintf('? ����ͳ��:\n');
fprintf('   ������ѵ�����: %d ��\n', analysis_count);
if isfield(results, 'gpu_stats')
    fprintf('   GPUѵ���غ�: %d\n', length(results.gpu_stats.trainingStats.EpisodeReward));
end
if isfield(results, 'cpu_stats')
    fprintf('   CPUѵ���غ�: %d\n', length(results.cpu_stats.trainingStats.EpisodeReward));
end

fprintf('\n? ��Ҫ����:\n');
if isfield(results, 'gpu_performance') && isfield(results, 'cpu_performance')
    gpu_reward = results.gpu_performance.total_reward;
    cpu_reward = results.cpu_performance.total_reward;
    if gpu_reward > cpu_reward
        fprintf('   ? GPU���������ܸ��� (�ܽ���: %.2f vs %.2f)\n', gpu_reward, cpu_reward);
    else
        fprintf('   ? CPU���������ܸ��� (�ܽ���: %.2f vs %.2f)\n', cpu_reward, gpu_reward);
    end
elseif isfield(results, 'gpu_performance')
    fprintf('   ? GPU�������ܽ���: %.2f\n', results.gpu_performance.total_reward);
elseif isfield(results, 'cpu_performance')
    fprintf('   ? CPU�������ܽ���: %.2f\n', results.cpu_performance.total_reward);
end

fprintf('\n? ����:\n');
fprintf('   1. �鿴���ɵĿ��ӻ�ͼ���˽���ϸ����\n');
fprintf('   2. ���ݷ����������ѵ��������\n');
fprintf('   3. ���ǽ��и���ʱ���ѵ���Ի�ø�������\n');
fprintf('   4. ���Բ�ͬ�Ľ����������\n');

fprintf('\n? ����ļ�:\n');
if exist('analysis_filename', 'var')
    fprintf('   �������: %s\n', analysis_filename);
end
fprintf('   ���ӻ�ͼ��: �鿴��ǰĿ¼�е�ͼƬ�ļ�\n');

fprintf('\n? 30�������������ɣ�\n');
fprintf('=========================================================================\n');

end

function analyze_training_performance(device_type, stats_data)
% ����ѵ������

fprintf('\n--- %sѵ������ ---\n', device_type);

if isfield(stats_data, 'trainingStats')
    training_stats = stats_data.trainingStats;
    
    if ~isempty(training_stats.EpisodeReward)
        total_episodes = length(training_stats.EpisodeReward);
        final_reward = training_stats.EpisodeReward(end);
        avg_reward = mean(training_stats.EpisodeReward);
        best_reward = max(training_stats.EpisodeReward);
        
        fprintf('  ��ѵ���غ�: %d\n', total_episodes);
        fprintf('  ���ս���: %.2f\n', final_reward);
        fprintf('  ƽ������: %.2f\n', avg_reward);
        fprintf('  ��ѽ���: %.2f\n', best_reward);
        
        % �����Է���
        if total_episodes >= 20
            early_avg = mean(training_stats.EpisodeReward(1:10));
            late_avg = mean(training_stats.EpisodeReward(end-9:end));
            improvement = late_avg - early_avg;
            
            fprintf('  ѵ���Ľ�: %.2f (ǰ10�غ�: %.2f �� ��10�غ�: %.2f)\n', ...
                    improvement, early_avg, late_avg);
            
            if improvement > 0
                fprintf('  ? ѵ����������\n');
            else
                fprintf('  ?? ѵ��������Ҫ����غ�\n');
            end
        end
    end
    
    if isfield(stats_data, 'training_time')
        training_time = stats_data.training_time;
        fprintf('  ѵ��ʱ��: %.1f ���� (%.2f Сʱ)\n', training_time/60, training_time/3600);
        
        if ~isempty(training_stats.EpisodeReward)
            time_per_episode = training_time / length(training_stats.EpisodeReward);
            fprintf('  ÿ�غ�ʱ��: %.1f ��\n', time_per_episode);
        end
    end
end

end

function performance = evaluate_agent_performance(agent, env, device_type)
% ��������������

fprintf('����30����������...\n');

try
    obs = reset(env);
    total_reward = 0;
    episode_length = 24 * 30; % 30��
    
    rewards_daily = zeros(30, 1);
    soc_history = zeros(episode_length, 1);
    soh_history = zeros(episode_length, 1);
    
    for step = 1:episode_length
        % ʹ��������ѡ����
        action = getAction(agent, obs);
        [obs, reward, done, info] = env.step(action);
        
        total_reward = total_reward + reward;
        soc_history(step) = obs(3);
        soh_history(step) = obs(4);
        
        % ��¼ÿ�ս���
        day = ceil(step / 24);
        if day <= 30
            rewards_daily(day) = rewards_daily(day) + reward;
        end
        
        if mod(step, 24*5) == 0 % ÿ5����ʾһ��
            fprintf('   ��%d��: �ۼƽ���=%.2f, SOC=%.2f, SOH=%.3f\n', ...
                    step/24, total_reward, obs(3), obs(4));
        end
        
        if done
            fprintf('   �����ڵ�%d����ǰ����\n', step);
            break;
        end
    end
    
    % ��������ָ��
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
    
    fprintf('? %s�������������\n', device_type);
    fprintf('   �ܽ���: %.2f\n', total_reward);
    fprintf('   ƽ���ս���: %.2f\n', performance.average_daily_reward);
    fprintf('   ����SOC: %.2f\n', performance.final_soc);
    fprintf('   ����SOH: %.3f\n', performance.final_soh);
    fprintf('   SOH�˻�: %.3f%%\n', performance.soh_degradation * 100);
    
catch ME
    fprintf('? %s����������ʧ��: %s\n', device_type, ME.message);
    performance = struct('device_type', device_type, 'error', ME.message);
end

end

function generate_comparison_report(results)
% ���ɶԱȱ���

fprintf('\n=== 30��ѵ���Աȱ��� ===\n');

if isfield(results, 'gpu_performance') && isfield(results, 'cpu_performance')
    gpu_perf = results.gpu_performance;
    cpu_perf = results.cpu_performance;
    
    fprintf('\n���ܶԱ�:\n');
    fprintf('                    GPU������    CPU������    ����\n');
    fprintf('  �ܽ���:          %8.2f    %8.2f    %+8.2f\n', ...
            gpu_perf.total_reward, cpu_perf.total_reward, ...
            gpu_perf.total_reward - cpu_perf.total_reward);
    fprintf('  ƽ���ս���:      %8.2f    %8.2f    %+8.2f\n', ...
            gpu_perf.average_daily_reward, cpu_perf.average_daily_reward, ...
            gpu_perf.average_daily_reward - cpu_perf.average_daily_reward);
    fprintf('  ����SOC:         %8.2f    %8.2f    %+8.2f\n', ...
            gpu_perf.final_soc, cpu_perf.final_soc, ...
            gpu_perf.final_soc - cpu_perf.final_soc);
    fprintf('  ����SOH:         %8.3f    %8.3f    %+8.3f\n', ...
            gpu_perf.final_soh, cpu_perf.final_soh, ...
            gpu_perf.final_soh - cpu_perf.final_soh);
    fprintf('  SOH�˻�(%%):       %8.2f    %8.2f    %+8.2f\n', ...
            gpu_perf.soh_degradation*100, cpu_perf.soh_degradation*100, ...
            (gpu_perf.soh_degradation - cpu_perf.soh_degradation)*100);
    
    % ȷ����ʤ��
    if gpu_perf.total_reward > cpu_perf.total_reward
        fprintf('\n? GPU���������ܸ���\n');
    elseif cpu_perf.total_reward > gpu_perf.total_reward
        fprintf('\n? CPU���������ܸ���\n');
    else
        fprintf('\n? GPU��CPU�����������൱\n');
    end
    
elseif isfield(results, 'gpu_performance')
    fprintf('\n����GPUѵ�����:\n');
    fprintf('  �ܽ���: %.2f\n', results.gpu_performance.total_reward);
    fprintf('  ƽ���ս���: %.2f\n', results.gpu_performance.average_daily_reward);
    
elseif isfield(results, 'cpu_performance')
    fprintf('\n����CPUѵ�����:\n');
    fprintf('  �ܽ���: %.2f\n', results.cpu_performance.total_reward);
    fprintf('  ƽ���ս���: %.2f\n', results.cpu_performance.average_daily_reward);
end

end

function generate_analysis_plots(results)
% ���ɷ���ͼ��

fprintf('���ɿ��ӻ�ͼ��...\n');

% ����ͼ��
figure('Position', [100, 100, 1200, 800]);

% ѵ�����߶Ա�
if (isfield(results, 'gpu_stats') && isfield(results, 'cpu_stats'))
    subplot(2, 2, 1);
    hold on;
    
    if isfield(results.gpu_stats, 'trainingStats')
        plot(results.gpu_stats.trainingStats.EpisodeReward, 'b-', 'LineWidth', 2, 'DisplayName', 'GPU');
    end
    
    if isfield(results.cpu_stats, 'trainingStats')
        plot(results.cpu_stats.trainingStats.EpisodeReward, 'r-', 'LineWidth', 2, 'DisplayName', 'CPU');
    end
    
    xlabel('ѵ���غ�');
    ylabel('�غϽ���');
    title('ѵ�����߶Ա�');
    legend('show');
    grid on;
end

% ���ܶԱ���״ͼ
if isfield(results, 'gpu_performance') && isfield(results, 'cpu_performance')
    subplot(2, 2, 2);
    
    metrics = [results.gpu_performance.total_reward, results.cpu_performance.total_reward];
    bar(metrics);
    set(gca, 'XTickLabel', {'GPU', 'CPU'});
    ylabel('�ܽ���');
    title('�ܽ����Ա�');
    grid on;
    
    % SOC��ʷ�Ա�
    subplot(2, 2, 3);
    hold on;
    plot(results.gpu_performance.soc_history, 'b-', 'LineWidth', 1.5, 'DisplayName', 'GPU SOC');
    plot(results.cpu_performance.soc_history, 'r-', 'LineWidth', 1.5, 'DisplayName', 'CPU SOC');
    xlabel('ʱ�䲽 (Сʱ)');
    ylabel('SOC');
    title('SOC��ʷ�Ա�');
    legend('show');
    grid on;
    
    % SOH��ʷ�Ա�
    subplot(2, 2, 4);
    hold on;
    plot(results.gpu_performance.soh_history, 'b-', 'LineWidth', 1.5, 'DisplayName', 'GPU SOH');
    plot(results.cpu_performance.soh_history, 'r-', 'LineWidth', 1.5, 'DisplayName', 'CPU SOH');
    xlabel('ʱ�䲽 (Сʱ)');
    ylabel('SOH');
    title('SOH��ʷ�Ա�');
    legend('show');
    grid on;
end

% ����ͼ��
timestamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
saveas(gcf, sprintf('30day_analysis_plots_%s.png', timestamp));

end
