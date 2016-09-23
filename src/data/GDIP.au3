#include-once

Global $GDIP_STATUS = 0
Global Const $GDIP_LF_FACESIZE = 32

Func _GDIPlus_PrivateCollectionCreate()
    Local $aResult = DllCall($__g_hGDIPDll, "uint", "GdipNewPrivateFontCollection", "int*", 0)

    If @error Then Return SetError(@error, @extended, 0)
    $GDIP_STATUS = $aResult[0]
    Return $aResult[1]
EndFunc   ;==>_GDIPlus_PrivateCollectionCreate

Func _GDIPlus_PrivateCollectionAddFontFile($hFontCollection, $sFileName)
    Local $aResult = DllCall($__g_hGDIPDll, "uint", "GdipPrivateAddFontFile", "hwnd", $hFontCollection, "wstr", $sFileName)

    If @error Then Return SetError(@error, @extended, False)
    $GDIP_STATUS = $aResult[0]
    Return $aResult[0] = 0
EndFunc   ;==>_GDIPlus_PrivateCollectionAddFontFile

Func _GDIPlus_FontCollectionGetFamilyList($hFontCollection)
    Local $iI, $iCount, $tFontFamilies, $pFontFamilies, $aFontFamilies[1], $aResult

    $iCount = _GDIPlus_FontCollectionGetFamilyCount($hFontCollection)
    If @error Then Return SetError(@error, @extended, -1)

    If $GDIP_STATUS Then
        $GDIP_ERROR = 1
        Return -1
    ElseIf $iCount = 0 Then
        $GDIP_ERROR = 2
        Return -1
    EndIf

    $tFontFamilies = DllStructCreate("hwnd[" & $iCount & "]")
    $pFontFamilies = DllStructGetPtr($tFontFamilies)
    $aResult = DllCall($__g_hGDIPDll, "uint", "GdipGetFontCollectionFamilyList", "hwnd", $hFontCollection, "int", $iCount, "ptr", $pFontFamilies, "int*", 0)
    If @error Then Return SetError(@error, @extended, -1)

    $GDIP_STATUS = $aResult[0]
    If $GDIP_STATUS Then
        $GDIP_ERROR = 3
        Return -1
    EndIf

    ReDim $aFontFamilies[$iCount + 1]
    $aFontFamilies[0] = $iCount
    For $iI = 1 To $iCount
        $aFontFamilies[$iI] = DllStructGetData($tFontFamilies, 1, $iI)
    Next

    Return $aFontFamilies
EndFunc   ;==>_GDIPlus_FontCollectionGetFamilyList

Func _GDIPlus_FontCollectionGetFamilyCount($hFontCollection)
    Local $aResult = DllCall($__g_hGDIPDll, "uint", "GdipGetFontCollectionFamilyCount", "hwnd", $hFontCollection, "int*", 0)

    If @error Then Return SetError(@error, @extended, 0)
    $GDIP_STATUS = $aResult[0]
    Return $aResult[2]
EndFunc   ;==>_GDIPlus_FontCollectionGetFamilyCount

Func _GDIPlus_FontFamilyGetFamilyName($hFontFamily, $iLANGID = 0)
    Local $tName, $pName, $sName, $aResult

    $tName = DllStructCreate("wchar[" & $GDIP_LF_FACESIZE & "]")
    $pName = DllStructGetPtr($tName)
    $aResult = DllCall($__g_hGDIPDll, "uint", "GdipGetFamilyName", "hwnd", $hFontFamily, "ptr", $pName, "ushort", $iLANGID)

    If @error Then Return SetError(@error, @extended, 0)
    $GDIP_STATUS = $aResult[0]
    If $GDIP_STATUS Then Return 0

    $sName = DllStructGetData($tName, 1)
    Return $sName
EndFunc   ;==>_GDIPlus_FontFamilyGetFamilyName

Func _GDIPlus_FontFamilyIsStyleAvailable($hFontFamily, $iStyle)
    Local $aResult = DllCall($__g_hGDIPDll, "uint", "GdipIsStyleAvailable", "hwnd", $hFontFamily, "int", $iStyle, "int*", 0)

    If @error Then Return SetError(@error, @extended, 0)
    $GDIP_STATUS = $aResult[0]
    Return $aResult[3]
EndFunc   ;==>_GDIPlus_FontFamilyIsStyleAvailable


Func _GDIPlus_GraphicsDrawStringColorFromFileFont($hGraphics, $sString, $nX, $nY, $sFontFilename, $nSize = 10, $iFormat = 0, $iBrush = 0xFF000000)
    Local $hBrush, $iError, $hFamily, $hFont, $hFormat, $aInfo, $tLayout, $bResult

    $hBrush = _GDIPlus_BrushCreateSolid($iBrush)
    $hFormat = _GDIPlus_StringFormatCreate($iFormat)
    $hCollection = _GDIPlus_PrivateCollectionCreate()
    _GDIPlus_PrivateCollectionAddFontFile($hCollection, $sFontFilename)
    $aList = _GDIPlus_FontCollectionGetFamilyList($hCollection)
    $hFamily = DllCall($__g_hGDIPDll, 'int', 'GdipCreateFontFamilyFromName', 'wstr', _GDIPlus_FontFamilyGetFamilyName($aList[1]), 'ptr', $hCollection, 'ptr*', 0)
    $hFamily = $hFamily[3]
    $iStyle = 0
    For $i = 0 To 2
        If _GDIPlus_FontFamilyIsStyleAvailable($hFamily, $i) Then
            $iStyle = $i
            ExitLoop
        EndIf
    Next
    $hFont = _GDIPlus_FontCreate($hFamily, $nSize, $iStyle)

    $tLayout = _GDIPlus_RectFCreate($nX, $nY, 0, 0)
    $aInfo = _GDIPlus_GraphicsMeasureString($hGraphics, $sString, $hFont, $tLayout, $hFormat)
    $bResult = _GDIPlus_GraphicsDrawStringEx($hGraphics, $sString, $hFont, $aInfo[0], $hFormat, $hBrush)
    $iError = @error

    _GDIPlus_FontDispose($hFont)
    _GDIPlus_FontFamilyDispose($hFamily)
    _GDIPlus_StringFormatDispose($hFormat)
    _GDIPlus_BrushDispose($hBrush)

    Return SetError($iError, 0, $bResult)
EndFunc

Func _GDIPlus_GraphicsDrawStringColor($hGraphics, $sString, $nX, $nY, $sFont = "Arial", $nSize = 10, $iFormat = 0, $iBrush = 0xFF000000)
    Local $hBrush, $iError, $hFamily, $hFont, $hFormat, $aInfo, $tLayout, $bResult

    $hBrush = _GDIPlus_BrushCreateSolid($iBrush)
    $hFormat = _GDIPlus_StringFormatCreate($iFormat)
    $hFamily = _GDIPlus_FontFamilyCreate($sFont)
    $hFont = _GDIPlus_FontCreate($hFamily, $nSize)
    $tLayout = _GDIPlus_RectFCreate($nX, $nY, 0, 0)
    $aInfo = _GDIPlus_GraphicsMeasureString($hGraphics, $sString, $hFont, $tLayout, $hFormat)
    $bResult = _GDIPlus_GraphicsDrawStringEx($hGraphics, $sString, $hFont, $aInfo[0], $hFormat, $hBrush)
    $iError = @error

    _GDIPlus_FontDispose($hFont)
    _GDIPlus_FontFamilyDispose($hFamily)
    _GDIPlus_StringFormatDispose($hFormat)
    _GDIPlus_BrushDispose($hBrush)

    Return SetError($iError, 0, $bResult)
EndFunc