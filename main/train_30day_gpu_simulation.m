function train_30day_gpu_simulation()
% TRAIN_30DAY_GPU_SIMULATION - 30天物理世界高性能GPU仿真训练
% 
% 基于Integrated文件夹的成功实现，进行真正的30天物理世界模拟仿真
% 特性:
% - 30天完整物理仿真
% - GPU加速训练
% - 合理的时间步长设置
% - 高性能优化配置
% - 完整的结果保存和分析

fprintf('=========================================================================\n');
fprintf('                30天物理世界高性能GPU仿真训练\n');
fprintf('                30-Day Physical World High-Performance GPU Simulation\n');
fprintf('=========================================================================\n');
fprintf('开始时间: %s\n', string(datetime('now')));
fprintf('=========================================================================\n\n');

%% 1. 系统配置和GPU检测
fprintf('步骤1: 系统配置和GPU检测...\n');

% 强制使用软件渲染避免GPU驱动问题
opengl('software');
fprintf('? 图形渲染器设置为软件模式以确保稳定性\n');

% GPU检测和配置
trainingDevice = "cpu";
if ~isempty(ver('parallel')) && gpuDeviceCount > 0
    try
        gpu_info = gpuDevice(1);
        trainingDevice = "gpu";
        fprintf('? GPU检测成功！训练将使用GPU加速\n');
        fprintf('   GPU型号: %s\n', gpu_info.Name);
        fprintf('   GPU内存: %.1f GB\n', gpu_info.AvailableMemory/1024^3);
        fprintf('   计算能力: %.1f\n', gpu_info.ComputeCapability);
    catch ME
        fprintf('?? GPU检测失败，使用CPU训练: %s\n', ME.message);
        trainingDevice = "cpu";
    end
else
    fprintf('?? 未检测到兼容GPU或缺少并行计算工具箱，使用CPU训练\n');
end

%% 2. 项目路径和数据准备
fprintf('\n步骤2: 项目路径和数据准备...\n');
try
    setup_project_paths();
    fprintf('? 项目路径设置完成\n');
catch ME
    fprintf('? 路径设置失败: %s\n', ME.message);
    return;
end

% 生成30天仿真数据
fprintf('生成30天物理仿真数据...\n');
try
    model_cfg = model_config();
    % 设置为30天仿真
    simulation_config = model_cfg;
    simulation_config.simulation.simulation_days = 30;
    simulation_config.simulation.sample_time_hours = 1; % 1小时步长
    
    [pv_profile, load_profile, price_profile] = generate_microgrid_profiles(simulation_config);
    
    % 保存到工作空间
    assignin('base', 'pv_power_profile', pv_profile);
    assignin('base', 'load_power_profile', load_profile);
    assignin('base', 'price_profile', price_profile);
    
    fprintf('? 30天仿真数据生成完成\n');
    fprintf('   PV数据点: %d (%.1f天)\n', length(pv_profile.Data), length(pv_profile.Data)/24);
    fprintf('   负载数据点: %d (%.1f天)\n', length(load_profile.Data), length(load_profile.Data)/24);
    fprintf('   电价数据点: %d (%.1f天)\n', length(price_profile.Data), length(price_profile.Data)/24);
    
catch ME
    fprintf('? 数据生成失败: %s\n', ME.message);
    return;
end

%% 3. 物理系统参数配置
fprintf('\n步骤3: 物理系统参数配置...\n');

% 基于Integrated文件夹的成功配置
PnomkW = 500; % 标称功率 kW
Pnom = PnomkW * 1e3; % 转换为瓦特
kWh_Rated = 100; % 电池容量 kWh
Ts = 3600; % 采样时间 1小时 (秒)
simulationDays = 30; % 仿真天数

% 电池参数
C_rated_Ah = kWh_Rated * 1000 / 5000; % 转换为安时，假设5000V标称电压
Efficiency = 96; % 电池效率百分比
Initial_SOC_pc = 50; % 初始SOC百分比
Initial_SOC_pc_MIN = 30; % 最小初始SOC
Initial_SOC_pc_MAX = 80; % 最大初始SOC
COST_PER_AH_LOSS = 0.25; % 电池退化成本惩罚
SOC_UPPER_LIMIT = 95.0; % SOC上限
SOC_LOWER_LIMIT = 15.0; % SOC下限
SOH_FAILURE_THRESHOLD = 0.8; % SOH失效阈值

fprintf('? 物理系统参数配置完成\n');
fprintf('   标称功率: %d kW\n', PnomkW);
fprintf('   电池容量: %d kWh\n', kWh_Rated);
fprintf('   采样时间: %d 秒 (%.1f 小时)\n', Ts, Ts/3600);
fprintf('   仿真天数: %d 天\n', simulationDays);

%% 4. 创建高性能MATLAB环境
fprintf('\n步骤4: 创建高性能MATLAB环境...\n');
try
    % 使用我们优化的MATLAB环境，但配置为30天仿真
    [env, obs_info, action_info] = create_30day_simulation_environment(simulation_config);
    
    fprintf('? 30天仿真环境创建成功\n');
    fprintf('   观测空间: %d维\n', obs_info.Dimension(1));
    fprintf('   动作空间: %d维, 范围: [%.0f, %.0f] W\n', ...
            action_info.Dimension(1), action_info.LowerLimit, action_info.UpperLimit);
    
catch ME
    fprintf('? 环境创建失败: %s\n', ME.message);
    return;
end

%% 5. 创建高性能GPU优化的DDPG智能体
fprintf('\n步骤5: 创建高性能GPU优化的DDPG智能体...\n');
try
    % 基于Integrated文件夹的成功网络架构
    agent = create_gpu_optimized_ddpg_agent(obs_info, action_info, trainingDevice, Ts, Pnom);
    
    % 分配到基础工作空间
    assignin('base', 'agentObj', agent);
    
    fprintf('? GPU优化DDPG智能体创建成功\n');
    fprintf('   训练设备: %s\n', upper(trainingDevice));
    fprintf('   网络架构: Actor[7→128→64→1], Critic[7+1→128→64→1]\n');
    
catch ME
    fprintf('? 智能体创建失败: %s\n', ME.message);
    return;
end

%% 6. 配置高性能训练选项
fprintf('\n步骤6: 配置高性能训练选项...\n');

% 基于30天仿真的训练配置
max_episodes = 1000; % 增加训练回合数
max_steps_per_episode = 24 * 30; % 每回合30天 = 720小时
score_averaging_window = 20; % 平均窗口

trainOpts = rlTrainingOptions(...
    'MaxEpisodes', max_episodes, ...
    'MaxStepsPerEpisode', max_steps_per_episode, ...
    'ScoreAveragingWindow', score_averaging_window, ...
    'Verbose', true, ...
    'Plots', 'training-progress', ...
    'StopTrainingCriteria', 'AverageReward', ...
    'StopTrainingValue', -10000, ... % 30天的目标奖励
    'SaveAgentCriteria', 'EpisodeReward', ...
    'SaveAgentValue', -15000, ... % 保存表现良好的智能体
    'SaveAgentDirectory', 'trained_agents_30day');

fprintf('? 高性能训练选项配置完成\n');
fprintf('   最大回合数: %d\n', max_episodes);
fprintf('   每回合最大步数: %d (30天)\n', max_steps_per_episode);
fprintf('   目标平均奖励: %.0f\n', trainOpts.StopTrainingValue);

%% 7. 预训练验证
fprintf('\n步骤7: 预训练验证...\n');
try
    % 测试环境重置
    fprintf('测试环境重置...\n');
    test_obs = reset(env);
    fprintf('? 环境重置成功，观测维度: %s\n', mat2str(size(test_obs)));
    
    % 测试环境步进
    fprintf('测试环境步进...\n');
    test_action = 0; % 0 W
    [next_obs, reward, done, info] = env.step(test_action);
    fprintf('? 环境步进成功，奖励: %.4f\n', reward);
    
    fprintf('? 预训练验证通过\n');
    
catch ME
    fprintf('? 预训练验证失败: %s\n', ME.message);
    return;
end

%% 8. 开始30天高性能训练
fprintf('\n步骤8: 开始30天高性能训练...\n');
fprintf('? 这将是一个长时间的训练过程，预计需要数小时...\n');
fprintf('训练配置:\n');
fprintf('   - 物理仿真: 30天/回合\n');
fprintf('   - 时间步长: 1小时\n');
fprintf('   - 训练设备: %s\n', upper(trainingDevice));
fprintf('   - 最大回合数: %d\n', max_episodes);
fprintf('\n开始训练...\n');

training_start_time = tic;
try
    % 开始训练
    trainingStats = train(agent, env, trainOpts);
    training_time = toc(training_start_time);
    
    fprintf('? 30天高性能训练完成！\n');
    fprintf('   总训练时间: %.1f 分钟 (%.2f 小时)\n', training_time/60, training_time/3600);
    
    % 显示训练统计
    if ~isempty(trainingStats.EpisodeReward)
        final_reward = trainingStats.EpisodeReward(end);
        avg_reward = mean(trainingStats.EpisodeReward(max(1, end-19):end)); % 最后20回合平均
        total_episodes = length(trainingStats.EpisodeReward);
        
        fprintf('   训练回合数: %d\n', total_episodes);
        fprintf('   最终回合奖励: %.2f\n', final_reward);
        fprintf('   最后20回合平均奖励: %.2f\n', avg_reward);
        
        if avg_reward >= trainOpts.StopTrainingValue
            fprintf('? 达到训练目标！\n');
        else
            fprintf('?? 未达到训练目标，但训练已完成\n');
        end
    end
    
catch ME
    training_time = toc(training_start_time);
    fprintf('? 训练失败: %s\n', ME.message);
    fprintf('   训练时间: %.1f 分钟\n', training_time/60);
    return;
end

%% 9. 保存训练结果
fprintf('\n步骤9: 保存训练结果...\n');
try
    % 创建结果文件名
    timestamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    agent_filename = sprintf('trained_agent_30day_gpu_%s.mat', timestamp);
    stats_filename = sprintf('training_stats_30day_gpu_%s.mat', timestamp);
    
    % 保存智能体
    save(agent_filename, 'agent', 'trainingStats', 'simulation_config');
    
    % 保存训练统计
    save(stats_filename, 'trainingStats', 'training_time', 'simulation_config', 'trainOpts');
    
    % 保存到工作空间
    assignin('base', 'trained_agent_30day', agent);
    assignin('base', 'training_stats_30day', trainingStats);
    
    fprintf('? 训练结果保存完成\n');
    fprintf('   智能体文件: %s\n', agent_filename);
    fprintf('   统计文件: %s\n', stats_filename);
    
catch ME
    fprintf('?? 结果保存失败: %s\n', ME.message);
end

%% 10. 性能评估
fprintf('\n步骤10: 性能评估...\n');
try
    % 运行一个完整的30天评估
    fprintf('运行30天性能评估...\n');
    obs = reset(env);
    total_reward = 0;
    episode_length = 24 * 30; % 30天
    
    for step = 1:episode_length
        % 使用训练好的智能体
        action = getAction(agent, obs);
        [obs, reward, done, info] = env.step(action);
        total_reward = total_reward + reward;
        
        if mod(step, 24*5) == 0 % 每5天显示一次
            fprintf('   第%d天: 累计奖励=%.2f, SOC=%.2f, SOH=%.3f\n', ...
                    step/24, total_reward, obs(3), obs(4));
        end
        
        if done
            fprintf('   评估在第%d步提前结束\n', step);
            break;
        end
    end
    
    fprintf('? 30天性能评估完成\n');
    fprintf('   总奖励: %.2f\n', total_reward);
    fprintf('   平均日奖励: %.2f\n', total_reward/30);
    
catch ME
    fprintf('?? 性能评估失败: %s\n', ME.message);
end

%% 总结报告
fprintf('\n=========================================================================\n');
fprintf('=== 30天物理世界高性能GPU仿真训练完成 ===\n');
fprintf('=========================================================================\n');

fprintf('? 训练成功完成！\n\n');

fprintf('训练配置:\n');
fprintf('  ? 仿真时长: 30天物理世界\n');
fprintf('  ?? 时间步长: 1小时\n');
fprintf('  ?? 训练设备: %s\n', upper(trainingDevice));
fprintf('  ? 训练回合: %d\n', max_episodes);

if exist('training_time', 'var')
    fprintf('\n性能指标:\n');
    fprintf('  ? 训练时间: %.1f 分钟 (%.2f 小时)\n', training_time/60, training_time/3600);
    if exist('trainingStats', 'var') && ~isempty(trainingStats.EpisodeReward)
        fprintf('  ? 完成回合: %d\n', length(trainingStats.EpisodeReward));
        fprintf('  ? 最终奖励: %.2f\n', trainingStats.EpisodeReward(end));
    end
end

fprintf('\n文件输出:\n');
if exist('agent_filename', 'var')
    fprintf('  ? 训练智能体: %s\n', agent_filename);
end
if exist('stats_filename', 'var')
    fprintf('  ? 训练统计: %s\n', stats_filename);
end

fprintf('\n下一步建议:\n');
fprintf('  1. 分析训练曲线和收敛性\n');
fprintf('  2. 进行更长时间的性能评估\n');
fprintf('  3. 调整超参数进行进一步优化\n');
fprintf('  4. 与基准策略进行对比分析\n');

fprintf('\n? 30天物理世界高性能仿真训练完成！\n');
fprintf('=========================================================================\n');

end
