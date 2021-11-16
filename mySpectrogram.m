function mySpectrogram(t,f,totalSpect,EEG_chans,numClasses, chans)
% Run over channels in 'chans' and display in subplot the mean spectrogram for
% each class. 

for index = 1:length(chans)
    elect = chans(index);
    figure('name','Spectrogram');
    sgtitle(strcat('Electrode:',EEG_chans(elect,:)));
    for class = 1:numClasses
        subplot(numClasses-1,2,class);
        surf(t,f,10*log10(squeeze(totalSpect(elect,class,:,:))),'EdgeColor','none','FaceAlpha',0.5);
        xlabel('Time'); ylabel('Frequency'); zlabel('PSD');
        title(strcat('Class:', num2str(class)));
        colormap jet
        ax=gca;
        colorlim = get(ax,'clim');
        newlim = [(colorlim(1)*0.8),colorlim(2)];
        set(ax,'clim',(newlim));
        colorbar;
    end
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