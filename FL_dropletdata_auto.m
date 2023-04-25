
%% instructions

% run the script. select your video file, then hit 'enter' for next frame,
% type 'r' to find radius, and 'e' once the droplet contacts the surface
% to evaluate impact velocity. if you accidentally select the wrong video
% file, press 'c' to cancel.


%% script

clear

run = 'y';
trow = 0;

while run == 'y' 
    trow  = trow + 1;
    FullPath = '';
    while isempty(FullPath)
        [FileName,PathName] = uigetfile('/Users/andysabo/Library/CloudStorage/GoogleDrive-asabo@bu.edu/.shortcut-targets-by-id/1JFj7IHPTVApFOT8rmEDZNLNh2Y8jhnQE/20230304 Fourth blood bag/1 Glass High Speed/*.*', 'Select Video');
        FullPath = strcat(PathName,FileName);
    end
    file_type = FullPath(end-2:end);
    close all
    fprintf('\n\n')

    %name info for later
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

    framerate = 2000;
    pixels = 105.5;
    mm = 2.08;
    pixel2mm = mm/pixels;

    round = 0;
    rad = 0;

    while in ~= 'e'
        frame  = read(vid, i);


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
            %velo1
            sframe = read(vid, i-4);
            eframe = read(vid, i-2);
            startpos = findcentroid(sframe);
            endpos = findcentroid(eframe);
            framediff = 2;
            velo = calcvelo(startpos, endpos, framediff, framerate, pixel2mm);

            %velo2
            sframe = read(vid, i-5);
            eframe = read(vid, i-3);
            startpos = findcentroid(sframe);
            endpos = findcentroid(eframe);
            velo2 = calcvelo(startpos, endpos, framediff, framerate, pixel2mm);

            %velo3
            sframe = read(vid, i-6);
            eframe = read(vid, i-4);
            startpos = findcentroid(sframe);
            endpos = findcentroid(eframe);
            velo3 = calcvelo(startpos, endpos, framediff, framerate, pixel2mm);

                
            data(trow) = struct(Hematocrit = hem, RH = rh, Surface = surface, Trial = tnumber, File = FileName, Radius_mm = rad, Roundness = round, ImpactVelocity_mps = velo, Velocity2 = velo2, Velocity3 = velo3);
            tab = struct2table(data(trow))
        end

        if isempty(in)
            i = i+1;
            in = 'n';
        end


    end


    clearvars -except data trow hem rh surface

    prompt = "another file? (y/n) \n";
    run = input(prompt, "s");
    
end

%%
    excelname = strcat(surface, '_', hem, '_', rh, '.xlsx');
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



function center = findcentroid(img)

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

    circle = regionprops(BWfinal,'centroid');
    center = cat(1,circle.Centroid);

end

function velo = calcvelo(startpos, endpos, framediff, framerate, pixel2mm)
    velo = (framerate/framediff) * (pixel2mm/1000) * (endpos(1,2) - startpos(1, 2));
end


    
 

