[listOfFolderNames, listOfFileNames, ~] = find_files(".tif");
for i = 1:length(listOfFolderNames)
addpath(listOfFolderNames{i})
end
data_table = table('Size',[0 5],'VariableTypes',{'string','double','double', 'double', 'string'});
data_table.Properties.VariableNames = ["Filename", "Center (x)", "Center (y)", "Radius (nm)", "Condition"];
metadata = table('Size',[0 4],'VariableTypes',{'string','double','double', 'double'});
metadata.Properties.VariableNames = ["Filename", "Masked center (x)", "Masked center (y)", "Masked radius (nm)"];

output_file = input("Please enter a path to save to.");
%%
for i = 1:length(listOfFileNames)
    img = imread(listOfFileNames{i});
    figure();
    %subplot(1, 2, 1);
    imshow(img);
    roi = [1214 2790 225 89];
    if (roi(2) > size(img, 1) || roi(1) > size(img, 2))
        ocrResults = ocr(img,[1, 1, 1, 1]);
    else
        ocrResults = ocr(img,roi);
    end

    if (size(ocrResults.Words, 1) == 0 || ocrResults.Words == " ") %% Scalebar to px (Aaron)
         title("No pixel size found; please box pixel size or scalebar.")
         rectangle = drawrectangle();
         imgcropped = imcrop(img, rectangle.Position);
         figure();
         subplot(1,2,1)
         imshow(img)
         subplot(1,2,2)
         imshow(imgcropped)

         auto = input("Press 1 to read pixel size, 2 to read a scalebar");

         if (auto == 1)
             ocrResults = ocr(img,rectangle.Position, CharacterSet= "1234567890");
             pixelSize = str2num(ocrResults.Words{1});
         elseif (auto == 2)
             % Length of scale
             line = drawline ;
             ep = line.Position;
              x1 = ep(1,1); 
              y1 = ep(1,2); 
              x2 = ep(2,1); 
              y2 = ep(2,2);
            lineLength = sqrt((x2 - x1)^2 + (y2 - y1)^2);
            
            disp(lineLength)
            
            % Read measurement above scalebar
            rectangleRoi = drawrectangle ;
            pos = round(rectangleRoi.Position) ;
            unit = ocr(imgcropped, pos, CharacterSet= "1234567890" ) ;  
            recognizedText = unit.Words ;
            
            % Calculate Pixel Size
            unitofMeasure = recognizedText{1,1};
            x =  str2double(unitofMeasure);
            pixelSize = (x / lineLength * 1000);
         end
         close all
         imshow(img);
    else
        pixelSize = str2num(ocrResults.Words{1});
    end
    high = contains(lower(listOfFileNames{i}), "high");
    low = contains(lower(listOfFileNames{i}), "low");
    nitrogen = contains(lower(listOfFileNames{i}), "nitrogen");
    phosphorus = contains(lower(listOfFileNames{i}), "phosphorus");

    if high 
        label = "high";
    elseif low
        label = "low";
    elseif nitrogen
        label = "no nitrogen";
    elseif phosphorus
        label = "no phosphorus";
    else
        label = listOfFileNames{i};
    end

    if (i == 1)
        preset = input("Enter a previous circle radius (in nm), or enter 0 to draw a new circle.");
        if preset == 0
            p = drawcircle();
            center = p.Center;
            radius = p.Radius;
            radius_nm = radius * pixelSize;
        else
            radius_nm = preset;
            point = drawpoint();
            p = drawcircle('Center', point.Position,'Radius', radius_nm / pixelSize);
            center = p.Position;
            radius = p.Radius;
        end
    else
        point = drawpoint();
        p = drawcircle('Center', point.Position,'Radius', radius_nm / pixelSize);
        center = p.Position;
        radius = p.Radius;
    end

    theta = linspace(0,2*pi,200); 
    x = center(1) + radius*cos(theta);
    y = center(2) + radius*sin(theta);
    bw = createMask(p);
    mask = img;
    mask(~bw) = 0;

% % Automated Circle Finding -- does not work well :(
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% [centers, radii] = imfindcircles(img,[floor(100/pixelSize) floor(250/pixelSize)],'ObjectPolarity', ...
%     'bright','Sensitivity',0.94,'Method','twostage','EdgeThreshold',0.1);
% % [centersDark, radiiDark] = imfindcircles(img,[floor(100/pixelSize) floor(250/pixelSize)],'ObjectPolarity', ...
% %     'bright','Sensitivity',0.94,'Method','twostage','EdgeThreshold',0.1);
% % centers = [centers; centersDark];
% % radii = [radii; radiiDark];
% insideROI = inpolygon(centers(:,1), centers(:,2), x, y);
% centers(~insideROI, :) = [];
% radii(~insideROI, :) = [];
% subplot(1, 2, 2);
% imshow(mask);
% h = viscircles(centers, radii);
% 
% export = array2table([repmat(listOfFileNames{i}, size(centers, 1), 1) centers(:, 1) centers(:, 2) radii .* pixelSize repmat(label, size(centers, 1), 1)]);
% export.Properties.VariableNames = ["Filename", "Center (x)", "Center (y)", "Radius (nm)", "Condition"];
% data_table = [data_table; export];

m_export = array2table([string(listOfFileNames{i}) center(1) center(2) radius * pixelSize]);
m_export.Properties.VariableNames = ["Filename", "Masked center (x)", "Masked center (y)", "Masked radius (nm)"];
metadata = [metadata; m_export];

% Circle Drawing (Aaron)
centerX = [] ;
centerY = [] ;
radius = [] ;
while true
    try
    roi = drawcircle();
    cx = roi.Center(1) ;
    cy = roi.Center(2) ;
    centerX = [centerX; cx] ;
    centerY = [centerY; cy] ;
    r = roi.Radius ;
    radius = [radius; r] ;
    catch
        break
    end
end

% Table
circle_data = table(centerX, centerY, radius .* pixelSize) ;
circle_data.Properties.VariableNames = ["Center (x)", "Center (y)", "Radius (nm)"];
Filename = repmat(listOfFileNames{i}, size(circle_data, 1), 1);
Condition = repmat(label, size(circle_data, 1), 1);
circle_data = addvars(circle_data, Filename, 'Before',"Center (x)");
circle_data = addvars(circle_data, Condition, 'After',"Radius (nm)");
data_table = [data_table; circle_data];
writetable(data_table, output_file);
splitpath = split(output_file,"/");
splitpath(end) = strcat("metadata_", splitpath(end));
metadata_path = join(splitpath,"/");
writetable(metadata,metadata_path);
end