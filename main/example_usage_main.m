function example_usage_main()
% EXAMPLE_USAGE_MAIN - 展示如何使用修复后的main文件夹
% 
% 这个示例展示了main文件夹的所有可用功能
% 包括配置管理、数据生成、环境创建、智能体创建等

fprintf('=== Main文件夹使用示例 ===\n');
fprintf('时间: %s\n', string(datetime('now')));
fprintf('========================================\n\n');

%% 步骤1: 环境设置
fprintf('步骤1: 设置项目环境...\n');
try
    % 设置项目路径
    setup_project_paths();
    fprintf('? 项目路径设置完成\n');
    
    % 加载配置
    model_cfg = model_config();
    training_cfg = training_config_ddpg();
    fprintf('? 配置文件加载完成\n');
    
catch ME
    fprintf('? 环境设置失败: %s\n', ME.message);
    return;
end

%% 步骤2: 数据准备
fprintf('\n步骤2: 准备训练数据...\n');
try
    % 检查是否有现有数据
    if load_workspace_data()
        fprintf('? 使用现有工作空间数据\n');
    else
        fprintf('生成新的训练数据...\n');
        % 设置为1天的数据用于演示
        demo_config = model_cfg;
        demo_config.simulation.simulation_days = 1;
        
        % 生成数据
        [pv_profile, load_profile, price_profile] = generate_microgrid_profiles(demo_config);
        
        % 保存到工作空间
        assignin('base', 'pv_profile', pv_profile);
        assignin('base', 'load_profile', load_profile);
        assignin('base', 'price_profile', price_profile);
        
        fprintf('? 新数据生成完成\n');
    end
    
catch ME
    fprintf('? 数据准备失败: %s\n', ME.message);
    return;
end

%% 步骤3: 创建RL环境
fprintf('\n步骤3: 创建强化学习环境...\n');
try
    % 使用兼容Integrated系统的方法创建环境
    [env, obs_info, action_info] = create_environment_with_specs(model_cfg);
    
    fprintf('? RL环境创建成功\n');
    fprintf('   观测空间: %d维 %s\n', obs_info.Dimension(1), mat2str(obs_info.Dimension));
    fprintf('   动作空间: %d维 %s\n', action_info.Dimension(1), mat2str(action_info.Dimension));
    fprintf('   动作范围: [%.0f, %.0f] W\n', action_info.LowerLimit, action_info.UpperLimit);
    
catch ME
    fprintf('? 环境创建失败: %s\n', ME.message);
    return;
end

%% 步骤4: 创建DDPG智能体
fprintf('\n步骤4: 创建DDPG智能体...\n');
try
    % 创建DDPG智能体
    agent = create_ddpg_agent(obs_info, action_info, training_cfg);
    
    % 将智能体分配到基础工作空间（Simulink需要）
    assignin('base', 'agentObj', agent);
    
    fprintf('? DDPG智能体创建成功\n');
    fprintf('   算法: DDPG\n');
    fprintf('   Actor学习率: %.2e\n', training_cfg.agent.actor_lr);
    fprintf('   Critic学习率: %.2e\n', training_cfg.agent.critic_lr);
    
catch ME
    fprintf('? 智能体创建失败: %s\n', ME.message);
    return;
end

%% 步骤5: 配置训练选项
fprintf('\n步骤5: 配置训练选项...\n');
try
    % 创建演示用的训练选项（短时间训练）
    demo_training_options = rlTrainingOptions(...
        'MaxEpisodes', 10, ...
        'MaxStepsPerEpisode', 24, ...
        'Verbose', true, ...
        'Plots', 'training-progress', ...
        'StopTrainingCriteria', 'AverageReward', ...
        'StopTrainingValue', -100);
    
    fprintf('? 训练选项配置完成\n');
    fprintf('   最大回合数: %d\n', demo_training_options.MaxEpisodes);
    fprintf('   每回合最大步数: %d\n', demo_training_options.MaxStepsPerEpisode);
    
catch ME
    fprintf('? 训练选项配置失败: %s\n', ME.message);
    return;
end

%% 步骤6: 系统验证
fprintf('\n步骤6: 验证系统完整性...\n');
try
    % 验证所有组件
    fprintf('验证组件:\n');
    
    % 检查配置
    assert(~isempty(model_cfg), '模型配置为空');
    fprintf('  ? 模型配置: 正常\n');
    
    % 检查数据
    pv_data = evalin('base', 'pv_profile');
    load_data = evalin('base', 'load_profile');
    price_data = evalin('base', 'price_profile');
    assert(~isempty(pv_data) && ~isempty(load_data) && ~isempty(price_data), '数据不完整');
    fprintf('  ? 训练数据: 正常\n');
    
    % 检查环境
    assert(~isempty(env), '环境为空');
    fprintf('  ? RL环境: 正常\n');
    
    % 检查智能体
    workspace_agent = evalin('base', 'agentObj');
    assert(~isempty(workspace_agent), '工作空间中智能体为空');
    fprintf('  ? DDPG智能体: 正常\n');
    
    % 检查训练选项
    assert(~isempty(demo_training_options), '训练选项为空');
    fprintf('  ? 训练选项: 正常\n');
    
    fprintf('? 系统验证通过\n');
    
catch ME
    fprintf('? 系统验证失败: %s\n', ME.message);
    return;
end

%% 步骤7: 使用建议
fprintf('\n步骤7: 使用建议和下一步...\n');
fprintf('? Main文件夹设置完成！\n\n');

fprintf('可用的功能:\n');
fprintf('  ? 配置管理 - model_config(), training_config_ddpg()\n');
fprintf('  ? 数据生成 - generate_microgrid_profiles()\n');
fprintf('  ? 环境创建 - create_environment_with_specs()\n');
fprintf('  ? 智能体创建 - create_ddpg_agent()\n');
fprintf('  ? 训练配置 - rlTrainingOptions()\n');

fprintf('\n推荐的下一步操作:\n');
fprintf('1. ? 测试功能: test_basic_functionality\n');
fprintf('2. ? 快速训练: quick_train_test (可能需要调试)\n');
fprintf('3. ? 完整训练: train_ddpg_microgrid (可能需要调试)\n');
fprintf('4. ? 使用Integrated: cd(''../Integrated''); run_drl_experiment\n');

fprintf('\n注意事项:\n');
fprintf('??  Simulink仿真可能需要进一步调试\n');
fprintf('? 所有准备工作已完成，可以开始开发\n');
fprintf('? 与Integrated系统完全兼容\n');

fprintf('\n变量状态:\n');
fprintf('  env: RL环境对象\n');
fprintf('  agent: DDPG智能体对象\n');
fprintf('  agentObj: 工作空间中的智能体（Simulink用）\n');
fprintf('  demo_training_options: 演示训练选项\n');

fprintf('\n========================================\n');
fprintf('=== Main文件夹使用示例完成 ===\n');

% 返回创建的对象供后续使用
if nargout > 0
    varargout{1} = struct('env', env, 'agent', agent, 'training_options', demo_training_options);
end

end
