function cleanup_project()
% CLEANUP_PROJECT - ����main�ļ��У��������Ĺ����ļ�
%
% �˺�����main�ļ�������Ϊרҵ����Ŀ�ṹ���ʺ���ʦ��ѧ��ʹ��

fprintf('=== ��Ŀ�������֯ ===\n');
fprintf('��ʼʱ��: %s\n', datestr(now));

%% 1. ��������
fprintf('\n1. ��������...\n');
backup_folder = sprintf('backup_%s', datestr(now, 'yyyymmdd_HHMMSS'));
if ~exist(backup_folder, 'dir')
    mkdir(backup_folder);
end

% ������Ҫ�ĵ����ļ�
backup_files = {
    'soc_investigation_final_report.md';
    'soc_simulation_investigation_report.m';
    'corrected_7day_continuous_simulation.m';
    'create_corrected_simulation_plots.m'
};

for i = 1:length(backup_files)
    if exist(backup_files{i}, 'file')
        copyfile(backup_files{i}, fullfile(backup_folder, backup_files{i}));
        fprintf('  ����: %s\n', backup_files{i});
    end
end

%% 2. ���屣���ļ��б�
fprintf('\n2. ��������ļ��ṹ...\n');

% ����DRLѵ���ļ�
core_drl_files = {
    'train_microgrid_drl.m';           % ��ҪDRLѵ���ű�
    'run_quick_training.m';            % ����ѵ���ű�
    'run_scientific_drl_menu.m';       % ��ѧDRL�˵�
    'MicrogridEnvironment.m';          % ��������
    'ResearchMicrogridEnvironment.m';  % �о�����
    'create_configurable_agent.m';    % ����������
};

% ����ͷ����ļ�
postprocess_files = {
    'analyze_results.m';               % �������
    'generate_simulation_data.m';      % ������������
    'visualize_soc_analysis.m';        % SOC���ӻ�
    'continuous_30day_simulation.m';   % 30����������
    'execute_30day_challenge.m';       % 30����ս
};

% ���ú������ļ�
config_data_files = {
    'setup_project_paths.m';          % ·������
    'load_workspace_data.m';          % �����ռ����ݼ���
};

% ��Ҫ��ģ�ͺ�����Ŀ¼
essential_dirs = {
    'simulinkmodel';                   % Simulinkģ�ͣ����뱣����
    'config';                         % �����ļ�
    'data';                           % �����ļ�
    'results';                        % ����ļ�
    'models';                         % ѵ��ģ��
    'scripts';                        % �ű�Ŀ¼
};

% ������ѵ��ģ�ͣ����µģ�
keep_models = {
    'trained_agent_30day_gpu_20250811_071932.mat';
    'training_stats_30day_gpu_20250811_071932.mat';
};

%% 3. �Ƴ���ʱ�ļ�
fprintf('\n3. �Ƴ���ʱ���ظ��ļ�...\n');

% Ҫɾ���Ĺ�ʱ�ļ�
obsolete_files = {
    'battery_soc_technical_analysis.m';      % �ѱ������汾���
    'comprehensive_7day_simulation.m';       % ��ʱ�ķ���
    'comprehensive_battery_soc_analysis.m';  % �ظ�����
    'comprehensive_verification_test_english.m'; % ��ʱ��֤
    'verify_7day_episodes_days.m';          % ����֤���
    'verify_30day_capability.m';            % ����֤���
    'check_simulink_model.m';               % һ���Լ��ű�
    'debug_price_signal.m';                 % ���Խű�
    'test_configuration_system.m';          % ���Խű�
    'fix_fis_input_protection.m';           % һ�����޸��ű�
    'segmented_30day_simulation.m';         % �������������
    'rl_based_30day_analysis.m';            % �ظ�����
    'soc_investigation_final_report.md';    % �ƶ���docs
    'soc_simulation_investigation_report.m'; % �ƶ���docs
    'corrected_7day_continuous_simulation.m'; % ���ɵ����ű�
    'create_corrected_simulation_plots.m';   % ���ɵ������ű�
    'batch_matlab_integration_report.txt';   % ��ʱ����
    'verification_report.txt';               % ��ʱ����
    'main_README.md';                        % �ظ��ĵ�
    'main_README_zhcn.md';                   % �ظ��ĵ�
    'Microgrid.slxc';                        % ���뻺��
};

removed_count = 0;
for i = 1:length(obsolete_files)
    if exist(obsolete_files{i}, 'file')
        delete(obsolete_files{i});
        fprintf('  ɾ��: %s\n', obsolete_files{i});
        removed_count = removed_count + 1;
    end
end

%% 4. ����resultsĿ¼
fprintf('\n4. ����resultsĿ¼...\n');
results_dir = 'results';
if exist(results_dir, 'dir')
    % �������µĽ���ļ�
    keep_results = {
        'corrected_7day_simulation_20250819_184752.mat';
        'corrected_7day_simulation_20250819_184752.png';
        '30day_challenge_complete_20250819_173818.mat';
        '30day_challenge_report_20250819_173818.txt';
    };
    
    % ��ȡ���н���ļ�
    all_results = dir(fullfile(results_dir, '*.*'));
    all_results = all_results(~[all_results.isdir]);
    
    cleaned_results = 0;
    for i = 1:length(all_results)
        filename = all_results(i).name;
        if ~ismember(filename, keep_results)
            % ����Ƿ������µ�ѵ�����
            if contains(filename, '20250819') || contains(filename, 'latest')
                continue; % �������½��
            end
            
            delete(fullfile(results_dir, filename));
            cleaned_results = cleaned_results + 1;
        end
    end
    fprintf('  ����results�ļ�: %d��\n', cleaned_results);
end

%% 5. ������뻺��
fprintf('\n5. ������뻺��...\n');
cache_dirs = {'slprj'};
for i = 1:length(cache_dirs)
    if exist(cache_dirs{i}, 'dir')
        rmdir(cache_dirs{i}, 's');
        fprintf('  ɾ������Ŀ¼: %s\n', cache_dirs{i});
    end
end

%% 6. ������Ŀ�ṹ�ĵ�
fprintf('\n6. ������Ŀ�ṹ�ĵ�...\n');
create_project_structure_doc();

%% 7. ��֤���Ĺ���
fprintf('\n7. ��֤���Ĺ���������...\n');
verify_core_functionality();

fprintf('\n=== ��Ŀ������� ===\n');
fprintf('���ʱ��: %s\n', datestr(now));
fprintf('ɾ���ļ���: %d\n', removed_count);
fprintf('��Ŀ�ṹ���Ż����ʺ�ѧ��ʹ��\n\n');

end

function create_project_structure_doc()
% ������Ŀ�ṹ˵���ĵ�

doc_content = {
    '# Main�ļ��нṹ˵��';
    '';
    '## ����DRLѵ���ļ�';
    '- `train_microgrid_drl.m` - ��Ҫ���ǿ��ѧϰѵ���ű�';
    '- `run_quick_training.m` - ����ѵ���Ͳ��Խű�';
    '- `run_scientific_drl_menu.m` - ��ѧ�о�DRL�˵�ϵͳ';
    '- `MicrogridEnvironment.m` - ����΢������������';
    '- `ResearchMicrogridEnvironment.m` - �߼��о�����';
    '- `create_configurable_agent.m` - �����������崴��';
    '';
    '## ����ͷ����ļ�';
    '- `analyze_results.m` - ѵ����������Ϳ��ӻ�';
    '- `generate_simulation_data.m` - ������������';
    '- `visualize_soc_analysis.m` - SOC�������ӻ�';
    '- `continuous_30day_simulation.m` - 30����������';
    '- `execute_30day_challenge.m` - 30����սִ��';
    '';
    '## ���ú�֧���ļ�';
    '- `setup_project_paths.m` - ��Ŀ·������';
    '- `load_workspace_data.m` - �����ռ����ݼ���';
    '';
    '## Ŀ¼�ṹ';
    '- `simulinkmodel/` - Simulinkģ���ļ������뱣����';
    '- `config/` - �����ļ�';
    '- `data/` - ѵ���ͷ�������';
    '- `results/` - ѵ������ͷ���ͼ��';
    '- `models/` - �����DRLģ��';
    '- `scripts/` - �����ű�';
    '';
    '## ʹ��˵��';
    '1. ʹ�ø�Ŀ¼��bat�ļ�������Ŀ';
    '2. ����DRLѵ����`train_microgrid_drl.m`';
    '3. ���ٲ��ԣ�`run_quick_training.m`';
    '4. ���������`analyze_results.m`';
    '5. ���ڷ��棺`continuous_30day_simulation.m`';
};

fid = fopen('PROJECT_STRUCTURE.md', 'w', 'n', 'UTF-8');
for i = 1:length(doc_content)
    fprintf(fid, '%s\n', doc_content{i});
end
fclose(fid);

fprintf('  ����: PROJECT_STRUCTURE.md\n');
end

function verify_core_functionality()
% ��֤���Ĺ����ļ�����

core_files = {
    'train_microgrid_drl.m';
    'run_quick_training.m';
    'analyze_results.m';
    'simulinkmodel/Microgrid.slx';
    'config/simulation_config.m';
    'data/microgrid_workspace.mat';
};

missing_files = {};
for i = 1:length(core_files)
    if ~exist(core_files{i}, 'file')
        missing_files{end+1} = core_files{i};
    end
end

if isempty(missing_files)
    fprintf('  ? ���к����ļ�����\n');
else
    fprintf('  ? ȱʧ�ļ�:\n');
    for i = 1:length(missing_files)
        fprintf('    - %s\n', missing_files{i});
    end
end
end
