%% Classification
%% Clean the workspace

clc
close all
clear variables

addpath('GLCM Final/') 
%% Parameters

% Scene settings
sceneFolderPath = 'imatges/Samples2/scenes';
sceneNames = {'scene1.png', 'scene2.png', 'scene3.png', 'scene4.png', 'scene5.png', 'scene6.png', 'scene7.png'};

% Sample settings
sampleFolderPathField = 'imatges/Samples2/camps'; % For now using 40x40 sample images
sampleFolderPathTree = 'imatges/Samples2/arbrets'; % For now using 40x40 sample images
sampleRot = 2; % Number of rotations to compute (1 - 4)

% Co-matrix settings
cmHSV = false; % If true, use saturation instead of grayscale
cmHSVchannel = 1; % HSV channel to use (Hue 1, Saturation 2, Value 3)
cmGF = 1.5; % Apply Gaussian blur to sample and scene
cmGL = 5; % Gray levels 
cmDist = 2;
cmDir = [1 1; -1 1];
%cmDir = [0 1; 1 0; 1 1; -1 1];
cmSym = true; % Symmetric (offsets [1 0] == [-1 0])
cmProps = {"Contrast", "Correlation", "Energy", "Homogeneity"};

% Sliding Window settings
swStep = 5;

% Classification settings
classWeight = 0.1; % Classification bias (0 Field always wins, 1 Tree always wins)
%Field
nbestField = 0; % Show best nbest cases. If 0, show cases better than threshold.
thrField = 0.4;
%Tree
nbestTree = 0; % Show best nbest cases. If 0, show cases better than threshold.
thrTree = 0.3;

% Presentation settings
maskAlpha = 0.65;
showSampleHist = true; % Show histograms on samples' props
showSceneHist = false; % Show histograms on scenes
showSceneMask = true; % Show partial masks on scenes
exportImages = false; % Export all generated figures to exportPath
exportPath = 'figureOut/';
%% Load sample filepaths

% Fields
sampleImdsField = imageDatastore(sampleFolderPathField);

sampleFilesField = size(sampleImdsField.Files, 1);
sampleCasesField = sampleFilesField*sampleRot;

% Tree
sampleImdsTree = imageDatastore(sampleFolderPathTree);

sampleFilesTree = size(sampleImdsTree.Files, 1);
sampleCasesTree = sampleFilesTree*sampleRot;

% Check export path folder exists if using it
if exportImages && ~exist(exportPath,'dir')
    mkdir(exportPath);
end
%% Process samples

% Field
samplePropsField = NaN(size(cmProps, 2), size(cmDir, 1), sampleCasesField);
for sf = 1:sampleFilesField

    sampleImg = readimage(sampleImdsField, sf);

    if cmHSV == false
        sampleImg2 = im2gray(sampleImg);
    else
        sampleImg2 = rgb2hsv(sampleImg);
        sampleImg2 = sampleImg2(:,:,cmHSVchannel);
    end

    if cmGF ~= 0
        sampleImg2 = imgaussfilt(sampleImg2, cmGF);
    end

    for rot = 1:sampleRot
        sampleImg2Rot = rot90(sampleImg2, rot-1);
        samplePropsField(:, :, (sf-1)*sampleRot+rot) = extractFeaturesGLCM(sampleImg2Rot, cmDir*cmDist, cmSym, cmProps, cmGL);
    end
end

% Tree
samplePropsTree = NaN(size(cmProps, 2), size(cmDir, 1), sampleCasesTree);
for sf = 1:sampleFilesTree

    sampleImg = readimage(sampleImdsTree, sf);

    if cmHSV == false
        sampleImg2 = im2gray(sampleImg);
    else
        sampleImg2 = rgb2hsv(sampleImg);
        sampleImg2 = sampleImg2(:,:,cmHSVchannel);
    end

    if cmGF ~= 0
        sampleImg2 = imgaussfilt(sampleImg2, cmGF);
    end

    for rot = 1:sampleRot
        sampleImg2Rot = rot90(sampleImg2, rot-1);
        samplePropsTree(:, :, (sf-1)*sampleRot+rot) = extractFeaturesGLCM(sampleImg2Rot, cmDir*cmDist, cmSym, cmProps, cmGL);
    end
end
%% Sample properties

if showSampleHist == true

% Field
figure,
tiledlayout('flow'), sgtitle(sprintf('(Field) GLCM properties using %i samples in %i orientations', sampleFilesField, sampleRot));
for sp = 1:size(cmProps, 2)
    nexttile,
    histogram(samplePropsField(sp,:,:)), title(cmProps{1,sp});
end
if exportImages, exportgraphics(gcf, [exportPath, sprintf('Samples - Field - GLCM properties using %i samples in %i orientations', sampleFilesField, sampleRot), '.png']); end

% Tree
figure,
tiledlayout('flow'), sgtitle(sprintf('(Tree) GLCM properties using %i samples in %i orientations', sampleFilesTree, sampleRot));
for sp = 1:size(cmProps, 2)
    nexttile,
    histogram(samplePropsTree(sp,:,:)), title(cmProps{1,sp});
end
if exportImages, exportgraphics(gcf, [exportPath, sprintf('Samples - Tree - GLCM properties using %i samples in %i orientations', sampleFilesField, sampleRot), '.png']); end

end
%% Begin scene loop

for sceneNum = 1:length(sceneNames)
%% Process scene

sceneImg = imread([sceneFolderPath '/' sceneNames{sceneNum}]);

if cmHSV == false
    sceneImg2 = im2gray(sceneImg);
else
    sceneImg2 = rgb2hsv(sceneImg);
    sceneImg2 = sceneImg2(:,:,cmHSVchannel);
end

if cmGF ~= 0
    sceneImg2 = imgaussfilt(sceneImg2, cmGF);
end
%% Compute errors

swSize = size(sampleImg2); % Sliding window must match sample size
sceneSize = size(sceneImg2);

swNumY = floor( (sceneSize(1)-swSize(1)) / swStep );
swOffsetsY = swStep*(1:swNumY);

swNumX = floor( (sceneSize(2)-swSize(2)) / swStep );
swOffsetsX = swStep*(1:swNumX);

%tic
errField = NaN(swNumY, swNumX, sampleCasesField);
errTree = NaN(swNumY, swNumX, sampleCasesTree);
parfor ny = 1:swNumY
    for nx = 1:swNumX

        y = swOffsetsY(ny);
        x = swOffsetsX(nx);

        swSample = sceneImg2(y:(y+swSize(1)-1), x:(x+swSize(2)-1));
        swProps = extractFeaturesGLCM(swSample, cmDir*cmDist, cmSym, cmProps, cmGL);

        for sc = 1:sampleCasesField
            errField(ny, nx, sc) = sum( abs(samplePropsField(:,:,sc) - swProps), 'all');
        end
        for sc = 1:sampleCasesTree
            errTree(ny, nx, sc) = sum( abs(samplePropsTree(:,:,sc) - swProps), 'all');
        end

    end
end
%toc
%% Find matching cases

% Field
if nbestField ~= 0
    bestThr = sort(errField(:));
    thrField = bestThr(nbestField);
end

if showSceneHist == true
figure,
histogram(errField(:,:,:)), xline(thrField), xlabel('Error'), ylabel('Cases'),
title(sprintf('[Scene %i] (Field) Found %i cases for threshold %.4f', sceneNum, sum(errField(:) <= thrField), thrField));

if exportImages, exportgraphics(gcf, [exportPath, sprintf('Scene %i - Field - Found %i cases for threshold %.4f', sceneNum, sum(errField(:) <= thrField), thrField), '.png']); end
end

% Tree
if nbestTree ~= 0
    bestThr = sort(errTree(:));
    thrTree = bestThr(nbestTree);
end

if showSceneHist == true
figure,
histogram(errTree(:,:,:)), xline(thrTree), xlabel('Error'), ylabel('Cases'),
title(sprintf('[Scene %i] (Tree) Found %i cases for threshold %.4f', sceneNum, sum(errField(:) <= thrTree), thrTree));

if exportImages, exportgraphics(gcf, [exportPath, sprintf('Scene %i - Tree - Found %i cases for threshold %.4f', sceneNum, sum(errField(:) <= thrTree), thrTree), '.png']); end
end

%tic
maskField = false(sceneSize(1), sceneSize(2), sampleCasesField);
maskTree = false(sceneSize(1), sceneSize(2), sampleCasesTree);
for ny = 1:swNumY
    for nx = 1:swNumX

        y = swOffsetsY(ny);
        x = swOffsetsX(nx);

        % Field
        for sc = 1:sampleCasesField
            if errField(ny, nx, sc) <= thrField    
                maskField(y:(y+swSize(1)-1), x:(x+swSize(2)-1), sc) = 1;
            end
        end
        % Tree
        for sc = 1:sampleCasesTree
            if errTree(ny, nx, sc) <= thrTree    
                maskTree(y:(y+swSize(1)-1), x:(x+swSize(2)-1), sc) = 1;
            end
        end
    end
end
%toc

maskField = sum(maskField,3);
maskTree = sum(maskTree,3);

if showSceneMask == true
figure,
imshow( labeloverlay(sceneImg, maskField, Transparency = maskAlpha)), title(sprintf('[Scene %i] (Field) Maximum detection depth is %i', sceneNum, max(maskField(:))));

if exportImages, exportgraphics(gcf, [exportPath, sprintf('Scene %i - Field - Maximum detection depth is %i', sceneNum, max(maskField(:))), '.png']); end

figure,
imshow( labeloverlay(sceneImg, maskTree, Transparency = maskAlpha)), title(sprintf('[Scene %i] (Tree) Maximum detection depth is %i', sceneNum, max(maskTree(:))));

if exportImages, exportgraphics(gcf, [exportPath, sprintf('Scene %i - Tree - Maximum detection depth is %i', sceneNum, max(maskTree(:))), '.png']); end
end
%% Combine masks

maskClass = zeros(sceneSize);
for py = 1:sceneSize(1)
    for px = 1:sceneSize(2)
        if (maskField(py, px) > 0) && (maskTree(py, px) > 0)
            if min(errField(floor(py/swSize(1))+1, floor(px/swSize(2))+1, :))*classWeight < (1-classWeight)*min(errTree(floor(py/swSize(1))+1, floor(px/swSize(2))+1, :))
                maskClass(py, px) = 1; % Field
            else
                maskClass(py, px) = 2; % Tree
            end
        elseif maskField(py, px) > 0
            maskClass(py, px) = 1; % Field
        elseif maskTree(py, px) > 0
            maskClass(py, px) = 2; % Tree
        end
    end
end

figure,
imshow( labeloverlay(sceneImg, maskClass, Transparency = maskAlpha)),
title(sprintf('[Scene %i] Result', sceneNum)), xlabel('Fields in yellow; Trees in blue');

if exportImages, exportgraphics(gcf, [exportPath, sprintf('Scene %i - Result', sceneNum), '.png']); end
%% End scene loop

end