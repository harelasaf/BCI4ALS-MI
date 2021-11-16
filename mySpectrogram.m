function mySpectrogram(t,f,totalSpect,numClasses, chans, EEG_chans)
% mySpectrogram takes the timevector (t), frequency vector (f), and power
% vector (totalSpect) and plots them for each class and channel.
% Effectively running over channels in 'chans' and displaying in a subplot 
% the mean spectrogram for each class. The input arguments are computed 
% outside of the function. 

% This function is part of the BCI4ALS course, written by Asaf Harel 2021.
% Feel free to use and change as you wish, but please cite properly if
% published.

% "t" - time vector / samples (vector)
% "f" - frequency vector (vector)
% "totalSpect" - power of each frequency over each time point (matrix)
% "chans" - which channels are plotted (vector)
% "EEG_chans" - names of EEG electrodes (string)

for index = 1:length(chans)
    elect = chans(index);                               % electrode number
    figure('name','Spectrogram');                       % open a figure
    sgtitle(strcat('Electrode:',EEG_chans(elect,:)));   % current figure title
    for class = 1:numClasses
        subplot(numClasses-1,2,class);                  % which subplot is being populated
        surf(t,f,10*log10(squeeze(totalSpect(elect,class,:,:))),'EdgeColor','none','FaceAlpha',0.5);
        % "surf" is a Matlab function used to create a 3D colored surface
        xlabel('Time'); ylabel('Frequency'); zlabel('PSD');     % define title for each dimension
        title(strcat('Class:', num2str(class)));                % define title for each subplot
        colormap jet                                            % nice colors!
        ax=gca;                                                 % get axis parameters
        colorlim = get(ax,'clim');                              % define a color limit
        newlim = [(colorlim(1)*0.8),colorlim(2)];               % these limits can be changed, but not necessary
        set(ax,'clim',(newlim)); 
        colorbar;                                               % add a color legend
    end
    %% This is used to create a subplot which shows the difference between two classes:
    subplot(numClasses-1,2,class+1);
    surf(t,f,real(10*log10(squeeze(totalSpect(elect,2,:,:)) - squeeze(totalSpect(elect,1,:,:)))),'EdgeColor','none','FaceAlpha',0.5);
    xlabel('Time'); ylabel('Frequency'); zlabel('PSD');
    title('Left Class - Right Class');
    colormap jet
    ax=gca;
    colorlim = get(ax,'clim');
    newlim = [(colorlim(1)*0.8),colorlim(2)];
    set(ax,'clim',(newlim));
    colorbar;
end