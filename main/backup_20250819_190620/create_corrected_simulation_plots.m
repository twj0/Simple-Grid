function create_corrected_simulation_plots(simulation_results, timestamp)
% CREATE_CORRECTED_SIMULATION_PLOTS - Generate comprehensive visualization
%
% This function creates scientific-quality plots showing the corrected
% simulation results with proper DRL agent control

fprintf('Generating corrected simulation visualization...\n');

% Extract data
soc_history = simulation_results.soc_history * 100;  % Convert to percentage
soh_history = simulation_results.soh_history * 100;  % Convert to percentage
battery_power = simulation_results.battery_power_history;
grid_power = simulation_results.grid_power_history;
pv_power = simulation_results.pv_power;
load_power = simulation_results.load_power;
price = simulation_results.price;

time_hours = 0:167;

% Create main figure
fig = figure('Name', 'Corrected 7-Day Continuous Simulation Results', ...
             'Position', [50, 50, 1600, 1200], 'Color', 'white');

%% Subplot 1: SOC Evolution (Main Result)
subplot(3, 3, 1);
plot(time_hours, soc_history, 'b-', 'LineWidth', 2);
hold on;
yline(20, 'r--', 'Min SOC', 'LineWidth', 1);
yline(90, 'r--', 'Max SOC', 'LineWidth', 1);
xlabel('Time (Hours)');
ylabel('SOC (%)');
title('Battery SOC Evolution - 7 Days Continuous');
grid on;
xlim([0, 167]);
ylim([15, 95]);

% Add day markers
for day = 1:7
    xline((day-1)*24, 'k:', sprintf('Day %d', day), 'Alpha', 0.3);
end

% Calculate and display statistics
soc_min = min(soc_history);
soc_max = max(soc_history);
soc_range = soc_max - soc_min;
text(10, 85, sprintf('Range: %.1f%% - %.1f%%\nVariation: %.1f%%', ...
     soc_min, soc_max, soc_range), 'FontSize', 10, 'BackgroundColor', 'white');

%% Subplot 2: Battery Power Control
subplot(3, 3, 2);
plot(time_hours, battery_power, 'g-', 'LineWidth', 1.5);
hold on;
yline(0, 'k-', 'Alpha', 0.5);
xlabel('Time (Hours)');
ylabel('Battery Power (kW)');
title('DRL Agent Battery Control Commands');
grid on;
xlim([0, 167]);

% Color coding for charge/discharge
pos_power = battery_power;
pos_power(pos_power < 0) = NaN;
neg_power = battery_power;
neg_power(neg_power > 0) = NaN;

plot(time_hours, pos_power, 'g-', 'LineWidth', 2, 'DisplayName', 'Charging');
plot(time_hours, neg_power, 'r-', 'LineWidth', 2, 'DisplayName', 'Discharging');
legend('Location', 'best');

%% Subplot 3: PV Generation and Load Demand
subplot(3, 3, 3);
plot(time_hours, pv_power, 'y-', 'LineWidth', 1.5, 'DisplayName', 'PV Generation');
hold on;
plot(time_hours, load_power, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Load Demand');
xlabel('Time (Hours)');
ylabel('Power (kW)');
title('PV Generation vs Load Demand');
legend('Location', 'best');
grid on;
xlim([0, 167]);

%% Subplot 4: Grid Power Exchange
subplot(3, 3, 4);
plot(time_hours, grid_power, 'm-', 'LineWidth', 1.5);
hold on;
yline(0, 'k-', 'Alpha', 0.5);
xlabel('Time (Hours)');
ylabel('Grid Power (kW)');
title('Grid Power Exchange');
grid on;
xlim([0, 167]);

% Color coding for import/export
import_power = grid_power;
import_power(import_power < 0) = NaN;
export_power = grid_power;
export_power(export_power > 0) = NaN;

plot(time_hours, import_power, 'r-', 'LineWidth', 2, 'DisplayName', 'Import');
plot(time_hours, export_power, 'g-', 'LineWidth', 2, 'DisplayName', 'Export');
legend('Location', 'best');

%% Subplot 5: SOH Degradation
subplot(3, 3, 5);
plot(time_hours, soh_history, 'r-', 'LineWidth', 2);
xlabel('Time (Hours)');
ylabel('SOH (%)');
title('Battery Health Degradation');
grid on;
xlim([0, 167]);

soh_initial = soh_history(1);
soh_final = soh_history(end);
soh_degradation = soh_initial - soh_final;
text(10, soh_final + 0.002, sprintf('Degradation: %.4f%%', soh_degradation), ...
     'FontSize', 10, 'BackgroundColor', 'white');

%% Subplot 6: Energy Balance Analysis
subplot(3, 3, 6);
net_energy = pv_power - load_power;
plot(time_hours, net_energy, 'k-', 'LineWidth', 1.5, 'DisplayName', 'Net Energy');
hold on;
plot(time_hours, battery_power, 'g-', 'LineWidth', 1.5, 'DisplayName', 'Battery Power');
yline(0, 'k--', 'Alpha', 0.5);
xlabel('Time (Hours)');
ylabel('Power (kW)');
title('Energy Balance: Net vs Battery');
legend('Location', 'best');
grid on;
xlim([0, 167]);

%% Subplot 7: Price Signal and Agent Response
subplot(3, 3, 7);
yyaxis left;
plot(time_hours, price, 'c-', 'LineWidth', 1.5);
ylabel('Price (CNY/kWh)');
yyaxis right;
plot(time_hours, battery_power, 'g-', 'LineWidth', 1.5);
ylabel('Battery Power (kW)');
xlabel('Time (Hours)');
title('Price Signal vs Agent Response');
grid on;
xlim([0, 167]);

%% Subplot 8: Daily SOC Patterns
subplot(3, 3, 8);
colors = lines(7);
for day = 1:7
    day_start = (day-1) * 24 + 1;
    day_end = day * 24;
    day_hours = 0:23;
    day_soc = soc_history(day_start:day_end);
    
    plot(day_hours, day_soc, 'Color', colors(day,:), 'LineWidth', 1.5, ...
         'DisplayName', sprintf('Day %d', day));
    hold on;
end
xlabel('Hour of Day');
ylabel('SOC (%)');
title('Daily SOC Patterns');
legend('Location', 'best');
grid on;
xlim([0, 23]);

%% Subplot 9: Performance Summary
subplot(3, 3, 9);
axis off;

% Calculate performance metrics
soc_variation = max(soc_history) - min(soc_history);
avg_battery_power = mean(abs(battery_power));
avg_grid_power = mean(abs(grid_power));
total_energy_traded = sum(abs(grid_power)) / 1000;  % MWh

% Agent activity analysis
charging_hours = sum(battery_power > 1);
discharging_hours = sum(battery_power < -1);
idle_hours = 168 - charging_hours - discharging_hours;

% Create performance summary text
summary_text = {
    'CORRECTED SIMULATION SUMMARY';
    '================================';
    '';
    sprintf('SOC Variation: %.1f%%', soc_variation);
    sprintf('SOC Range: %.1f%% - %.1f%%', min(soc_history), max(soc_history));
    sprintf('SOH Degradation: %.4f%%', soh_degradation);
    '';
    sprintf('Avg Battery Power: %.1f kW', avg_battery_power);
    sprintf('Avg Grid Power: %.1f kW', avg_grid_power);
    sprintf('Total Energy Traded: %.2f MWh', total_energy_traded);
    '';
    'AGENT ACTIVITY:';
    sprintf('Charging Hours: %d (%.1f%%)', charging_hours, charging_hours/168*100);
    sprintf('Discharging Hours: %d (%.1f%%)', discharging_hours, discharging_hours/168*100);
    sprintf('Idle Hours: %d (%.1f%%)', idle_hours, idle_hours/168*100);
    '';
    'VALIDATION STATUS:';
    sprintf('SOC Realistic: %s', ternary(soc_variation > 10, 'PASS', 'FAIL'));
    sprintf('Agent Active: %s', ternary(avg_battery_power > 1, 'PASS', 'FAIL'));
    sprintf('Continuous Op: %s', ternary(length(soc_history) == 168, 'PASS', 'FAIL'));
};

text(0.05, 0.95, summary_text, 'FontSize', 10, 'FontName', 'Courier', ...
     'VerticalAlignment', 'top', 'Units', 'normalized');

%% Add overall title and save
sgtitle(sprintf('Corrected 7-Day Continuous Simulation - %s', timestamp), ...
        'FontSize', 16, 'FontWeight', 'bold');

% Save figure
fig_filename = sprintf('results/corrected_7day_simulation_%s.png', timestamp);
saveas(fig, fig_filename);
fprintf('Visualization saved: %s\n', fig_filename);

% Generate additional analysis plots
create_detailed_analysis_plots(simulation_results, timestamp);

end

function create_detailed_analysis_plots(simulation_results, timestamp)
% Create additional detailed analysis plots

fprintf('Generating detailed analysis plots...\n');

% SOC vs Battery Power correlation
fig2 = figure('Name', 'SOC-Power Correlation Analysis', ...
              'Position', [100, 100, 1200, 800], 'Color', 'white');

subplot(2, 2, 1);
scatter(simulation_results.soc_history * 100, simulation_results.battery_power_history, ...
        20, 'filled', 'Alpha', 0.6);
xlabel('SOC (%)');
ylabel('Battery Power (kW)');
title('SOC vs Battery Power Correlation');
grid on;

subplot(2, 2, 2);
scatter(simulation_results.price, simulation_results.battery_power_history, ...
        20, 'filled', 'Alpha', 0.6);
xlabel('Price (CNY/kWh)');
ylabel('Battery Power (kW)');
title('Price vs Battery Power Correlation');
grid on;

subplot(2, 2, 3);
net_power = simulation_results.pv_power - simulation_results.load_power;
scatter(net_power, simulation_results.battery_power_history, ...
        20, 'filled', 'Alpha', 0.6);
xlabel('Net Power (PV - Load) (kW)');
ylabel('Battery Power (kW)');
title('Net Power vs Battery Power Correlation');
grid on;

subplot(2, 2, 4);
hour_of_day = mod(0:167, 24);
scatter(hour_of_day, simulation_results.battery_power_history, ...
        20, 'filled', 'Alpha', 0.6);
xlabel('Hour of Day');
ylabel('Battery Power (kW)');
title('Time of Day vs Battery Power');
grid on;

sgtitle('Agent Behavior Analysis', 'FontSize', 14, 'FontWeight', 'bold');

% Save detailed analysis
fig2_filename = sprintf('results/corrected_7day_analysis_%s.png', timestamp);
saveas(fig2, fig2_filename);
fprintf('Detailed analysis saved: %s\n', fig2_filename);

end

function result = ternary(condition, true_val, false_val)
if condition
    result = true_val;
else
    result = false_val;
end
end
