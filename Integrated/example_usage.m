% =========================================================================
%                           example_usage.m
% -------------------------------------------------------------------------
% Description:
%   示例脚本展示如何使用新开发的高性能仿真和绘图系统
%   
%   包含的功能演示：
%   1. 高性能仿真脚本的使用
%   2. 长时间物理仿真的配置和运行
%   3. 模块化绘图系统的各种用法
%   4. 集成工作流程示例
%
% Author: Augment Agent
% Date: 2025-08-06
% Version: 1.0
% =========================================================================

%% 清理工作空间
clear; clc; close all;

fprintf('=========================================================================\n');
fprintf('              微电网仿真系统使用示例\n');
fprintf('=========================================================================\n\n');

%% 示例1: 高性能仿真 (30天)
fprintf('示例1: 运行30天高性能仿真\n');
fprintf('----------------------------------------\n');

try
    % 配置高性能仿真参数
    hp_config = struct();
    hp_config.simulation_days = 30;
    hp_config.segment_days = 5;
    hp_config.data_file = 'simulation_data_10days_random.mat';
    hp_config.model_name = 'Microgrid2508020734';
    hp_config.agent_file = 'final_trained_agent_random.mat';
    hp_config.output_dir = 'hp_simulation_results';
    hp_config.enable_gpu = true;
    hp_config.memory_limit_gb = 8;
    hp_config.save_intermediate = true;
    hp_config.verbose = true;
    
    % 运行高性能仿真
    fprintf('正在启动高性能仿真...\n');
    hp_results = high_performance_simulation('simulation_days', hp_config.simulation_days, ...
                                           'segment_days', hp_config.segment_days, ...
                                           'data_file', hp_config.data_file, ...
                                           'model_name', hp_config.model_name, ...
                                           'agent_file', hp_config.agent_file, ...
                                           'output_dir', hp_config.output_dir, ...
                                           'enable_gpu', hp_config.enable_gpu, ...
                                           'memory_limit_gb', hp_config.memory_limit_gb, ...
                                           'save_intermediate', hp_config.save_intermediate, ...
                                           'verbose', hp_config.verbose);
    
    fprintf('? 高性能仿真完成\n\n');
    
    % 自动生成高性能仿真结果图表
    fprintf('正在生成高性能仿真结果图表...\n');
    integrated_plotting(hp_results, 'plot_types', {'power_balance', 'soc_price', 'energy_flow'}, ...
                       'output_dir', fullfile(hp_config.output_dir, 'plots'), ...
                       'theme', 'publication', 'format', 'png', 'verbose', true);
    
catch ME
    fprintf('? 高性能仿真失败: %s\n', ME.message);
    fprintf('跳过到下一个示例...\n\n');
end

%% 示例2: 长时间物理仿真 (60天)
fprintf('示例2: 运行60天长时间物理仿真\n');
fprintf('----------------------------------------\n');

try
    % 配置长时间仿真参数
    lt_config = struct();
    lt_config.simulation_days = 60;
    lt_config.checkpoint_interval = 7;
    lt_config.data_file = 'simulation_data_10days_random.mat';
    lt_config.model_name = 'Microgrid2508020734';
    lt_config.agent_file = 'final_trained_agent_random.mat';
    lt_config.output_dir = 'long_term_results';
    lt_config.memory_threshold_gb = 6;
    lt_config.stability_monitoring = true;
    lt_config.auto_recovery = true;
    lt_config.data_compression = true;
    lt_config.verbose = true;
    
    % 运行长时间仿真
    fprintf('正在启动长时间物理仿真...\n');
    lt_results = long_term_simulation('simulation_days', lt_config.simulation_days, ...
                                    'checkpoint_interval', lt_config.checkpoint_interval, ...
                                    'data_file', lt_config.data_file, ...
                                    'model_name', lt_config.model_name, ...
                                    'agent_file', lt_config.agent_file, ...
                                    'output_dir', lt_config.output_dir, ...
                                    'memory_threshold_gb', lt_config.memory_threshold_gb, ...
                                    'stability_monitoring', lt_config.stability_monitoring, ...
                                    'auto_recovery', lt_config.auto_recovery, ...
                                    'data_compression', lt_config.data_compression, ...
                                    'verbose', lt_config.verbose);
    
    fprintf('? 长时间仿真完成\n\n');
    
    % 生成长时间仿真专用图表
    fprintf('正在生成长时间仿真结果图表...\n');
    integrated_plotting(lt_results, 'plot_types', {'soh_degradation', 'stability_metrics', 'long_term_trends'}, ...
                       'output_dir', fullfile(lt_config.output_dir, 'plots'), ...
                       'theme', 'presentation', 'format', 'pdf', 'verbose', true);
    
catch ME
    fprintf('? 长时间仿真失败: %s\n', ME.message);
    fprintf('跳过到下一个示例...\n\n');
end

%% 示例3: 独立绘图系统使用
fprintf('示例3: 独立绘图系统使用\n');
fprintf('----------------------------------------\n');

try
    % 方法1: 从文件加载数据并绘图
    fprintf('方法1: 从结果文件生成图表\n');
    
    % 检查是否有可用的结果文件
    result_files = {};
    if exist('hp_simulation_results/final_simulation_results.mat', 'file')
        result_files{end+1} = 'hp_simulation_results/final_simulation_results.mat';
    end
    if exist('long_term_results/final_long_term_results.mat', 'file')
        result_files{end+1} = 'long_term_results/final_long_term_results.mat';
    end
    if exist('simulation_results.mat', 'file')
        result_files{end+1} = 'simulation_results.mat';
    end
    
    if ~isempty(result_files)
        % 使用第一个可用的结果文件
        data_file = result_files{1};
        fprintf('使用数据文件: %s\n', data_file);
        
        % 生成所有类型的图表
        plot_results = modular_plotting_system('data_file', data_file, ...
                                              'plot_types', 'all', ...
                                              'output_dir', 'standalone_plots', ...
                                              'theme', 'publication', ...
                                              'format', 'png', ...
                                              'resolution', 300, ...
                                              'save_plots', true, ...
                                              'show_plots', false, ...
                                              'verbose', true);
        
        fprintf('? 独立绘图完成\n');
    else
        fprintf('? 未找到可用的结果文件，跳过独立绘图示例\n');
    end
    
    % 方法2: 批量绘图
    if length(result_files) > 1
        fprintf('\n方法2: 批量绘图处理\n');
        batch_plotting(result_files, 'plot_types', {'power_balance', 'battery_performance'}, ...
                      'output_dir', 'batch_plots', 'theme', 'default', 'verbose', true);
        fprintf('? 批量绘图完成\n');
    end
    
catch ME
    fprintf('? 独立绘图失败: %s\n', ME.message);
end

%% 示例4: 自定义配置示例
fprintf('\n示例4: 自定义配置示例\n');
fprintf('----------------------------------------\n');

try
    % 演示如何使用自定义配置
    fprintf('演示自定义配置的使用方法:\n\n');
    
    % 高性能仿真的自定义配置
    fprintf('1. 高性能仿真自定义配置:\n');
    fprintf('   - 仿真天数: 15天\n');
    fprintf('   - 分段大小: 3天\n');
    fprintf('   - 启用GPU加速\n');
    fprintf('   - 内存限制: 4GB\n\n');
    
    % 长时间仿真的自定义配置
    fprintf('2. 长时间仿真自定义配置:\n');
    fprintf('   - 仿真天数: 90天\n');
    fprintf('   - 检查点间隔: 10天\n');
    fprintf('   - 启用稳定性监控\n');
    fprintf('   - 启用自动恢复\n');
    fprintf('   - 启用数据压缩\n\n');
    
    % 绘图系统的自定义配置
    fprintf('3. 绘图系统自定义配置:\n');
    fprintf('   - 主题: publication (发表用)\n');
    fprintf('   - 格式: PDF\n');
    fprintf('   - 分辨率: 300 DPI\n');
    fprintf('   - 特定图表类型: power_balance, soc_price, soh_degradation\n\n');
    
    % 创建自定义绘图配置示例
    custom_plot_config = struct();
    custom_plot_config.theme = 'publication';
    custom_plot_config.format = 'pdf';
    custom_plot_config.resolution = 300;
    custom_plot_config.save_plots = true;
    custom_plot_config.show_plots = false;
    
    fprintf('? 自定义配置示例完成\n');
    
catch ME
    fprintf('? 自定义配置示例失败: %s\n', ME.message);
end

%% 示例5: 性能对比和建议
fprintf('\n示例5: 性能优化建议\n');
fprintf('----------------------------------------\n');

fprintf('性能优化建议:\n\n');

fprintf('1. 高性能仿真优化:\n');
fprintf('   ? 使用分段仿真减少内存占用\n');
fprintf('   ? 启用GPU加速(如果可用)\n');
fprintf('   ? 合理设置内存限制\n');
fprintf('   ? 保存中间结果以防数据丢失\n\n');

fprintf('2. 长时间仿真优化:\n');
fprintf('   ? 设置合适的检查点间隔\n');
fprintf('   ? 启用稳定性监控\n');
fprintf('   ? 启用自动错误恢复\n');
fprintf('   ? 使用数据压缩节省存储空间\n\n');

fprintf('3. 绘图系统优化:\n');
fprintf('   ? 选择合适的主题和格式\n');
fprintf('   ? 批量处理多个结果文件\n');
fprintf('   ? 集成到仿真流程中自动生成图表\n');
fprintf('   ? 使用模块化设计便于扩展\n\n');

fprintf('4. 系统资源建议:\n');
fprintf('   ? 内存: 至少8GB，推荐16GB以上\n');
fprintf('   ? 存储: 为长时间仿真预留足够空间\n');
fprintf('   ? GPU: 可选，但能显著提升性能\n');
fprintf('   ? CPU: 多核处理器有助于并行计算\n\n');

%% 总结
fprintf('=========================================================================\n');
fprintf('                           使用示例总结\n');
fprintf('=========================================================================\n');

fprintf('本示例展示了以下功能:\n\n');

fprintf('? 高性能仿真脚本 (high_performance_simulation.m)\n');
fprintf('  - 支持分段仿真和内存优化\n');
fprintf('  - GPU加速和并行计算\n');
fprintf('  - 自动性能监控和资源管理\n\n');

fprintf('? 长时间物理仿真脚本 (long_term_simulation.m)\n');
fprintf('  - 支持30-60天长时间仿真\n');
fprintf('  - 检查点和断点续传功能\n');
fprintf('  - 稳定性监控和自动恢复\n\n');

fprintf('? 模块化绘图系统 (modular_plotting_system.m)\n');
fprintf('  - 8种不同类型的专业图表\n');
fprintf('  - 多种主题和输出格式\n');
fprintf('  - 独立使用和集成使用两种模式\n\n');

fprintf('? 集成工作流程\n');
fprintf('  - 仿真完成后自动生成图表\n');
fprintf('  - 批量处理多个结果文件\n');
fprintf('  - 灵活的配置和扩展能力\n\n');

fprintf('有关详细使用方法，请参考各脚本文件中的文档和注释。\n');
fprintf('=========================================================================\n');

fprintf('\n示例脚本执行完成！\n');
