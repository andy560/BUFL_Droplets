
%% instructions
% select multiple files at once. the script will ask if you if you would
% like to include additional batches after you select your first batch,
% that way you can pull from multiple folders. script will not work if
% batches have only 1 file. 
% 
% after batches are selected, the script creates a .mat file with the
% diameter of each droplet after impact as a function of time, under the
% name of the original file. it also creates an excel sheet with the list
% of files analyzed.


%% script

clear

morefiles = 'y';    %for determining if more batches will be selected
trow = 0;           %counts rows so that 
batch = 1;          %for organizing batches

%getting batches of files
    FullPath = '';
    while morefiles == 'y'      
        [FileName{batch},PathName] = uigetfile('/Users/andysabo/Library/CloudStorage/GoogleDrive-asabo@bu.edu/.shortcut-targets-by-id/1JFj7IHPTVApFOT8rmEDZNLNh2Y8jhnQE/20230304 Fourth blood bag/1 Glass High Speed/*.*', 'Select Video', 'MultiSelect','on');
        FullPath{batch} = strcat(PathName,FileName{batch});
        prompt = "another batch? (y/n) \n";
        morefiles = input(prompt, "s");
        batch = batch+1;
    end

    k = 0;
    for i = 1:numel(FileName)
        bigcells = numel(FileName{i})
        for j = 1:bigcells
            k = k+1;
            FNList{k} = FileName{i}{j};
            FPList{k} = FullPath{i}{j};
        end
    end

for run =  1:numel(FNList)

    trow  = trow + 1;

    close all
    fprintf('\n\n')

    %name info for excel file rows
    half = strsplit(FPList{run}, 'Hematocrit ');
    third = strsplit(half{2}, '/');
    fourth = strsplit(third{3}, '_');
    
    hem = strcat('hem', half{2}(1));
    rh = erase(third{2}, ' ');
    surface = fourth{2};
    tnumber = fourth{5};
    

    vid = VideoReader(FPList{run});
    in = 'n';
    i = 1;

    %change these depending on video specifications
    framerate = 2000;
    pixels = 105.5;
    mm = 2.08;

    pixel2mm = mm/pixels;

    round = 0;
    rad = 0;

    %frame by frame loop for before impact portion of video
    while in ~= 'e'
        if i<=vid.NumFrames
            frame  = read(vid, i);
            
            %save first frame
            if i == 1
                frame1 = frame;
            end
    
            [radt, roundt] = findrad(frame, pixel2mm);
            %fprintf('Roundness: %f\n', roundt)
            if roundt >= 1
                %disp('error: roundness value > 1\n')
            end
            if roundt > round && roundt < 1
                round = roundt;
                rad = radt;
            end
    
            i = i+1;
    
            if roundt == 0 && round > 0 && i>15
                in = 'e';
            end
    
            if in == 'e'
                impactframe = i;
            end
        elseif i>vid.NumFrames
            maxd = 'N/A';
            maxdframe = 'N/A';
            impactframe = 'N/A';
            in = 'e';
        end


    end

    maxd = 0;
    y = 0;
    diameter = zeros(1, vid.NumFrames - i + 1);
    x = 0:1/2000 : (numel(diameter)-1)/2000;

    %frame by frame for post impact portion of video
    while in == 'e' 
        if i<=vid.NumFrames
            y = y+1;
           
            frame = read(vid, i);
                
                %uncomment to show steps
                %imshow(frame) 
                %pause(.5)
    
            newframe = frame1-frame;
                
                %uncomment to show steps
                %imshow(newframe)
                %pause(.5)
    
            framechange = rgb2gray(newframe)>70;
            [r, c] = size(framechange);
            framechange(1:r/2, 1:c) = zeros(r/2, c);
            
                %uncomment to show steps
                %imshow(framechange)
                %pause(.5)
    
            [row, col] = find(framechange==1);
            left = min(col);
            right = max(col);
            diameter(y) = pixel2mm*(right - left);
    
                imshow(labeloverlay(frame,framechange))
            i = i+1;
    
        else
            in = 'x';
        end
    end

    plot(x, diameter, 'r-')
    pause(1)
    graph_file = strcat('/Users/andysabo/Library/CloudStorage/GoogleDrive-asabo@bu.edu/.shortcut-targets-by-id/1JFj7IHPTVApFOT8rmEDZNLNh2Y8jhnQE/20230304 Fourth blood bag/MAT Files - Glass/', FNList{run}(1:end-4), '.mat');
    graphdat = [x; diameter];
    save(graph_file, 'graphdat');



    %find frame number
    numpic = imresize(frame1(32:48, 838:891), 10);
    imshow(numpic)
    ocrResults = ocr(numpic);
    actualframeno = str2num(ocrResults.Text(find(~isspace(ocrResults.Text))));

    %pause(.5)

    
    data(trow) = struct(Hematocrit = hem, RH = rh, Surface = surface, Trial = tnumber, File = FNList{run});


    
end

%%
    excelname = strcat('G2_',surface, '_', hem, '_', rh, '.xlsx');
    writetable(struct2table(data), excelname);
    fprintf('\n\n%s\n\n', excelname)

clf

%% functions

function [rad, round] = findrad(img, pixel2mm)
    
    img = rgb2gray(img);


    %detect edges
    [~, threshold] = edge(img,'sobel');
    fudgeFactor = .5;
    BWs = edge(img,'sobel',threshold * fudgeFactor);

    se90 = strel('diamond',2);
    BWs = imdilate(BWs,se90);

    %fill holes
    BWdfill = imfill(BWs,'holes');

    %remove selections on image border
    BWnobord = imclearborder(BWdfill,4);
  
    % remove noise
    BWfinal = bwareaopen(BWnobord, 7000);

    %trim
    seD = strel('diamond',2);
    BWfinal = imerode(BWfinal,seD);

    %show selection as mask
    imshow(labeloverlay(img,BWfinal))
    %pause(.1)
    hold off

    area = (pixel2mm^2) * sum(sum(BWfinal));
    rad = (area/pi)^.5;


    %roundness
    [r, c] = size(BWfinal);
    col = 1;
    row = 1;
    area = sum(sum(BWfinal));
    if area == 0
        %fprintf('no reading')
        rad = 0;
        round = 0;
    else
        while BWfinal(row, col) == 0
            if col < c
                col = col+1;
            elseif col == c && row < r
                row = row +1;
                col = 1;
            end
        end
        boundary1 = bwtraceboundary(BWfinal,[row, col],'N');
        %plot(boundary1(:,2),boundary1(:,1),'g','LineWidth',2);

        %perimeter
        [r1, ~] = size(boundary1);
        perimeter1 = 0;
        for i=1:r1-1
	        dx = boundary1(i, 1) - boundary1(i+1, 1);
            dy = boundary1(i, 2) - boundary1(i+1, 2);
            dl = sqrt(dx^2+dy^2);
            perimeter1 = perimeter1 + dl;
        end
        round = 4*pi*area/perimeter1^2;
    end
end

