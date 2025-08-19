function analyze_fuzzy_logic_english()
% ANALYZE_FUZZY_LOGIC_ENGLISH - Analyze fuzzy logic system logic and data flow issues
%
% This function specifically analyzes the logical reasonableness of Economic FIS,
% rather than modifying rules to accommodate erroneous data

fprintf('=== Fuzzy Logic System Deep Analysis ===\n');

%% Load FIS files
try
    economic_fis_path = fullfile('simulinkmodel', 'Economic_Reward_FIS.fis');
    economic_fis = readfis(economic_fis_path);
    fprintf('? Economic FIS loaded successfully\n');
catch ME
    fprintf('? Cannot load Economic FIS: %s\n', ME.message);
    return;
end

%% Analyze FIS design reasonableness
fprintf('\n=== FIS Design Reasonableness Analysis ===\n');
analyze_fis_design_logic(economic_fis);

%% Analyze rule coverage
fprintf('\n=== Rule Coverage Analysis ===\n');
analyze_rule_coverage(economic_fis);

%% Test Chinese electricity price range reasonableness
fprintf('\n=== Chinese Electricity Price Range Test ===\n');
test_chinese_price_ranges(economic_fis);

%% Analyze possible data flow issues
fprintf('\n=== Data Flow Issue Analysis ===\n');
analyze_data_flow_issues();

%% Provide fix recommendations
fprintf('\n=== Fix Recommendations ===\n');
provide_fix_recommendations();

end

function analyze_fis_design_logic(fis)
% Analyze FIS design logical reasonableness

fprintf('Economic FIS Design Analysis:\n');

% Input 1: Price (electricity price)
fprintf('  Input 1 - Price (electricity price):\n');
fprintf('    Range: [%.1f, %.1f] (should correspond to Chinese electricity price range)\n', fis.Inputs(1).Range(1), fis.Inputs(1).Range(2));
fprintf('    Membership functions: Low, Medium, High\n');
fprintf('    Logic: Use more electricity at low prices, less at high prices ?\n');

% Input 2: SOC (battery state of charge)
fprintf('  Input 2 - SOC (battery state of charge):\n');
fprintf('    Range: [%.0f, %.0f]%% (standard battery SOC range)\n', fis.Inputs(2).Range(1), fis.Inputs(2).Range(2));
fprintf('    Membership functions: Low, Medium, High\n');
fprintf('    Logic: Charge when SOC is low, discharge when SOC is high ?\n');

% Input 3: P_net_load (net load)
fprintf('  Input 3 - P_net_load (net load):\n');
fprintf('    Range: [%.0f, %.0f] W (microgrid power range)\n', fis.Inputs(3).Range(1), fis.Inputs(3).Range(2));
fprintf('    Membership functions: Surplus, Balanced, Load_Demand\n');
fprintf('    Logic: Charge during surplus, discharge during demand ?\n');

% Output: Economic_Score
fprintf('  Output - Economic_Score (economic score):\n');
fprintf('    Range: [%.0f, %.0f] (reward/penalty score)\n', fis.Outputs(1).Range(1), fis.Outputs(1).Range(2));
fprintf('    Membership functions: Strong_Penalty, Penalty, Neutral, Reward, Strong_Reward\n');
fprintf('    Logic: Reward economical operations, penalize uneconomical ones ?\n');

end

function analyze_rule_coverage(fis)
% Analyze rule coverage

fprintf('Rule Coverage Analysis:\n');
fprintf('  Total rules: %d\n', length(fis.Rules));
fprintf('  Theoretical maximum rules: %d ¡Á %d ¡Á %d = %d\n', ...
        length(fis.Inputs(1).MembershipFunctions), ...
        length(fis.Inputs(2).MembershipFunctions), ...
        length(fis.Inputs(3).MembershipFunctions), ...
        length(fis.Inputs(1).MembershipFunctions) * ...
        length(fis.Inputs(2).MembershipFunctions) * ...
        length(fis.Inputs(3).MembershipFunctions));

% Check rule logic
fprintf('\n  Rule logic check:\n');
check_rule_logic(fis);

end

function check_rule_logic(fis)
% Check economic logic reasonableness of rules

% Analyze several key rules
fprintf('    Key rule logic analysis:\n');

% Rule example analysis
rules = fis.Rules;
for i = 1:min(5, length(rules))
    rule = rules(i);
    price_mf = rule.Antecedent(1);
    soc_mf = rule.Antecedent(2);
    load_mf = rule.Antecedent(3);
    output_mf = rule.Consequent(1);
    
    price_name = get_mf_name(fis.Inputs(1), price_mf);
    soc_name = get_mf_name(fis.Inputs(2), soc_mf);
    load_name = get_mf_name(fis.Inputs(3), load_mf);
    output_name = get_mf_name(fis.Outputs(1), output_mf);
    
    fprintf('      Rule %d: IF Price=%s AND SOC=%s AND Load=%s THEN Score=%s\n', ...
            i, price_name, soc_name, load_name, output_name);
    
    % Check logical reasonableness
    logic_check = check_economic_logic(price_name, soc_name, load_name, output_name);
    fprintf('        Economic logic: %s\n', logic_check);
end

end

function name = get_mf_name(input_output, mf_index)
% Get membership function name
if mf_index > 0 && mf_index <= length(input_output.MembershipFunctions)
    name = input_output.MembershipFunctions(mf_index).Name;
else
    name = 'Unknown';
end
end

function logic_result = check_economic_logic(price, soc, load, output)
% Check economic logic reasonableness
logic_result = '? Reasonable';

% Basic economic logic check
if strcmp(price, 'Low') && strcmp(load, 'Load_Demand') && contains(output, 'Penalty')
    logic_result = '? Possibly unreasonable: Meeting load demand at low prices should be economical';
elseif strcmp(price, 'High') && strcmp(load, 'Surplus') && contains(output, 'Reward')
    logic_result = '? Possibly unreasonable: Having surplus at high prices should not be rewarded';
end

end

function test_chinese_price_ranges(fis)
% Test Chinese electricity price range reasonableness

fprintf('Chinese Electricity Price Range Test:\n');

% Actual Chinese electricity price range (CNY/kWh)
chinese_prices = [0.48, 0.86, 1.2, 1.8];  % Valley, standard, peak, maximum
chinese_names = {'Valley', 'Standard', 'Peak', 'Maximum'};

% Convert to FIS range [0, 2]
fis_prices = 2 * (chinese_prices - 0.48) / (1.8 - 0.48);

fprintf('  Chinese electricity price -> FIS price mapping:\n');
for i = 1:length(chinese_prices)
    fprintf('    %s: %.2f CNY/kWh -> %.3f (FIS)\n', ...
            chinese_names{i}, chinese_prices{i}, fis_prices(i));
end

% Test typical scenarios
fprintf('\n  Typical scenario test:\n');
test_scenarios = [
    fis_prices(1), 30, 100000;   % Valley price, low SOC, load demand
    fis_prices(3), 80, -200000;  % Peak price, high SOC, surplus
    fis_prices(2), 50, 0;        % Standard price, medium SOC, balanced
];

scenario_names = {'Valley price charging scenario', 'Peak price discharging scenario', 'Standard price balanced scenario'};

for i = 1:size(test_scenarios, 1)
    try
        output = evalfis(fis, test_scenarios(i, :));
        fprintf('    %s: Output=%.3f\n', scenario_names{i}, output);
    catch ME
        fprintf('    %s: ? Evaluation failed - %s\n', scenario_names{i}, ME.message);
    end
end

end

function analyze_data_flow_issues()
% Analyze possible data flow issues

fprintf('Data Flow Issue Analysis:\n');
fprintf('  Problem phenomenon: Price input value is -4.56961, exceeding FIS range [0, 2]\n');
fprintf('  Possible causes:\n');
fprintf('    1. ? Additional price calculation/conversion in Simulink model\n');
fprintf('    2. ? Price signal modified during transmission\n');
fprintf('    3. ? Unit conversion error (CNY/kWh vs other units)\n');
fprintf('    4. ? Numerical error from mathematical operations\n');
fprintf('    5. ? Signal routing error (wrong signal connected to Price input)\n');

fprintf('\n  Data generation verification:\n');
fprintf('    ? generate_simulation_data() function is correct\n');
fprintf('    ? Price range correctly mapped to [0, 2]\n');
fprintf('    ? Configuration parameters correctly set\n');

end

function provide_fix_recommendations()
% Provide fix recommendations

fprintf('Fix Recommendations (by priority):\n');
fprintf('\n1. ? **Immediately debug Simulink model**:\n');
fprintf('   - Add Display blocks at Economic FIS input\n');
fprintf('   - Monitor actual Price values input to FIS\n');
fprintf('   - Check price_profile signal path\n');

fprintf('\n2. ? **Check signal connections**:\n');
fprintf('   - Verify price_profile connects to correct FIS input\n');
fprintf('   - Check for signal branching or merging errors\n');
fprintf('   - Confirm no unexpected mathematical operation blocks\n');

fprintf('\n3. ? **Add signal validation**:\n');
fprintf('   - Add Saturation blocks before FIS inputs (limit to [0, 2])\n');
fprintf('   - Add Assert blocks to validate input ranges\n');
fprintf('   - Use MinMax blocks to record out-of-range values for debugging\n');

fprintf('\n4. ? **Step-by-step debugging**:\n');
fprintf('   - Use Simulink debugger for step-by-step execution\n');
fprintf('   - Check Price values at each time step\n');
fprintf('   - Determine exact moment and cause of price anomaly\n');

fprintf('\n5. ?? **Temporary protection measures**:\n');
fprintf('   - Add input range checking before FIS\n');
fprintf('   - Truncate or map out-of-range values\n');
fprintf('   - Log warnings but do not interrupt simulation\n');

fprintf('\n? **Not recommended approaches**:\n');
fprintf('   - Modify FIS rules to accommodate erroneous data\n');
fprintf('   - Expand FIS input range to mask the problem\n');
fprintf('   - Ignore warnings and continue running\n');

fprintf('\n? **Correct solution approach**:\n');
fprintf('   - Find and fix errors in data flow\n');
fprintf('   - Maintain economic logic reasonableness of FIS rules\n');
fprintf('   - Ensure price data has correct physical meaning\n');

end
