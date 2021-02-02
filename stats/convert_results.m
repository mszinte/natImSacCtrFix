function convert_results(subject,session,num_run,plot_res)
% ----------------------------------------------------------------------
% convert_results(subject,session,num_run,plot_res)
% ----------------------------------------------------------------------
% Goal of the function :
% Convert resutls in .mat format
% ----------------------------------------------------------------------
% Input(s) :
% subject : subject name (ex. 'sub-01')
% session : session number (ex. 1)
% num_run : number of runs to analyse
% plot_res : plot results
% ----------------------------------------------------------------------
% Output(s):
% .mat results
% ----------------------------------------------------------------------
% Function created by Martin SZINTE (martin.szinte@gmail.com)
% Last update : 02 / 02 / 2021
% Project :     natImSacFix
% Version :     1.0
% ----------------------------------------------------------------------

%% Get data

% define files names
file_dir = sprintf('%s/data/%s/ses-0%i',cd,subject,session);
task1_txt = 'rest';

list_filename = {   sprintf('%s_ses-0%i_task-%s_run-01',subject,session,task1_txt),...
                    sprintf('%s_ses-0%i_task-%s_run-02',subject,session,task1_txt)};


% software for edf conversion
if ismac
    edf2asc_dir = '/Applications/Eyelink/EDF_Access_API/Example';
    end_file = '';
elseif ispc 
    edf2asc_dir = 'C:\Experiments\natImSacCtr\stats\';
    end_file ='.exe';
end

for t_run = 1:num_run
    
    % get data
    mat_filename = sprintf('%s/add/%s_matFile.mat',file_dir,list_filename{t_run});
    load(mat_filename);
    edf_filename = sprintf('%s/func/%s_eyeData',file_dir,list_filename{t_run});
    
    % get .msg and .dat file
    if ~exist(sprintf('%s_left.dat',edf_filename),'file') || ~exist(sprintf('%s_left.msg',edf_filename),'file')
        [~,~] = system(sprintf('%s/edf2asc%s %s.edf -e -y',edf2asc_dir,end_file,edf_filename));
        movefile(sprintf('%s.asc',edf_filename),sprintf('%s_left.msg',edf_filename));
        [~,~] = system(sprintf('%s/edf2asc%s %s.edf -s -l -miss -1.0 -y',edf2asc_dir,end_file,edf_filename));
        movefile(sprintf('%s.asc',edf_filename),sprintf('%s_left.dat',edf_filename));
    end
    
    % get stim time stamps
    run_onset = [];
    run_offset = [];
    msgfid = fopen(sprintf('%s_left.msg',edf_filename),'r');
    record_stop = 0;
    while ~record_stop
        line_read = fgetl(msgfid);
        if ~isempty(line_read)                           % skip empty lines
            la = textscan(line_read,'%s');
            % get first time
            if size(la{1},1) > 5
                if strcmp(la{1}(3),'TR') && strcmp(la{1}(4),'num') && strcmp(la{1}(5),'1') && strcmp(la{1}(6),'stopped')
                    run_onset = [run_onset;str2double(la{1}(2))];
                end
                if strcmp(la{1}(3),'TR') && strcmp(la{1}(4),'num') && strcmp(la{1}(5),'500') && strcmp(la{1}(6),'stopped')
                    run_offset = [run_offset;str2double(la{1}(2))];
                    record_stop = 1;
                end
            end
        end
    end
    fclose(msgfid);
    
    % load eye coord data
    datafid_left  = fopen(sprintf('%s_left.dat',edf_filename),'r');
    eye_dat_left = textscan(datafid_left,'%f%f%f%f%s');
    eye_data_left = [eye_dat_left{1},eye_dat_left{2},eye_dat_left{3},eye_dat_left{4}];

    % get corresponding data
    datapix_left  = transpose(eye_data_left(eye_data_left(:,1) >= run_onset & eye_data_left(:,1) <= run_offset,:));
    
    % convert datapix to data in degrees from screen center
    screen_size = [config.scr.scr_sizeX,config.scr.scr_sizeY];
    ppd = config.const.ppd;

    res(t_run).data_left = datapix_left;
    res(t_run).data_left(2,:) = (res(t_run).data_left(2,:) - (screen_size(1)/2))/ppd;
    res(t_run).data_left(3,:) = (-1*(res(t_run).data_left(3,:) - screen_size(2)/2))/ppd;
    
    % blink time for left eye
    blink_start = 0;
    blinkNum = 0;
    blink_onset_offset = [];
    for tTime = 1:size(datapix_left,2)
        if ~blink_start
            if datapix_left(2,tTime)==-1
                blinkNum = blinkNum + 1;
                timeBlinkOnset = datapix_left(1,tTime);
                blink_start = 1;
                blink_onset_offset(blinkNum,:) = [timeBlinkOnset,NaN];
            end
        end
        if blink_start
            if datapix_left(2,tTime)~=-1
                timeBlinkOfffset = datapix_left(1,tTime);
                blink_start = 0;
                blink_onset_offset(blinkNum,2) = timeBlinkOfffset;
            end
        end
    end
    res(t_run).blink_left = blink_onset_offset;

    % plot data
    if plot_res == 1
        plot(res(t_run).data_left(2,:),-res(t_run).data_left(3,:),'k');
        pause(2);
        hold off;
    end

    fclose(datafid_left);
    delete(sprintf('%s_left.msg',edf_filename))
    delete(sprintf('%s_left.dat',edf_filename))

end
file_dir = sprintf('%s/data/%s',cd,subject);
save(sprintf('%s/%s_resmat.mat',file_dir,subject),'res')

end