
%% instructions



%% script

clear

run = 'y';
trow = 0;

while run == 'y' 
    trow  = trow + 1;
    FullPath = '';
    while isempty(FullPath)         %getting file
        [FileName,PathName] = uigetfile('/Users/andysabo/Library/CloudStorage/GoogleDrive-asabo@bu.edu/.shortcut-targets-by-id/1JFj7IHPTVApFOT8rmEDZNLNh2Y8jhnQE/20230304 Fourth blood bag/2 Wood High Speed/*.*', 'Select Video');
        FullPath = strcat(PathName,FileName);
        pause(.5);
    end

    file_type = FullPath(end-2:end);
    close all
    fprintf('\n\n')

    %name info for excel file rows
    half = strsplit(FullPath, 'Hematocrit ');
    third = strsplit(half{2}, '/');
    fourth = strsplit(third{3}, '_');
    
    hem = strcat('hem', half{2}(1));
    rh = erase(third{2}, ' ');
    surface = fourth{2};
    tnumber = fourth{5};
    

    vid = VideoReader(FullPath);
    in = 'n';
    i = 1;

    %change these depending on video specifications
    framerate = 2000;
    pixels = 105.5;
    mm = 2.08;
    pixel2mm = mm/pixels;

    round = 0;
    rad = 0;

    %frame by frame loop
    while in ~= 'e'
            frame  = read(vid, i);
            
            %save first frame
            if i == 1
                frame1 = frame;
            end
    
            [radt, roundt] = findrad(frame, pixel2mm);
            fprintf('Roundness: %f\n', roundt)
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


    end

    maxd = 0;
    while in == 'e'
        frame = read(vid, i);
            
            %imshow(frame)
            %pause(.5)

        newframe = frame1-frame;
            
            %imshow(newframe)
            %pause(.5)

        framechange = rgb2gray(newframe)>70;
        [r, c] = size(framechange);
        framechange(1:r/2, 1:c) = zeros(r/2, c);
        
            %imshow(framechange)
            %pause(.5)

        [row, col] = find(framechange==1);
        left = min(col);
        right = max(col);
        diameter = pixel2mm*(right - left);

            imshow(labeloverlay(frame,framechange))

        if diameter > maxd
            maxd = diameter;
            maxdframe = i;
        end
        if diameter < maxd
            in = 'x';
        end
        i = i+1;

    end

    %find frame number
    numpic = imresize(frame1(32:48, 838:891), 10);
    imshow(numpic)
    ocrResults = ocr(numpic);
    actualframeno = str2num(ocrResults.Text(find(~isspace(ocrResults.Text))))

    pause(1)

    actimpactframe = impactframe - abs(actualframeno) - 2;
    actmaxdframe = maxdframe - abs(actualframeno) - 1;

    data(trow) = struct(Hematocrit = hem, RH = rh, Surface = surface, Trial = tnumber, File = FileName, Impact_Frame = actimpactframe, Max_Diameter_Frame = actmaxdframe, Max_Diameter = maxd);
    tab = struct2table(data(trow))



    %clearvars -except data trow hem rh surface

    prompt = "another file? (y/n) \n";
    run = input(prompt, "s");
    
end

%%
    excelname = strcat('D_',surface, '_', hem, '_', rh, '.xlsx');
    writetable(struct2table(data), excelname);

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
        fprintf('no reading')
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

