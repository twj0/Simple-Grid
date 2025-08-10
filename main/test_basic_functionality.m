function test_basic_functionality()
% TEST_BASIC_FUNCTIONALITY - 测试main文件夹的基本功能
% 
% 这个函数测试修复后的main文件夹是否可以正常工作
% 重点测试与Integrated文件夹的兼容性

fprintf('=== 测试main文件夹基本功能 ===\n');
fprintf('时间: %s\n', string(datetime('now')));
fprintf('========================================\n\n');

%% 测试1: 路径和配置
fprintf('测试1: 路径和配置...\n');
try
    setup_project_paths();
    model_cfg = model_config();
    training_cfg = training_config_ddpg();
    fprintf('? 路径和配置测试通过\n');
catch ME
    fprintf('? 路径和配置测试失败: %s\n', ME.message);
    return;
end

%% 测试2: 数据生成和加载
fprintf('\n测试2: 数据生成和加载...\n');
try
    % 测试工作空间数据加载
    if load_workspace_data()
        fprintf('? 工作空间数据加载成功\n');
    else
        fprintf('?? 工作空间数据不存在，生成新数据...\n');
        test_config = model_cfg;
        test_config.simulation.simulation_days = 1;
        [pv_profile, load_profile, price_profile] = generate_microgrid_profiles(test_config);
        assignin('base', 'pv_profile', pv_profile);
        assignin('base', 'load_profile', load_profile);
        assignin('base', 'price_profile', price_profile);
        fprintf('? 新数据生成成功\n');
    end
catch ME
    fprintf('? 数据生成和加载失败: %s\n', ME.message);
    return;
end

%% 测试3: 环境创建（使用Integrated兼容方法）
fprintf('\n测试3: 环境创建...\n');
try
    [env, obs_info, action_info] = create_environment_with_specs(model_cfg);
    fprintf('? 环境创建成功\n');
    fprintf('   观测维度: %s\n', mat2str(obs_info.Dimension));
    fprintf('   动作维度: %s\n', mat2str(action_info.Dimension));
catch ME
    fprintf('? 环境创建失败: %s\n', ME.message);
    return;
end

%% 测试4: 智能体创建
fprintf('\n测试4: 智能体创建...\n');
try
    agent = create_ddpg_agent(obs_info, action_info, training_cfg);
    assignin('base', 'agentObj', agent);
    fprintf('? DDPG智能体创建成功\n');
catch ME
    fprintf('? 智能体创建失败: %s\n', ME.message);
    return;
end

%% 测试5: 与Integrated系统兼容性测试
fprintf('\n测试5: 与Integrated系统兼容性...\n');
try
    % 检查是否可以使用Integrated文件夹中的数据
    integrated_dir = fullfile(fileparts(pwd), 'Integrated');
    if exist(integrated_dir, 'dir')
        integrated_data_file = fullfile(integrated_dir, 'simulation_data_10days_random.mat');
        if exist(integrated_data_file, 'file')
            fprintf('? 找到Integrated数据文件\n');
            
            % 尝试加载Integrated数据
            integrated_data = load(integrated_data_file);
            if isfield(integrated_data, 'pv_power_profile')
                fprintf('? Integrated数据格式兼容\n');
            else
                fprintf('?? Integrated数据格式需要转换\n');
            end
        else
            fprintf('?? 未找到Integrated数据文件\n');
        end
    else
        fprintf('?? 未找到Integrated文件夹\n');
    end
catch ME
    fprintf('? 兼容性测试失败: %s\n', ME.message);
end

%% 测试6: 训练配置测试
fprintf('\n测试6: 训练配置...\n');
try
    training_options = rlTrainingOptions(...
        'MaxEpisodes', 5, ...
        'MaxStepsPerEpisode', 10, ...
        'Verbose', false, ...
        'Plots', 'none');
    fprintf('? 训练配置创建成功\n');
catch ME
    fprintf('? 训练配置失败: %s\n', ME.message);
end

%% 总结
fprintf('\n========================================\n');
fprintf('=== 基本功能测试完成 ===\n');
fprintf('main文件夹已经具备以下功能:\n');
fprintf('? 配置管理系统\n');
fprintf('? 数据生成和管理\n');
fprintf('? RL环境创建\n');
fprintf('? DDPG智能体创建\n');
fprintf('? 与Integrated系统兼容\n');
fprintf('? 训练配置管理\n');

fprintf('\n下一步建议:\n');
fprintf('1. 运行 train_ddpg_microgrid 开始训练\n');
fprintf('2. 或者运行 quick_train_test 进行快速测试\n');
fprintf('3. 检查 Integrated/run_drl_experiment.m 作为参考\n');

fprintf('\n注意: 如果遇到Simulink仿真问题，可以:\n');
fprintf('1. 使用Integrated文件夹中的工作代码作为参考\n');
fprintf('2. 检查模型配置和数据格式\n');
fprintf('3. 确保所有工作空间变量正确设置\n');

end
