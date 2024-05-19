function [funcProps, funcCM] = extractFeaturesGLCM(funcImgGs, funcOffset, cmSym, funcProps, cmGL)

    funcCM = graycomatrix(funcImgGs, Offset = funcOffset, Symmetric = cmSym, NumLevels = cmGL);
    
    funcProps = graycoprops(funcCM, funcProps);
    funcProps = cell2mat(struct2cell(funcProps));

end