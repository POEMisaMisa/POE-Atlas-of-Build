#include-once

; #INDEX# =======================================================================================================================
; Title .........: CodeQR barcode generator
; AutoIt Version : 3.3.12.0
; Description ...: Create a QR Code from supplied data
; Author(s) .....: David Williams (willichan)
; Dll ...........: quricol32.dll (http://delphi32.blogspot.it/2011/11/quricol-qr-code-generator-library.html)
; ===============================================================================================================================

; #CURRENT# =====================================================================================================================
;_BcodeQR_GenCode
; ===============================================================================================================================

; #INTERNAL_USE_ONLY# ===========================================================================================================
;__BcodeQR_FixResolution
;__BcodeQR_BitmapSetResolution
; ===============================================================================================================================

; #VARIABLES# ===================================================================================================================
; ===============================================================================================================================

; #CONSTANTS# ===================================================================================================================
; ===============================================================================================================================

#include <file.au3>
#include <GDIPlus.au3>

; #FUNCTION# ====================================================================================================================
; Name ..........: _BcodeQR_GenCode
; Description ...:
; Syntax ........: _BcodeQR_GenCode($sData[, $sOutFile = Default[, $iModuleSize = Default[, $iBorderSize = Default[,
;                  $vErrorCorrect = Default[, $iDPI = Default[, $sDllPath = Default]]]]]])
; Parameters ....: $sData               - A string value to encode into a QR Code
;                  $sOutFile            - [optional] Where to write out the BMP file. Default is to create a random temp file
;                                         0 = Copy to the clipboard (planned, but not yet implemented)
;                                         1 = Create a randomly named temp file (Default)
;                                         String = Write to specified path\filename (assumes valid path and filename)
;                  $iModuleSize         - [optional] Size of QR Code Module (square dots) specified in Pixels.  Default is 2.
;                  $iBorderSize         - [optional] Width of the border (rest space) around the QR Code.  Default is twice the Module Size.
;                  $vErrorCorrect       - [optional] Error Correction Level, or how much dammage can be recovered.  Default is 1.
;                                         0 or L = Low (7%)
;                                         1 or M = Medium (15%)
;                                         2 or Q = Quality (25%)
;                                         3 or H = High (30%)
;                  $iDPI                - [optional] The dots-per-inch setting for the BMP file.  Default is 96
;                  $sDllPath            - [optional] Path to quricol32.dll.  Default assumes in current folder or search path.
; Return values .: String containing the location and name of the BMP file created, or "" if copied to the clipboard.
; Author ........: David E Williams (willichan)
; Modified ......:
; Remarks .......: Copying to the clipboard is not yet implemented.  Random temp file will be made instead.
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _BcodeQR_GenCode($sData, $bgColor, $fgColor, $sOutFile = Default, $iModuleSize = Default, $iBorderSize = Default, $vErrorCorrect = Default, $iDPI = Default, $sDllPath = Default)
	Local $hDll
	If (not IsString($sData)) Or (StringLen($sData) < 1) Then Return ""
	;;Set defaults
	If IsNumber($sOutFile) Then $sOutFile = 1 ;;; *** treat any number like a temp file, in case the user messed up ***
	If ($sOutFile = Default) Or ($sOutFile = 1) Then $sOutFile = _TempFile(@TempDir, "~", ".bmp", 7)
	If $iModuleSize = Default Then $iModuleSize = 2
	If $iBorderSize = Default Then $iBorderSize = 2 * $iModuleSize
	If $vErrorCorrect = Default Then
		$vErrorCorrect = 'M'
	Else
		Switch StringLower($vErrorCorrect)
			Case '0', 'l', 'low'
				$vErrorCorrect = 'L'
			Case '1', 'm', 'medium'
				$vErrorCorrect = 'M'
			Case '2', 'q', 'quality'
				$vErrorCorrect = 'Q'
			Case '3', 'h', 'high'
				$vErrorCorrect = 'H'
			Case Else
				Return ""
		EndSwitch
	EndIf
	If $iDPI = Default Then $iDPI = 96
	If $sDllPath = Default Then
		$sDllPath = "data\quricol"
		If @AutoItX64 Then
			$sDllPath &= "64.dll"
		Else
			$sDllPath &= "32.dll"
		EndIf
	EndIf

	;initialize
	$hDll = DllOpen($sDllPath)
	
	DllCall($hDll, "none", "SetBackgroundColor", "int", $bgColor)
	DllCall($hDll, "none", "SetForegroundColor", "int", $fgColor)
	
	If $hDll = -1 Then Return ""

	;generate
	If FileExists($sOutFile) Then FileDelete($sOutFile)
	DllCall($hDll, "none", "GenerateBMP", "str", $sOutFile, "str", $sData, "int", $iBorderSize, "int", $iModuleSize, "int", $vErrorCorrect)
	__BcodeQR_FixResolution($sOutFile, $iDPI)

	;closeout
	DllClose($hDll)
EndFunc

; #INTERNAL_USE_ONLY# ===========================================================================================================
; Name ..........: __BcodeQR_FixResolution
; Description ...:
; Syntax ........: __BcodeQR_FixResolution($sOutFile, $iDPI)
; Parameters ....: $sOutFile            - Bitmap file path
;                  $iDPI                - Dots Per Inch setting to give the bitmap file
; Return values .: None
; Author ........:
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func __BcodeQR_FixResolution($sOutFile, $iDPI)
	_GDIPlus_Startup()
	Local $hImage = _GDIPlus_BitmapCreateFromFile($sOutFile)
	Local $aResult = __BcodeQR_BitmapSetResolution($hImage, $iDPI, $iDPI)
	Local $Ext = _GDIPlus_EncodersGetCLSID("bmp")
	Local $Status = _GDIPlus_ImageSaveToFileEx($hImage, $sOutFile, $Ext, 0)
	_GDIPlus_ImageDispose($hImage)
	_GDIPlus_Shutdown()
EndFunc   ;==>__FixResolution

; #INTERNAL_USE_ONLY# ===========================================================================================================
; Name ..........: __BcodeQR_BitmapSetResolution
; Description ...: Sets the resolution of this Bitmap object
; Syntax ........: __BcodeQR_BitmapSetResolution($hBitmap, $nDpiX, $nDpiY)
; Parameters ....: $hBitmap             - Pointer to the Bitmap object
;                  $nDpiX               - Horizontal resolution in dots per inch
;                  $nDpiY               - Vertical resolution in dots per inch
; Return values .: Success              - True
;                  Failure              - False
; Author ........:
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........: @@MsdnLink@@ GdipBitmapSetResolution
; Example .......: No
; ===============================================================================================================================
Func __BcodeQR_BitmapSetResolution($hBitmap, $nDpiX, $nDpiY)
	Local $aResult = DllCall($__g_hGDIPDll, "uint", "GdipBitmapSetResolution", "hwnd", $hBitmap, "float", $nDpiX, "float", $nDpiY)
	Local $err = @error
	Local $Ext = @extended
	Local $GDIP_STATUS = $aResult[0]
	Return SetError($err, $Ext, False)
	Return $aResult[0] = 0
EndFunc   ;==>_GDIPlus_BitmapSetResolution
