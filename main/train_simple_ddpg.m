function train_simple_ddpg()
% TRAIN_SIMPLE_DDPG - 使用简化MATLAB环境训练DDPG智能体
% 
% 完全避免Simulink依赖，使用纯MATLAB实现

fprintf('=== 简化DDPG训练 ===\n');
fprintf('时间: %s\n', string(datetime('now')));
fprintf('使用纯MATLAB环境，无Simulink依赖\n');
fprintf('========================================\n\n');

%% 步骤1: 设置环境
fprintf('步骤1: 设置项目环境...\n');
try
    setup_project_paths();
    fprintf('? 项目路径设置完成\n');
catch ME
    fprintf('? 环境设置失败: %s\n', ME.message);
    return;
end

%% 步骤2: 加载配置
fprintf('\n步骤2: 加载配置...\n');
try
    model_cfg = model_config();
    training_cfg = training_config_ddpg();
    fprintf('? 配置加载完成\n');
    fprintf('   电池: %d kW / %d kWh\n', model_cfg.battery.rated_power_kW, model_cfg.battery.rated_capacity_kWh);
catch ME
    fprintf('? 配置加载失败: %s\n', ME.message);
    return;
end

%% 步骤3: 创建环境
fprintf('\n步骤3: 创建简化MATLAB环境...\n');
try
    [env, obs_info, action_info] = create_simple_matlab_environment();
    fprintf('? 环境创建成功\n');
    fprintf('   观测空间: %d维\n', obs_info.Dimension(1));
    fprintf('   动作空间: %d维, 范围: [%.0f, %.0f] W\n', ...
            action_info.Dimension(1), action_info.LowerLimit, action_info.UpperLimit);
catch ME
    fprintf('? 环境创建失败: %s\n', ME.message);
    return;
end

%% 步骤4: 创建DDPG智能体
fprintf('\n步骤4: 创建DDPG智能体...\n');
try
    agent = create_ddpg_agent(obs_info, action_info, training_cfg);
    fprintf('? DDPG智能体创建成功\n');
catch ME
    fprintf('? 智能体创建失败: %s\n', ME.message);
    return;
end

%% 步骤5: 环境测试
fprintf('\n步骤5: 测试环境功能...\n');
try
    % 测试环境重置
    obs = reset(env);
    fprintf('? 环境重置成功\n');
    fprintf('   初始观测: [PV=%.1f, Load=%.1f, SOC=%.2f, SOH=%.2f, Price=%.3f]\n', ...
            obs(1), obs(2), obs(3), obs(4), obs(5));
    
    % 测试环境步进
    test_action = 0;  % 0 W
    [next_obs, reward, is_done, info] = env.step(test_action);
    fprintf('? 环境步进成功，奖励: %.4f\n', reward);
    
catch ME
    fprintf('? 环境测试失败: %s\n', ME.message);
    return;
end

%% 步骤6: 配置训练选项
fprintf('\n步骤6: 配置训练选项...\n');
try
    % 使用较短的训练进行演示
    training_options = rlTrainingOptions(...
        'MaxEpisodes', 20, ...
        'MaxStepsPerEpisode', 24, ...
        'Verbose', true, ...
        'Plots', 'training-progress', ...
        'StopTrainingCriteria', 'AverageReward', ...
        'StopTrainingValue', -30, ...
        'ScoreAveragingWindow', 5);
    
    fprintf('? 训练选项配置完成\n');
    fprintf('   最大回合数: %d\n', training_options.MaxEpisodes);
    fprintf('   每回合最大步数: %d\n', training_options.MaxStepsPerEpisode);
    fprintf('   目标平均奖励: %.1f\n', training_options.StopTrainingValue);
catch ME
    fprintf('? 训练选项配置失败: %s\n', ME.message);
    return;
end

%% 步骤7: 开始训练
fprintf('\n步骤7: 开始DDPG训练...\n');
fprintf('这可能需要几分钟时间...\n');
try
    % 开始训练
    tic;
    training_stats = train(agent, env, training_options);
    training_time = toc;
    
    fprintf('? 训练完成！用时: %.1f 秒\n', training_time);
    
    % 显示训练结果
    if ~isempty(training_stats.EpisodeReward)
        final_reward = training_stats.EpisodeReward(end);
        avg_reward = mean(training_stats.EpisodeReward(max(1, end-4):end));
        fprintf('   最终回合奖励: %.2f\n', final_reward);
        fprintf('   最后5回合平均奖励: %.2f\n', avg_reward);
        fprintf('   总训练回合数: %d\n', length(training_stats.EpisodeReward));
        
        % 检查是否达到目标
        if avg_reward >= training_options.StopTrainingValue
            fprintf('? 达到训练目标！\n');
        else
            fprintf('?? 未达到训练目标，可能需要更多训练\n');
        end
    end
    
catch ME
    fprintf('? 训练失败: %s\n', ME.message);
    fprintf('可能的原因:\n');
    fprintf('1. 网络架构问题\n');
    fprintf('2. 超参数设置问题\n');
    fprintf('3. 环境奖励函数问题\n');
    return;
end

%% 步骤8: 保存训练结果
fprintf('\n步骤8: 保存训练结果...\n');
try
    % 保存训练好的智能体
    save('trained_agent_simple.mat', 'agent', 'training_stats');
    
    % 保存到工作空间
    assignin('base', 'trained_agent', agent);
    assignin('base', 'training_stats', training_stats);
    
    fprintf('? 训练结果已保存\n');
    fprintf('   文件: trained_agent_simple.mat\n');
    fprintf('   工作空间变量: trained_agent, training_stats\n');
    
catch ME
    fprintf('?? 保存失败: %s\n', ME.message);
end

%% 步骤9: 测试训练好的智能体
fprintf('\n步骤9: 测试训练好的智能体...\n');
try
    % 重置环境
    obs = reset(env);
    total_reward = 0;
    episode_data = [];
    
    fprintf('运行一个完整回合...\n');
    for step = 1:24
        % 使用训练好的智能体选择动作
        action = getAction(agent, obs);
        
        % 执行动作
        [obs, reward, is_done, info] = env.step(action);
        total_reward = total_reward + reward;
        
        % 记录数据
        episode_data(step, :) = [step, action/1000, reward, obs(3), obs(4), info.economic_cost];
        
        if mod(step, 6) == 0 || step == 24
            fprintf('   步骤 %d: 动作=%.1f kW, 奖励=%.2f, SOC=%.2f, SOH=%.3f\n', ...
                    step, action/1000, reward, obs(3), obs(4));
        end
        
        if is_done
            fprintf('   回合提前结束于步骤 %d\n', step);
            break;
        end
    end
    
    fprintf('? 测试完成，总奖励: %.2f\n', total_reward);
    
    % 保存测试数据
    assignin('base', 'episode_data', episode_data);
    fprintf('   测试数据已保存到工作空间变量: episode_data\n');
    
catch ME
    fprintf('?? 测试失败: %s\n', ME.message);
end

%% 总结
fprintf('\n========================================\n');
fprintf('=== 简化DDPG训练完成 ===\n');
fprintf('? 成功使用纯MATLAB环境完成训练！\n');

fprintf('\n主要优势:\n');
fprintf('? 完全避免Simulink依赖\n');
fprintf('? 训练速度快\n');
fprintf('? 易于调试和修改\n');
fprintf('? 代码简洁清晰\n');

fprintf('\n训练结果文件:\n');
fprintf('? trained_agent_simple.mat - 训练好的智能体\n');
fprintf('? episode_data - 测试回合数据\n');

fprintf('\n下一步建议:\n');
fprintf('1. 调整奖励函数以获得更好的性能\n');
fprintf('2. 增加训练回合数进行更充分的训练\n');
fprintf('3. 尝试不同的网络架构和超参数\n');
fprintf('4. 分析episode_data来理解智能体行为\n');

fprintf('\n使用示例:\n');
fprintf('load(''trained_agent_simple.mat'')  %% 加载智能体\n');
fprintf('[env, ~, ~] = create_simple_matlab_environment()  %% 创建环境\n');
fprintf('obs = reset(env); action = getAction(agent, obs)  %% 使用智能体\n');

end
