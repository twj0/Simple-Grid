function test_all_training_scripts()
% TEST_ALL_TRAINING_SCRIPTS - 测试所有训练脚本
% 
% 快速测试所有训练脚本是否能正常工作

fprintf('=== 测试所有训练脚本 ===\n');
fprintf('时间: %s\n', string(datetime('now')));
fprintf('========================================\n\n');

%% 设置环境
fprintf('设置项目环境...\n');
try
    setup_project_paths();
    fprintf('? 项目路径设置完成\n');
catch ME
    fprintf('? 路径设置失败: %s\n', ME.message);
    return;
end

%% 测试结果记录
test_results = struct();
test_count = 0;
success_count = 0;

%% 测试1: train_simple_ddpg
fprintf('\n=== 测试1: train_simple_ddpg ===\n');
test_count = test_count + 1;
try
    % 运行简化DDPG训练（快速模式）
    fprintf('运行简化DDPG训练...\n');
    tic;
    train_simple_ddpg();
    training_time = toc;
    
    fprintf('? train_simple_ddpg 测试通过\n');
    fprintf('   训练时间: %.1f 秒\n', training_time);
    test_results.train_simple_ddpg = true;
    success_count = success_count + 1;
    
catch ME
    fprintf('? train_simple_ddpg 测试失败: %s\n', ME.message);
    test_results.train_simple_ddpg = false;
end

%% 测试2: quick_train_test
fprintf('\n=== 测试2: quick_train_test ===\n');
test_count = test_count + 1;
try
    fprintf('运行快速训练测试...\n');
    tic;
    quick_train_test();
    training_time = toc;
    
    fprintf('? quick_train_test 测试通过\n');
    fprintf('   训练时间: %.1f 秒\n', training_time);
    test_results.quick_train_test = true;
    success_count = success_count + 1;
    
catch ME
    fprintf('? quick_train_test 测试失败: %s\n', ME.message);
    test_results.quick_train_test = false;
end

%% 测试3: train_ddpg_microgrid (快速模式)
fprintf('\n=== 测试3: train_ddpg_microgrid (快速模式) ===\n');
test_count = test_count + 1;
try
    fprintf('运行DDPG微电网训练（快速模式）...\n');
    tic;
    train_ddpg_microgrid('QuickTest', true);
    training_time = toc;
    
    fprintf('? train_ddpg_microgrid 测试通过\n');
    fprintf('   训练时间: %.1f 秒\n', training_time);
    test_results.train_ddpg_microgrid = true;
    success_count = success_count + 1;
    
catch ME
    fprintf('? train_ddpg_microgrid 测试失败: %s\n', ME.message);
    test_results.train_ddpg_microgrid = false;
end

%% 测试4: train_td3_microgrid (快速模式)
fprintf('\n=== 测试4: train_td3_microgrid (快速模式) ===\n');
test_count = test_count + 1;
try
    fprintf('运行TD3微电网训练（快速模式）...\n');
    tic;
    train_td3_microgrid('QuickTest', true);
    training_time = toc;
    
    fprintf('? train_td3_microgrid 测试通过\n');
    fprintf('   训练时间: %.1f 秒\n', training_time);
    test_results.train_td3_microgrid = true;
    success_count = success_count + 1;
    
catch ME
    fprintf('? train_td3_microgrid 测试失败: %s\n', ME.message);
    fprintf('   错误详情: %s\n', ME.message);
    test_results.train_td3_microgrid = false;
end

%% 测试5: train_sac_microgrid (快速模式)
fprintf('\n=== 测试5: train_sac_microgrid (快速模式) ===\n');
test_count = test_count + 1;
try
    fprintf('运行SAC微电网训练（快速模式）...\n');
    tic;
    train_sac_microgrid('QuickTest', true);
    training_time = toc;
    
    fprintf('? train_sac_microgrid 测试通过\n');
    fprintf('   训练时间: %.1f 秒\n', training_time);
    test_results.train_sac_microgrid = true;
    success_count = success_count + 1;
    
catch ME
    fprintf('? train_sac_microgrid 测试失败: %s\n', ME.message);
    fprintf('   错误详情: %s\n', ME.message);
    test_results.train_sac_microgrid = false;
end

%% 总结报告
fprintf('\n========================================\n');
fprintf('=== 训练脚本测试结果 ===\n');
fprintf('总测试数: %d\n', test_count);
fprintf('成功测试: %d\n', success_count);
fprintf('成功率: %.1f%%\n', (success_count/test_count)*100);
fprintf('========================================\n\n');

fprintf('详细结果:\n');
test_names = fieldnames(test_results);
for i = 1:length(test_names)
    status = test_results.(test_names{i});
    if status
        fprintf('? %s: 通过\n', test_names{i});
    else
        fprintf('? %s: 失败\n', test_names{i});
    end
end

%% 推荐使用
fprintf('\n推荐使用的训练脚本:\n');
if test_results.train_simple_ddpg
    fprintf('? train_simple_ddpg - 推荐首选（纯MATLAB，最稳定）\n');
end
if test_results.quick_train_test
    fprintf('? quick_train_test - 快速验证（5回合测试）\n');
end
if test_results.train_ddpg_microgrid
    fprintf('? train_ddpg_microgrid - 完整DDPG训练\n');
end

%% 问题诊断
if success_count < test_count
    fprintf('\n问题诊断:\n');
    if ~test_results.train_td3_microgrid
        fprintf('?? TD3训练失败 - 可能是噪声配置问题\n');
        fprintf('   建议: 使用DDPG训练代替\n');
    end
    if ~test_results.train_sac_microgrid
        fprintf('?? SAC训练失败 - 可能是智能体配置问题\n');
        fprintf('   建议: 使用DDPG训练代替\n');
    end
end

%% 保存测试结果
assignin('base', 'training_script_test_results', test_results);
fprintf('\n测试结果已保存到工作空间变量: training_script_test_results\n');

%% 使用建议
fprintf('\n========================================\n');
fprintf('=== 使用建议 ===\n');

if success_count == test_count
    fprintf('? 所有训练脚本都正常工作！\n');
    fprintf('推荐使用顺序:\n');
    fprintf('1. train_simple_ddpg - 日常使用\n');
    fprintf('2. quick_train_test - 快速验证\n');
    fprintf('3. train_ddpg_microgrid - 完整训练\n');
    fprintf('4. train_td3_microgrid - 高级算法\n');
    fprintf('5. train_sac_microgrid - 高级算法\n');
else
    fprintf('部分训练脚本有问题，推荐使用:\n');
    if test_results.train_simple_ddpg
        fprintf('? train_simple_ddpg - 最稳定的选择\n');
    end
    if test_results.quick_train_test
        fprintf('? quick_train_test - 快速测试\n');
    end
    if test_results.train_ddpg_microgrid
        fprintf('? train_ddpg_microgrid - 完整训练\n');
    end
end

fprintf('\n快速启动命令:\n');
fprintf('train_simple_ddpg  %% 推荐\n');
fprintf('quick_train_test   %% 快速验证\n');

end
