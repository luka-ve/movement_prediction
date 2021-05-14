function write_log_entry(msg, ppt_info)
    log_file_location = '/home/luka/Thesis/movement_prediction/MATLAB/Log/log.txt';
    
    if isfile(log_file_location)
        fileID = fopen(log_file_location, 'a');
        Write_Message(fileID, msg, ppt_info);
    else 
        fileID = fopen(log_file_location, 'w');
        Write_Message(fileID, msg, ppt_info);
    end
    fclose(fileID);
end

function Write_Message(fileID, msg, ppt_info)
    timestamp = datestr(datetime(now, 'ConvertFrom', 'datenum'));
    if isfield(ppt_info, 'subfolder')
        subfolder = ppt_info.subfolder;
    else
        subfolder = '-';
    end
    
    if isfield(ppt_info, 'filename')
        filename = ppt_info.filename;
    else
        filename = '-';
    end
        
    log_msg = strjoin({timestamp, subfolder, filename, convertStringsToChars(msg), '\n'}, ' / ');
    fprintf(fileID, log_msg);
end


