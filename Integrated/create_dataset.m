% =========================================================================
%                create_dataset.m
% -------------------------------------------------------------------------
% Description:
%   This script is responsible for generating input data with realistic randomness
%   for microgrid DRL simulation, including PV power output, load power, and
%   real-time electricity prices.
%
%   The generated data is packaged as timeseries objects and saved to a .mat file
%   for loading by the main training script. This script also plots the generated
%   data for verification.
%
%   Press F5 to run and generate the data file.
% =========================================================================

clear; clc; close all;

%% 1. ���� (Configuration)
% -------------------------------------------------------------------------
simulationDays = 10; % �������ɵ�������
output_filename = 'simulation_data_10days_random.mat'; % �����mat�ļ���

% --- ������������� ---
% ѡ����������ͣ�'fixed' �� 'variable'
solver_type = 'variable';  % �Ƽ�ʹ�ñ䲽��������Ի�ø��õľ���

if strcmp(solver_type, 'fixed')
    % �̶���������
    Ts = 3600; % �̶�ʱ�䲽�� (��)����1Сʱ
    solver_name = 'ode1';  % ŷ�����������ȶ�
    fprintf('Using FIXED-STEP solver: %s with Ts = %d seconds\n', solver_name, Ts);
else
    % �䲽������ - ���߾���
    Ts = 3600; % ���ݲ��������Ϊ1Сʱ�������������ʹ�ø�С���ڲ�����
    solver_name = 'ode23tb';  % �Ƽ����ڸ���ϵͳ�ı䲽�������
    % ����ѡ��: 'ode15s' (���ʺϸ���ϵͳ), 'ode45' (ͨ��), 'ode23' (�ͽ�)
    fprintf('Using VARIABLE-STEP solver: %s with data sampling = %d seconds\n', solver_name, Ts);
end

% --- ����Կ��Ʋ��� ---
% �ռ�仯���� [��Сֵ, ���ֵ] (����, 0.7��ʾ�����ܹ��/������ƽ���յ�70%)
pv_daily_scale_range = [0.7, 1.2];   % ģ�����쵽������ı仯
load_daily_scale_range = [0.8, 1.1];  % ģ���/�͸����յı仯

% Сʱ���������� (����, 0.1 ��ʾ��ÿСʱ���ݵ����� +/- 5% ���������)
pv_hourly_jitter = 0.15; % �����Сʱ�������Ը���һЩ
load_hourly_jitter = 0.05; % ���ص�Сʱ�������ƽ��һЩ

fprintf('Starting data generation for %d day(s) with randomized profiles...\n', simulationDays);

%% 2. ��������������ո������� (Baseline Profiles)
% -------------------------------------------------------------------------
Ts = 3600; % ���ݵ�֮���ʱ���� (��)����1Сʱ
Tf = simulationDays * 24 * 3600; % �ܷ���ʱ�� (��)
time_vector = (0:Ts:Tf-Ts)'; % ����ʱ������

% ����һ�����͵�24Сʱ����ģ��
daily_pv_points_base = [0, 0, 0, 0, 0, 5, 20, 50, 100, 180, 250, 230, 200, 150, 80, 30, 5, 0, 0, 0, 0, 0, 0, 0]' * 1e3; % W
daily_load_points_base = [100, 90, 85, 80, 80, 90, 150, 250, 300, 320, 310, 300, 280, 290, 350, 400, 500, 600, 550, 450, 350, 250, 180, 120]' * 1e3; % W
daily_price_points = [0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.7, 0.7, 0.7, 1.2, 1.2, 1.2, 1.2, 0.7, 0.7, 0.7, 0.7, 1.2, 1.2, 1.2, 0.7, 0.7, 0.3, 0.3]'; % $/kWh

disp('... Daily baseline profiles defined.');

%% 3. ���ɾ�������Ե�����ʱ����������
% -------------------------------------------------------------------------
% Ԥ�����ڴ������Ч��
final_pv_points = zeros(length(time_vector), 1);
final_load_points = zeros(length(time_vector), 1);

% ѭ��ÿһ����ʩ�������
for d = 1:simulationDays
    % 1. ���ɵ�����ռ�߶�����
    day_scale_pv = rand() * (pv_daily_scale_range(2) - pv_daily_scale_range(1)) + pv_daily_scale_range(1);
    day_scale_load = rand() * (load_daily_scale_range(2) - load_daily_scale_range(1)) + load_daily_scale_range(1);
    
    % ��ȡ�������������
    day_indices = (1:24) + (d-1)*24;
    
    for h = 1:24
        % 2. ���ɵ�ǰСʱ�Ķ������� (���Ļ���1����)
        hour_jitter_pv = 1 + (rand() - 0.5) * pv_hourly_jitter;
        hour_jitter_load = 1 + (rand() - 0.5) * load_hourly_jitter;
        
        % 3. �����������ݵ� = ���� * �ճ߶� * Сʱ����
        pv_point = daily_pv_points_base(h) * day_scale_pv * hour_jitter_pv;
        load_point = daily_load_points_base(h) * day_scale_load * hour_jitter_load;
        
        % ȷ�����������Ϊ��
        final_pv_points(day_indices(h)) = max(0, pv_point);
        final_load_points(day_indices(h)) = max(0, load_point);
    end
end

% �������ͨ����ȷ���ģ���������ֱ���ظ���
price_points = repmat(daily_price_points, simulationDays, 1);

% ���� timeseries ����
pv_power_profile = timeseries(final_pv_points, time_vector, 'Name', 'PV Power Profile');
load_power_profile = timeseries(final_load_points, time_vector, 'Name', 'Load Power Profile');
price_profile = timeseries(price_points, time_vector, 'Name', 'Electricity Price Profile');

disp('... Randomized timeseries objects created.');

%% 4. ���ݿ��ӻ� (Visualization)
% -------------------------------------------------------------------------
figure('Name', 'Generated Simulation Data Profiles', 'NumberTitle', 'off', 'Position', [200 200 1200 800]);
days_vector = time_vector / (24*3600);

% �������ͼ
subplot(3,1,1);
plot(days_vector, final_pv_points / 1000, 'Color', [0.9290 0.6940 0.1250]);
title(sprintf('Generated PV Power Profile for %d Days', simulationDays));
xlabel('Time (days)');
ylabel('Power (kW)');
grid on;
xlim([0, simulationDays]);

% ���ع���ͼ
subplot(3,1,2);
plot(days_vector, final_load_points / 1000, 'Color', [0 0.4470 0.7410]);
title(sprintf('Generated Load Profile for %d Days', simulationDays));
xlabel('Time (days)');
ylabel('Power (kW)');
grid on;
xlim([0, simulationDays]);

% ���ͼ
subplot(3,1,3);
stairs(days_vector, price_points, 'Color', [0.8500 0.3250 0.0980]);
title('Electricity Price Profile');
xlabel('Time (days)');
ylabel('Price ($/kWh)');
grid on;
xlim([0, simulationDays]);
ylim([0, max(price_points)*1.1]);

disp('... Data visualization complete.');

%% 5. ���浽 .mat �ļ�
% -------------------------------------------------------------------------
try
    % �������ݺ������������Ϣ
    save(output_filename, 'pv_power_profile', 'load_power_profile', 'price_profile', ...
         'simulationDays', 'Ts', 'solver_type', 'solver_name');

    fprintf('SUCCESS: Simulation data saved to "%s".\n', output_filename);
    fprintf('  - Solver type: %s\n', solver_type);
    fprintf('  - Solver name: %s\n', solver_name);
    fprintf('  - Data sampling interval: %d seconds\n', Ts);
    disp('You can now run the main training script.');
catch ME
    fprintf('ERROR: Failed to save data to file.\n');
    rethrow(ME);
end
