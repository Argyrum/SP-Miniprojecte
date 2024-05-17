function [funcProps, funcCM] = extractFeaturesGLCM(funcImgGs, funcOffset, cmSym, funcProps)

    funcCM = graycomatrix(funcImgGs, Offset = funcOffset, Symmetric = cmSym);
    
    funcProps = graycoprops(funcCM, funcProps);
    funcProps = cell2mat(struct2cell(funcProps));

end