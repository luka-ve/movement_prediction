function [log_file] = instantiate_log_file()
    log_exist = dir('log.csv');
    
    if numel(log_exist) == 0
        % Create log file
        log_table_vars = ['filename', 'time', 'alignment_decision'];
        log_table = array2table(zeros(0,length(log_table_vars)));
        
        log_table.Properties.VariableNames = log_table_vars;
        
        writetable(log_table, 'log.csv')
        
    else
        log_file = log_exist.name;
    end
end
