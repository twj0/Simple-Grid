% =========================================================================
%                           example_usage.m
% -------------------------------------------------------------------------
% Description:
%   ʾ���ű�չʾ���ʹ���¿����ĸ����ܷ���ͻ�ͼϵͳ
%   
%   �����Ĺ�����ʾ��
%   1. �����ܷ���ű���ʹ��
%   2. ��ʱ�������������ú�����
%   3. ģ�黯��ͼϵͳ�ĸ����÷�
%   4. ���ɹ�������ʾ��
%
% Author: Augment Agent
% Date: 2025-08-06
% Version: 1.0
% =========================================================================

%% �������ռ�
clear; clc; close all;

fprintf('=========================================================================\n');
fprintf('              ΢��������ϵͳʹ��ʾ��\n');
fprintf('=========================================================================\n\n');

%% ʾ��1: �����ܷ��� (30��)
fprintf('ʾ��1: ����30������ܷ���\n');
fprintf('----------------------------------------\n');

try
    % ���ø����ܷ������
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
    
    % ���и����ܷ���
    fprintf('�������������ܷ���...\n');
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
    
    fprintf('? �����ܷ������\n\n');
    
    % �Զ����ɸ����ܷ�����ͼ��
    fprintf('�������ɸ����ܷ�����ͼ��...\n');
    integrated_plotting(hp_results, 'plot_types', {'power_balance', 'soc_price', 'energy_flow'}, ...
                       'output_dir', fullfile(hp_config.output_dir, 'plots'), ...
                       'theme', 'publication', 'format', 'png', 'verbose', true);
    
catch ME
    fprintf('? �����ܷ���ʧ��: %s\n', ME.message);
    fprintf('��������һ��ʾ��...\n\n');
end

%% ʾ��2: ��ʱ��������� (60��)
fprintf('ʾ��2: ����60�쳤ʱ���������\n');
fprintf('----------------------------------------\n');

try
    % ���ó�ʱ��������
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
    
    % ���г�ʱ�����
    fprintf('����������ʱ���������...\n');
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
    
    fprintf('? ��ʱ��������\n\n');
    
    % ���ɳ�ʱ�����ר��ͼ��
    fprintf('�������ɳ�ʱ�������ͼ��...\n');
    integrated_plotting(lt_results, 'plot_types', {'soh_degradation', 'stability_metrics', 'long_term_trends'}, ...
                       'output_dir', fullfile(lt_config.output_dir, 'plots'), ...
                       'theme', 'presentation', 'format', 'pdf', 'verbose', true);
    
catch ME
    fprintf('? ��ʱ�����ʧ��: %s\n', ME.message);
    fprintf('��������һ��ʾ��...\n\n');
end

%% ʾ��3: ������ͼϵͳʹ��
fprintf('ʾ��3: ������ͼϵͳʹ��\n');
fprintf('----------------------------------------\n');

try
    % ����1: ���ļ��������ݲ���ͼ
    fprintf('����1: �ӽ���ļ�����ͼ��\n');
    
    % ����Ƿ��п��õĽ���ļ�
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
        % ʹ�õ�һ�����õĽ���ļ�
        data_file = result_files{1};
        fprintf('ʹ�������ļ�: %s\n', data_file);
        
        % �����������͵�ͼ��
        plot_results = modular_plotting_system('data_file', data_file, ...
                                              'plot_types', 'all', ...
                                              'output_dir', 'standalone_plots', ...
                                              'theme', 'publication', ...
                                              'format', 'png', ...
                                              'resolution', 300, ...
                                              'save_plots', true, ...
                                              'show_plots', false, ...
                                              'verbose', true);
        
        fprintf('? ������ͼ���\n');
    else
        fprintf('? δ�ҵ����õĽ���ļ�������������ͼʾ��\n');
    end
    
    % ����2: ������ͼ
    if length(result_files) > 1
        fprintf('\n����2: ������ͼ����\n');
        batch_plotting(result_files, 'plot_types', {'power_balance', 'battery_performance'}, ...
                      'output_dir', 'batch_plots', 'theme', 'default', 'verbose', true);
        fprintf('? ������ͼ���\n');
    end
    
catch ME
    fprintf('? ������ͼʧ��: %s\n', ME.message);
end

%% ʾ��4: �Զ�������ʾ��
fprintf('\nʾ��4: �Զ�������ʾ��\n');
fprintf('----------------------------------------\n');

try
    % ��ʾ���ʹ���Զ�������
    fprintf('��ʾ�Զ������õ�ʹ�÷���:\n\n');
    
    % �����ܷ�����Զ�������
    fprintf('1. �����ܷ����Զ�������:\n');
    fprintf('   - ��������: 15��\n');
    fprintf('   - �ֶδ�С: 3��\n');
    fprintf('   - ����GPU����\n');
    fprintf('   - �ڴ�����: 4GB\n\n');
    
    % ��ʱ�������Զ�������
    fprintf('2. ��ʱ������Զ�������:\n');
    fprintf('   - ��������: 90��\n');
    fprintf('   - ������: 10��\n');
    fprintf('   - �����ȶ��Լ��\n');
    fprintf('   - �����Զ��ָ�\n');
    fprintf('   - ��������ѹ��\n\n');
    
    % ��ͼϵͳ���Զ�������
    fprintf('3. ��ͼϵͳ�Զ�������:\n');
    fprintf('   - ����: publication (������)\n');
    fprintf('   - ��ʽ: PDF\n');
    fprintf('   - �ֱ���: 300 DPI\n');
    fprintf('   - �ض�ͼ������: power_balance, soc_price, soh_degradation\n\n');
    
    % �����Զ����ͼ����ʾ��
    custom_plot_config = struct();
    custom_plot_config.theme = 'publication';
    custom_plot_config.format = 'pdf';
    custom_plot_config.resolution = 300;
    custom_plot_config.save_plots = true;
    custom_plot_config.show_plots = false;
    
    fprintf('? �Զ�������ʾ�����\n');
    
catch ME
    fprintf('? �Զ�������ʾ��ʧ��: %s\n', ME.message);
end

%% ʾ��5: ���ܶԱȺͽ���
fprintf('\nʾ��5: �����Ż�����\n');
fprintf('----------------------------------------\n');

fprintf('�����Ż�����:\n\n');

fprintf('1. �����ܷ����Ż�:\n');
fprintf('   ? ʹ�÷ֶη�������ڴ�ռ��\n');
fprintf('   ? ����GPU����(�������)\n');
fprintf('   ? ���������ڴ�����\n');
fprintf('   ? �����м����Է����ݶ�ʧ\n\n');

fprintf('2. ��ʱ������Ż�:\n');
fprintf('   ? ���ú��ʵļ�����\n');
fprintf('   ? �����ȶ��Լ��\n');
fprintf('   ? �����Զ�����ָ�\n');
fprintf('   ? ʹ������ѹ����ʡ�洢�ռ�\n\n');

fprintf('3. ��ͼϵͳ�Ż�:\n');
fprintf('   ? ѡ����ʵ�����͸�ʽ\n');
fprintf('   ? ��������������ļ�\n');
fprintf('   ? ���ɵ������������Զ�����ͼ��\n');
fprintf('   ? ʹ��ģ�黯��Ʊ�����չ\n\n');

fprintf('4. ϵͳ��Դ����:\n');
fprintf('   ? �ڴ�: ����8GB���Ƽ�16GB����\n');
fprintf('   ? �洢: Ϊ��ʱ�����Ԥ���㹻�ռ�\n');
fprintf('   ? GPU: ��ѡ������������������\n');
fprintf('   ? CPU: ��˴����������ڲ��м���\n\n');

%% �ܽ�
fprintf('=========================================================================\n');
fprintf('                           ʹ��ʾ���ܽ�\n');
fprintf('=========================================================================\n');

fprintf('��ʾ��չʾ�����¹���:\n\n');

fprintf('? �����ܷ���ű� (high_performance_simulation.m)\n');
fprintf('  - ֧�ֶַη�����ڴ��Ż�\n');
fprintf('  - GPU���ٺͲ��м���\n');
fprintf('  - �Զ����ܼ�غ���Դ����\n\n');

fprintf('? ��ʱ���������ű� (long_term_simulation.m)\n');
fprintf('  - ֧��30-60�쳤ʱ�����\n');
fprintf('  - ����Ͷϵ���������\n');
fprintf('  - �ȶ��Լ�غ��Զ��ָ�\n\n');

fprintf('? ģ�黯��ͼϵͳ (modular_plotting_system.m)\n');
fprintf('  - 8�ֲ�ͬ���͵�רҵͼ��\n');
fprintf('  - ��������������ʽ\n');
fprintf('  - ����ʹ�úͼ���ʹ������ģʽ\n\n');

fprintf('? ���ɹ�������\n');
fprintf('  - ������ɺ��Զ�����ͼ��\n');
fprintf('  - ��������������ļ�\n');
fprintf('  - �������ú���չ����\n\n');

fprintf('�й���ϸʹ�÷�������ο����ű��ļ��е��ĵ���ע�͡�\n');
fprintf('=========================================================================\n');

fprintf('\nʾ���ű�ִ����ɣ�\n');
