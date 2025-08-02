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

%% 1. 配置 (Configuration)
% -------------------------------------------------------------------------
simulationDays = 10; % 您想生成的总天数
output_filename = 'simulation_data_10days_random.mat'; % 输出的mat文件名

% --- 仿真求解器配置 ---
% 选择求解器类型：'fixed' 或 'variable'
solver_type = 'variable';  % 推荐使用变步长求解器以获得更好的精度

if strcmp(solver_type, 'fixed')
    % 固定步长配置
    Ts = 3600; % 固定时间步长 (秒)，即1小时
    solver_name = 'ode1';  % 欧拉方法，简单稳定
    fprintf('Using FIXED-STEP solver: %s with Ts = %d seconds\n', solver_name, Ts);
else
    % 变步长配置 - 更高精度
    Ts = 3600; % 数据采样间隔仍为1小时，但求解器可以使用更小的内部步长
    solver_name = 'ode23tb';  % 推荐用于刚性系统的变步长求解器
    % 其他选项: 'ode15s' (更适合刚性系统), 'ode45' (通用), 'ode23' (低阶)
    fprintf('Using VARIABLE-STEP solver: %s with data sampling = %d seconds\n', solver_name, Ts);
end

% --- 随机性控制参数 ---
% 日间变化幅度 [最小值, 最大值] (例如, 0.7表示当天总光伏/负载是平均日的70%)
pv_daily_scale_range = [0.7, 1.2];   % 模拟晴天到多云天的变化
load_daily_scale_range = [0.8, 1.1];  % 模拟高/低负荷日的变化

% 小时级抖动幅度 (例如, 0.1 表示在每小时数据点上有 +/- 5% 的随机抖动)
pv_hourly_jitter = 0.15; % 光伏的小时波动可以更大一些
load_hourly_jitter = 0.05; % 负载的小时波动相对平滑一些

fprintf('Starting data generation for %d day(s) with randomized profiles...\n', simulationDays);

%% 2. 定义基础参数和日负荷曲线 (Baseline Profiles)
% -------------------------------------------------------------------------
Ts = 3600; % 数据点之间的时间间隔 (秒)，即1小时
Tf = simulationDays * 24 * 3600; % 总仿真时长 (秒)
time_vector = (0:Ts:Tf-Ts)'; % 创建时间向量

% 定义一个典型的24小时数据模板
daily_pv_points_base = [0, 0, 0, 0, 0, 5, 20, 50, 100, 180, 250, 230, 200, 150, 80, 30, 5, 0, 0, 0, 0, 0, 0, 0]' * 1e3; % W
daily_load_points_base = [100, 90, 85, 80, 80, 90, 150, 250, 300, 320, 310, 300, 280, 290, 350, 400, 500, 600, 550, 450, 350, 250, 180, 120]' * 1e3; % W
daily_price_points = [0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.7, 0.7, 0.7, 1.2, 1.2, 1.2, 1.2, 0.7, 0.7, 0.7, 0.7, 1.2, 1.2, 1.2, 0.7, 0.7, 0.3, 0.3]'; % $/kWh

disp('... Daily baseline profiles defined.');

%% 3. 生成具有随机性的完整时间序列数据
% -------------------------------------------------------------------------
% 预分配内存以提高效率
final_pv_points = zeros(length(time_vector), 1);
final_load_points = zeros(length(time_vector), 1);

% 循环每一天来施加随机性
for d = 1:simulationDays
    % 1. 生成当天的日间尺度因子
    day_scale_pv = rand() * (pv_daily_scale_range(2) - pv_daily_scale_range(1)) + pv_daily_scale_range(1);
    day_scale_load = rand() * (load_daily_scale_range(2) - load_daily_scale_range(1)) + load_daily_scale_range(1);
    
    % 获取当天的数据索引
    day_indices = (1:24) + (d-1)*24;
    
    for h = 1:24
        % 2. 生成当前小时的抖动因子 (中心化在1附近)
        hour_jitter_pv = 1 + (rand() - 0.5) * pv_hourly_jitter;
        hour_jitter_load = 1 + (rand() - 0.5) * load_hourly_jitter;
        
        % 3. 计算最终数据点 = 基线 * 日尺度 * 小时抖动
        pv_point = daily_pv_points_base(h) * day_scale_pv * hour_jitter_pv;
        load_point = daily_load_points_base(h) * day_scale_load * hour_jitter_load;
        
        % 确保光伏出力不为负
        final_pv_points(day_indices(h)) = max(0, pv_point);
        final_load_points(day_indices(h)) = max(0, load_point);
    end
end

% 电价曲线通常是确定的，所以我们直接重复它
price_points = repmat(daily_price_points, simulationDays, 1);

% 创建 timeseries 对象
pv_power_profile = timeseries(final_pv_points, time_vector, 'Name', 'PV Power Profile');
load_power_profile = timeseries(final_load_points, time_vector, 'Name', 'Load Power Profile');
price_profile = timeseries(price_points, time_vector, 'Name', 'Electricity Price Profile');

disp('... Randomized timeseries objects created.');

%% 4. 数据可视化 (Visualization)
% -------------------------------------------------------------------------
figure('Name', 'Generated Simulation Data Profiles', 'NumberTitle', 'off', 'Position', [200 200 1200 800]);
days_vector = time_vector / (24*3600);

% 光伏出力图
subplot(3,1,1);
plot(days_vector, final_pv_points / 1000, 'Color', [0.9290 0.6940 0.1250]);
title(sprintf('Generated PV Power Profile for %d Days', simulationDays));
xlabel('Time (days)');
ylabel('Power (kW)');
grid on;
xlim([0, simulationDays]);

% 负载功率图
subplot(3,1,2);
plot(days_vector, final_load_points / 1000, 'Color', [0 0.4470 0.7410]);
title(sprintf('Generated Load Profile for %d Days', simulationDays));
xlabel('Time (days)');
ylabel('Power (kW)');
grid on;
xlim([0, simulationDays]);

% 电价图
subplot(3,1,3);
stairs(days_vector, price_points, 'Color', [0.8500 0.3250 0.0980]);
title('Electricity Price Profile');
xlabel('Time (days)');
ylabel('Price ($/kWh)');
grid on;
xlim([0, simulationDays]);
ylim([0, max(price_points)*1.1]);

disp('... Data visualization complete.');

%% 5. 保存到 .mat 文件
% -------------------------------------------------------------------------
try
    % 保存数据和求解器配置信息
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
