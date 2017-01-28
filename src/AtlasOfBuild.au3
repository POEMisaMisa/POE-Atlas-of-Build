#include <data\ImageSearch.au3>
#include <ScreenCapture.au3>
#include <GDIPlus.au3>
#include <data\GDIP.au3>
#include <Math.au3>
#include <Array.au3>
#include <data\CodeQR.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <FontConstants.au3>
#include <Timers.au3>
#include <ButtonConstants.au3>
#include <EditConstants.au3>
#include <data\GUIPanel_UDF.au3>
#include <GuiEdit.au3>

Local Const $SCRIPT_NAME = "Atlas of Build"
Local Const $SCRIPT_VERSION = "1.3"
Local Const $FORUM_THREAD_ID = "1715993"
Local Const $QR_OUTPUT_FILENAME = @ScriptDir & "\latest_QR_code.bmp"

Local Const $MOUSE_SPEED = 7
Local Const $POPUP_DELAY = 180
Local Const $STEPS_TO_REACH_SKILL_TREE = 7 ; How many times we need to press "Up" button to reach skill tree. Tested on Chrome, Firefox, Opera
Local Const $IMAGE_RECOGNITION_TOLERANCE = 0 ; 0-255. 0 is full match
Local Const $IMAGE_RECOGNITION_TOLERANCE_FOR_ASCENDARY_BUTTONS = 50 ; 0-255. 0 is full match

Local Const $DEBUG_MODE = false

AutoItSetOption("SendKeyDelay", 70)

HotKeySet("{ESC}", "StopProgram")
HotKeySet("{F2}", "StartGrabbing")

Dim $is_grabbing_in_process = false

Dim $inventory_x = 0
Dim $inventory_y = 0

Dim $total_captured_width = 0
Dim $total_captured_height = 0

; Structure: [ "Section name", [[handle, width, height], [...] ] ], [...]
Dim $sections_to_write_index = 0
Dim $sections_to_write_section_index = 0
Dim $sections_to_write_name[0]
Dim $sections_to_write_img_handle[0][0]
Dim $sections_to_write_img_width[0][0]
Dim $sections_to_write_img_height[0][0]

; Structure [ [offset_x, offset_y, row, column, is_aligned_to_right, line_color], [...] ]
Dim $jewel_offsets[21][6] = [[631, 211, 0, 0, 0, 0x454080FF], _ ; 0
                             [317, 238, 1, 0, 1, 0x45FFFFFF], _ ; 1
                             [ -1, 236, 2, 0, 1, 0x4540FF80], _ ; 2
                             [334, 121, 0, 2, 0, 0x45FFD040], _ ; 3
                             [112,  40, 1, 2, 0, 0x458040FF], _ ; 4
                             [527,  75, 1, 2, 1, 0x457040FF], _ ; 5
                             [290, 143, 2, 2, 1, 0x4580FF40], _ ; 6
                             [255,  95, 0, 3, 0, 0x45FF8020], _ ; 7
                             [659,  82, 0, 3, 0, 0x45FF4080], _ ; 8
                             [214,  65, 1, 3, 0, 0x45FF80E0], _ ; 9
                             [376,  62, 1, 3, 1, 0x45C000FF], _ ; 10
                             [655, 139, 1, 3, 1, 0x45FF8040], _ ; 11
                             [296, 207, 1, 3, 1, 0x45FF80E0], _ ; 12
                             [383, 127, 2, 3, 1, 0x45FF4080], _ ; 13
                             [335, 121, 0, 4, 0, 0x45FF8040], _ ; 14
                             [ 85, 161, 1, 4, 0, 0x45C000FF], _ ; 15
                             [452, 181, 1, 4, 1, 0x45FF8020], _ ; 16
                             [271,  59, 2, 4, 1, 0x458040FF], _ ; 17
                             [275, 241, 1, 5, 0, 0x4580FF40], _ ; 18
                             [579,  57, 0, 6, 0, 0x457040FF], _ ; 19
                             [708,  75, 1, 6, 1, 0x45FFD040]]   ; 20

; This order used to prevent some trivial crossed lines overlaps
Dim $jewels_draw_order[21] = [0,  4,  9,  3,  8,  7, 15, 14, 18, 19, _   ; Left jewel section order
                              1,  2,  5,  6, 10, 11, 13, 12, 17, 16, 20] ; Right jewel section order

Dim $jewels_to_write_jewel_id[0]
Dim $jewels_to_write_img_handle[0]
Dim $jewels_to_write_img_width[0]
Dim $jewels_to_write_img_height[0]

Local Const $ITEM_SIZE_1x1 = 1 ; Amulet, Ring
Local Const $ITEM_SIZE_2x2 = 2 ; Helmet, Gloves, Boots
Local Const $ITEM_SIZE_1x2 = 3 ; Flask
Local Const $ITEM_SIZE_2x1 = 4 ; Belt
Local Const $ITEM_SIZE_2x6 = 5 ; Weapon
Local Const $ITEM_SIZE_2x4 = 6 ; Armour

Local Const $GEMS_NO_GEMS_FOUND           = 0
Local Const $GEMS_1L                      = 1
Local Const $GEMS_4L_SQUARE               = 2
Local Const $GEMS_2L_HORIZONTAL           = 3
Local Const $GEMS_6L_ARMOUR               = 4
Local Const $GEMS_6L_WEAPON               = 5
Local Const $GEMS_4L_ARMOUR_SQUARE        = 6
Local Const $GEMS_4L_VERTICAL             = 7
Local Const $GEMS_3L_VERTICAL             = 8
Local Const $GEMS_2L_VERTICAL             = 9
Local Const $GEMS_3L_WEAPON_SQUARE        = 10
Local Const $GEMS_4L_WEAPON               = 11

Local Const $ASCENDARY_NONE               = 0
Local Const $ASCENDARY_WITCH              = 1
Local Const $ASCENDARY_MARAUDER           = 2
Local Const $ASCENDARY_RANGER             = 3
Local Const $ASCENDARY_DUELIST            = 4
Local Const $ASCENDARY_TEMPLAR            = 5
Local Const $ASCENDARY_SHADOW             = 6
Local Const $ASCENDARY_SCION              = 7

Local Const $GEM_SLOT_WIDTH = 48
Local Const $GEM_SLOT_HEIGHT = $GEM_SLOT_WIDTH

Local Const $TREE_TILES_WIDTH = 3
Local Const $TREE_TILES_HEIGHT = 7
Local Const $TREE_SCREEN_WIDTH = 720
Local Const $TREE_SCREEN_HEIGHT = 260

Local Const $ASCENDARY_TREE_SCREEN_WIDTH = 392
Local Const $ASCENDARY_TREE_SCREEN_HEIGHT = 390

Local Const $SKILL_TREE_OFFSET_FROM_BOTTOM_X = 160
Local Const $SKILL_TREE_OFFSET_FROM_BOTTOM_Y = 217

Dim $tree_screen_x = 0
Dim $tree_screen_y = 0

Dim $build_saving_folder = "builds"
Dim $build_saving_name = "build"

Func AddSectionToWrite($section_name)
    $total_count = $sections_to_write_index

    ReDim $sections_to_write_name[$total_count + 1]
    $current_size = UBound($sections_to_write_img_handle, $UBOUND_COLUMNS)
    ReDim $sections_to_write_img_handle[$total_count + 1][$current_size]
    ReDim $sections_to_write_img_width[$total_count + 1][$current_size]
    ReDim $sections_to_write_img_height[$total_count + 1][$current_size]

    $sections_to_write_name[$total_count] = $section_name

    $sections_to_write_index += 1
    $sections_to_write_section_index = 0
EndFunc

Func AddImgToCurrentSection($img_handle, $width, $height)
    if ($sections_to_write_section_index + 1) > UBound($sections_to_write_img_handle, $UBOUND_COLUMNS) Then
        $current_size = UBound($sections_to_write_img_handle, $UBOUND_COLUMNS)

        ReDim $sections_to_write_img_handle[$sections_to_write_index][$current_size + 1]
        ReDim $sections_to_write_img_width[$sections_to_write_index][$current_size + 1]
        ReDim $sections_to_write_img_height[$sections_to_write_index][$current_size + 1]
    EndIf

    $sections_to_write_img_handle[$sections_to_write_index - 1][$sections_to_write_section_index] = $img_handle
    $sections_to_write_img_width[$sections_to_write_index - 1][$sections_to_write_section_index] = $width
    $sections_to_write_img_height[$sections_to_write_index - 1][$sections_to_write_section_index] = $height

    $sections_to_write_section_index += 1
EndFunc

Func AddJewel($jewel_id, $img_handle, $width, $height)
    $current_size = UBound($jewels_to_write_jewel_id, $UBOUND_ROWS)

    ReDim $jewels_to_write_jewel_id[$current_size + 1]
    ReDim $jewels_to_write_img_handle[$current_size + 1]
    ReDim $jewels_to_write_img_width[$current_size + 1]
    ReDim $jewels_to_write_img_height[$current_size + 1]

    $jewels_to_write_jewel_id[$current_size] = $jewel_id
    $jewels_to_write_img_handle[$current_size] = $img_handle
    $jewels_to_write_img_width[$current_size] = $width
    $jewels_to_write_img_height[$current_size] = $height
EndFunc

Func StartGrabbing()
    if $is_grabbing_in_process Then
        Return
    EndIf

    $is_grabbing_in_process = true

    ; Press alt to ensure all socket graphics will load before we gonna grab general view (I hope it will)
    Send("{Alt down}")
    Sleep($POPUP_DELAY)
    Send("{Alt up}")
    ; Twice, because of Firefox
    Send("{Alt down}")
    Sleep($POPUP_DELAY)
    Send("{Alt up}")

    if FindInventory() == False Then
        $is_grabbing_in_process = false
        Return
    EndIf

    ; Hide gui, we don't need it anymore
    GUISetState(@SW_HIDE, $hGUI)
    Sleep(500)

    ; Reset mouse pos
    ResetMouseToInventoryStart()

    ; Ensure window is focused
    PrimaryClickMouseRelative()
    ; Scroll to the top of the page using Home hotkey
    Send("{HOME}")
    Sleep($POPUP_DELAY)

    FindInventory()

    ; Start grabbing sections

    AddSectionToWrite("General view, QR code")
    ; General view
    CaptureGeneralView()    
    ; Capture QR code
    CaptureQRCode()

    AddSectionToWrite("Main Hand")
    ; Left hand
    CaptureItem(65, 111, $ITEM_SIZE_2x6)

    ResetMouseToInventoryStart() ; To prevent overlay from tooltip

    AddSectionToWrite("Off Hand")
    ; Right hand
    CaptureItem(437, 111, $ITEM_SIZE_2x6)

    if (_IsChecked($idCaptureWeaponSwapCheckbox)) Then
        SwapWeaponSlot()
        
        AddSectionToWrite("Weapon Swap Main Hand")
        ; Left hand
        CaptureItem(65, 111, $ITEM_SIZE_2x6)

        ResetMouseToInventoryStart() ; To prevent overlay from tooltip

        AddSectionToWrite("Weapon Swap Off Hand")
        ; Right hand
        CaptureItem(437, 111, $ITEM_SIZE_2x6)
        
        SwapWeaponSlot()
    EndIf

    AddSectionToWrite("Armour")
    ; Armour
    CaptureItem(251, 206, $ITEM_SIZE_2x4)

    ResetMouseToInventoryStart() ; To prevent overlay from tooltip

    AddSectionToWrite("Helmet")
    ; Helmet
    CaptureItem(251, 99, $ITEM_SIZE_2x2)

    AddSectionToWrite("Gloves")
    ; Gloves
    CaptureItem(134, 312, $ITEM_SIZE_2x2)

    AddSectionToWrite("Boots")
    ; Boots
    CaptureItem(367, 312, $ITEM_SIZE_2x2)

    ResetMouseToInventoryStart() ; To prevent overlay from tooltip

    AddSectionToWrite("Amulet, Rings, Belt")
    ; Amulet
    CaptureItem(368, 194, $ITEM_SIZE_1x1)

    ; Rings
    CaptureItem(182, 253, $ITEM_SIZE_1x1)
    CaptureItem(368, 253, $ITEM_SIZE_1x1)

    ; Belt
    CaptureItem(251, 360, $ITEM_SIZE_2x1, false)

    AddSectionToWrite("Flasks")
    ; Flasks
    CaptureItem(186, 419, $ITEM_SIZE_1x2, false)
    CaptureItem(233, 419, $ITEM_SIZE_1x2, false)
    CaptureItem(281, 419, $ITEM_SIZE_1x2, false)
    CaptureItem(328, 419, $ITEM_SIZE_1x2, false)
    CaptureItem(376, 419, $ITEM_SIZE_1x2, false)

    AddSectionToWrite("Ascendary Passive Skill Tree")
    ; Capture Ascendary skill tree
    CaptureAscendarySkillTree()

    AddSectionToWrite("Passive Skill Tree")
    ; Capture skill tree
    CaptureSkillTree()

    SaveBuild()

    StopProgram()
EndFunc

Func PrimaryClickMouseRelative($offset_x = 0, $offset_y = 0, $clicks_count = 1)
    Local $mouse_pos = MouseGetPos()
    MouseClick($MOUSE_CLICK_PRIMARY, $mouse_pos[0] + $offset_x, $mouse_pos[1] + $offset_y, $clicks_count)
EndFunc

Func DragMouse($pos_x, $pos_y, $restore_offset = true)
    Local $mouse_pos = MouseGetPos()
    MouseClickDrag($MOUSE_CLICK_PRIMARY, $mouse_pos[0], $mouse_pos[1], $pos_x, $pos_y, 0)
    if $restore_offset Then
        MouseMove($mouse_pos[0], $mouse_pos[1], $MOUSE_SPEED)
    EndIf
    Sleep($POPUP_DELAY)
EndFunc

Func DragMouseRelative($offset_x, $offset_y, $restore_offset = true)
    Local $mouse_pos = MouseGetPos()
    MouseClickDrag($MOUSE_CLICK_PRIMARY, $mouse_pos[0], $mouse_pos[1], $mouse_pos[0] + $offset_x, $mouse_pos[1] + $offset_y, 0)
    if $restore_offset Then
        MouseMove($mouse_pos[0], $mouse_pos[1], $MOUSE_SPEED)
    EndIf
    Sleep($POPUP_DELAY)
EndFunc

Func MouseMoveRelative($offset_x, $offset_y)
    Local $mouse_pos = MouseGetPos()
    MouseMove($mouse_pos[0] + $offset_x, $mouse_pos[1] + $offset_y, $MOUSE_SPEED)
EndFunc

Func CaptureCurrentTreeView($hBmpCtxt, $row, $column)
    $captured_view = _ScreenCapture_Capture("", $tree_screen_x, $tree_screen_y, $tree_screen_x + $TREE_SCREEN_WIDTH, $tree_screen_y + $TREE_SCREEN_HEIGHT, false)

    _GDIPlus_GraphicsDrawImage($hBmpCtxt, _GDIPlus_BitmapCreateFromHBITMAP($captured_view), $row * $TREE_SCREEN_WIDTH, $column * $TREE_SCREEN_HEIGHT)

    if $DEBUG_MODE Then
        ; Debug rect
        Local $hPen = _GDIPlus_PenCreate(0xFFFE0000, 1)
        _GDIPlus_GraphicsDrawRect($hBmpCtxt, $row * $TREE_SCREEN_WIDTH, $column * $TREE_SCREEN_HEIGHT, $TREE_SCREEN_WIDTH, $TREE_SCREEN_HEIGHT, $hPen)
        _GDIPlus_PenDispose($hPen)

        ; Debug row + column
        _GDIPlus_GraphicsDrawStringColor($hBmpCtxt, "[" & $row & "," & $column & "]", $row * $TREE_SCREEN_WIDTH + 5, $column * $TREE_SCREEN_HEIGHT + 5, "Courier New", 10, 0, 0xFFFE0000)
    EndIf

    _WinAPI_DeleteObject($captured_view)
EndFunc

Func SwapWeaponSlot()
    MouseClick($MOUSE_CLICK_PRIMARY, $inventory_x + 105, $inventory_y + 100, 1)
    Sleep($POPUP_DELAY)	
EndFunc

Func TryToCaptureJewel($jewel_id)
    ; Saving mouse position before offset
    Local $saved_mouse_pos = MouseGetPos()

    Local $delta_x = ($tree_screen_x + $jewel_offsets[$jewel_id][0]) - $saved_mouse_pos[0]
    Local $delta_y = ($tree_screen_y + $jewel_offsets[$jewel_id][1]) - $saved_mouse_pos[1]

    ; Search for jewel first. Not always working because of shadow overlay, but still saves some time
    $not_used_x = 0
    $not_used_y = 0

    ; Hover jewel slot
    MouseMoveRelative($delta_x, $delta_y)
    Sleep($POPUP_DELAY)
    ; Zero tolerance because tree lines can be confused with it
    If _ImageSearch("data\empty_jewel_slot.bmp", 0, $not_used_x, $not_used_y, 0) Then
        ; Empty jewel slot, reset mouse back
        MouseMove($saved_mouse_pos[0], $saved_mouse_pos[1], 0)

        Return
    Else
        MouseMove($saved_mouse_pos[0], $saved_mouse_pos[1], 0)
    EndIf

    DragMouseRelative(-$delta_x, -$delta_y)
    DragMouseRelative(0, 200, false)

    ; Hover jewel slot
    Sleep($POPUP_DELAY)

    ; Search for item tooltip
    $item_left_x = -1
    $item_left_y = -1

    $item_width = -1
    $item_height = -1

    if     SearchForItemType("unique", $item_left_x, $item_left_y, $item_width) Then
    ElseIf SearchForItemType("rare", $item_left_x, $item_left_y, $item_width) Then
    ElseIf SearchForItemType("magic", $item_left_x, $item_left_y, $item_width) Then
    ElseIf SearchForItemType("white", $item_left_x, $item_left_y, $item_width) Then
    EndIf

    ; Jewel found?
    if $item_left_x <> -1 Then
        ; Correct item width and calculate item height
        Local $current_mouse_pos = MouseGetPos()

        $item_width -= 1
        $item_height = Abs($item_left_y - $current_mouse_pos[1]) - 10

        ; Save item
        $captured_item = _ScreenCapture_Capture("", $item_left_x, $item_left_y, $item_left_x + $item_width, $item_left_y + $item_height, False)
        AddJewel($jewel_id, _GDIPlus_BitmapCreateFromHBITMAP($captured_item), $item_width, $item_height)
        _WinAPI_DeleteObject($captured_item)
    EndIf

    ; Restore position
    DragMouseRelative(0, -200, false)
    PrimaryClickMouseRelative() ; Because tree is not read-only we need to click to ensure that jewel will not be missed from tree
    DragMouseRelative($delta_x, $delta_y)
EndFunc

Func CaptureSkillTree()
    ; Reset mouse pos
    ResetMouseToInventoryStart()

    ; Scroll way down
    Send("{END}")
    Sleep($POPUP_DELAY)

    ; Scroll up to tree position
    for $i = 1 to $STEPS_TO_REACH_SKILL_TREE
        Send("{UP}")
        Sleep($POPUP_DELAY)
    Next

    ; Search for skill tree marker
    $skill_tree_marker_x = 0
    $skill_tree_marker_y = 0
    If _ImageSearch("data\site_tree_points_marker.bmp", 0, $skill_tree_marker_x, $skill_tree_marker_y, 5) Then
        MouseMove($skill_tree_marker_x + $SKILL_TREE_OFFSET_FROM_BOTTOM_X, $skill_tree_marker_y + $SKILL_TREE_OFFSET_FROM_BOTTOM_Y, 0)
        Sleep($POPUP_DELAY)

        ; Scroll out
        MouseWheel("down", 10)
        Sleep($POPUP_DELAY)

        ; Save relative positions for screen
        Local $mouse_pos = MouseGetPos()
        $tree_screen_x = $mouse_pos[0] - $TREE_SCREEN_WIDTH / 2
        $tree_screen_y = $mouse_pos[1] - $TREE_SCREEN_HEIGHT / 2

        ; Offest to top left corner. Should be enough even starting on duelist/ranger areas
        for $i = 1 to 10
            DragMouseRelative(430, 190)
        Next

        $hTreeBitmap = _GDIPlus_BitmapCreateFromScan0($TREE_SCREEN_WIDTH * $TREE_TILES_WIDTH, $TREE_SCREEN_HEIGHT * $TREE_TILES_HEIGHT)
        $hTreeBitmapCtxt = _GDIPlus_ImageGetGraphicsContext($hTreeBitmap)
        _GDIPlus_GraphicsSetSmoothingMode($hTreeBitmapCtxt, 0)
        _GDIPlus_GraphicsClear($hTreeBitmapCtxt, 0xFFBB9E74)

        ; Lets assume we at top left now. Drag view to starting position
        DragMouseRelative(-320, -200)

        ; Start iterating through tree
        $current_row = 0
        $current_column = 0
        $going_right = True
        $current_chunk_number = 0
        While True
            ; Saving mouse position before offset
            Local $saved_mouse_pos = MouseGetPos()
            MouseMove($mouse_pos[0], $mouse_pos[1] - 300, $MOUSE_SPEED)
            Sleep($POPUP_DELAY)

            ; Capture view
            CaptureCurrentTreeView($hTreeBitmapCtxt, $current_row, $current_column)

            ; Restore mouse pos
            MouseMove($saved_mouse_pos[0], $saved_mouse_pos[1], 0)

            ; Capture jewels
            For $i_row = 0 to UBound($jewel_offsets, $UBOUND_ROWS) - 1
                if ($jewel_offsets[$i_row][2] == $current_row) and _
                   ($jewel_offsets[$i_row][3] == $current_column) Then
                    TryToCaptureJewel($i_row)
                EndIf
            Next

            ; Are we done yet?
            $current_chunk_number += 1

            if ($current_chunk_number >= ($TREE_TILES_WIDTH * $TREE_TILES_HEIGHT)) Then
                ExitLoop
            EndIf

            if $going_right Then
                if $current_row == ($TREE_TILES_WIDTH - 1) Then
                    DragMouseRelative(0, -$TREE_SCREEN_HEIGHT / 2)
                    DragMouseRelative(0, -$TREE_SCREEN_HEIGHT / 2)

                    $current_column += 1

                    $going_right = false
                Else
                    DragMouseRelative(-$TREE_SCREEN_WIDTH / 2, 0)
                    DragMouseRelative(-$TREE_SCREEN_WIDTH / 2, 0)

                    $current_row += 1
                EndIf
            Else
                if $current_row == 0 Then
                    DragMouseRelative(0, -$TREE_SCREEN_HEIGHT / 2)
                    DragMouseRelative(0, -$TREE_SCREEN_HEIGHT / 2)

                    $current_column += 1

                    $going_right = true
                Else
                    DragMouseRelative($TREE_SCREEN_WIDTH / 2, 0)
                    DragMouseRelative($TREE_SCREEN_WIDTH / 2, 0)

                    $current_row -= 1
                EndIf
            EndIf
        WEnd

        ; Free resource
        _GDIPlus_GraphicsDispose($hTreeBitmapCtxt)

        ; Emerge jewels to tree image
        $max_width_left = 0
        $max_width_right = 0
        $total_height_left = 0
        $total_height_right = 0
        $total_height = 0

        ; Calculate jewels size
        For $jewel = 0 to UBound($jewels_to_write_img_width, $UBOUND_ROWS) - 1
            if $jewel_offsets[$jewels_to_write_jewel_id[$jewel]][4] Then ; Is aligned to right?
                $max_width_right = _Max($max_width_right, $jewels_to_write_img_width[$jewel])
                $total_height_right += $jewels_to_write_img_height[$jewel] + 3
            Else
                $max_width_left = _Max($max_width_left, $jewels_to_write_img_width[$jewel])
                $total_height_left += $jewels_to_write_img_height[$jewel] + 3
            EndIf
        Next
        $max_width_left += 5
        $max_width_right += 5
        $total_height = _Max($total_height_left, $total_height_right)

        $hTreeAndJewelsBitmap = _GDIPlus_BitmapCreateFromScan0($max_width_left + _GDIPlus_ImageGetWidth($hTreeBitmap) + $max_width_right, _Max(_GDIPlus_ImageGetHeight($hTreeBitmap), $total_height))
        $tree_offset_x = $max_width_left
        $tree_offset_y = 0
        $hTreeAndJewelsBmpCtxt = _GDIPlus_ImageGetGraphicsContext($hTreeAndJewelsBitmap)
        _GDIPlus_GraphicsSetSmoothingMode($hTreeAndJewelsBmpCtxt, 1)
        _GDIPlus_GraphicsDrawImage($hTreeAndJewelsBmpCtxt, $hTreeBitmap, $tree_offset_x, $tree_offset_y)

        ; Draw jewels
        $jewel_item_draw_y_left = 0
        $jewel_item_draw_y_right = 0

        For $jewel_order_i = 0 to UBound($jewels_draw_order, $UBOUND_ROWS) - 1
            For $jewel = 0 to UBound($jewels_to_write_jewel_id, $UBOUND_ROWS) - 1
                ; Check if this jewel from order?
                if $jewels_to_write_jewel_id[$jewel] <> $jewels_draw_order[$jewel_order_i] Then
                    ContinueLoop
                EndIf

                Local $is_aligned_to_right = $jewel_offsets[$jewels_to_write_jewel_id[$jewel]][4]

                $jewel_item_draw_x = 0
                $jewel_item_draw_y = 0

                $line_on_item_draw_x = 0
                $line_on_item_draw_y = 0

                if $is_aligned_to_right Then
                    $jewel_item_draw_x = $tree_offset_x + _GDIPlus_ImageGetWidth($hTreeBitmap) + 5
                    $jewel_item_draw_y = $tree_offset_y + $jewel_item_draw_y_right

                    $line_on_item_draw_x = $jewel_item_draw_x + 6
                Else
                    $jewel_item_draw_x = $tree_offset_x - $jewels_to_write_img_width[$jewel] - 5
                    $jewel_item_draw_y = $tree_offset_y + $jewel_item_draw_y_left

                    $line_on_item_draw_x = $jewel_item_draw_x + $jewels_to_write_img_width[$jewel] - 3
                EndIf

                $line_on_item_draw_y = $jewel_item_draw_y + 27

                ; Draw jewel item
                _GDIPlus_GraphicsDrawImage($hTreeAndJewelsBmpCtxt, $jewels_to_write_img_handle[$jewel], $jewel_item_draw_x, $jewel_item_draw_y)

                ; Get jewel coordinates in tree
                Local $jewel_draw_x = $tree_offset_x + $jewel_offsets[$jewels_to_write_jewel_id[$jewel]][2] * $TREE_SCREEN_WIDTH + $jewel_offsets[$jewels_to_write_jewel_id[$jewel]][0]
                Local $jewel_draw_y = $tree_offset_y + $jewel_offsets[$jewels_to_write_jewel_id[$jewel]][3] * $TREE_SCREEN_HEIGHT + $jewel_offsets[$jewels_to_write_jewel_id[$jewel]][1]

                ; Draw line from jewel in tree to jewel item
                Local $hPen = _GDIPlus_PenCreate($jewel_offsets[$jewels_to_write_jewel_id[$jewel]][5], 3)
                _GDIPlus_GraphicsDrawLine($hTreeAndJewelsBmpCtxt, $jewel_draw_x, $jewel_draw_y, $line_on_item_draw_x, $line_on_item_draw_y, $hPen)
                _GDIPlus_PenDispose($hPen)

                ; Calculate offsets for next jewel
                if $is_aligned_to_right Then
                    $jewel_item_draw_y_right += $jewels_to_write_img_height[$jewel] + 3
                Else
                    $jewel_item_draw_y_left += $jewels_to_write_img_height[$jewel] + 3
                EndIf
            Next
        Next

        ; Debug jewels circles
        if $DEBUG_MODE Then
            For $jewel_id = 0 to UBound($jewel_offsets, $UBOUND_ROWS) - 1
                ; Get jewel coordinates in tree
                Local $jewel_draw_x = $tree_offset_x + $jewel_offsets[$jewel_id][2] * $TREE_SCREEN_WIDTH + $jewel_offsets[$jewel_id][0]
                Local $jewel_draw_y = $tree_offset_y + $jewel_offsets[$jewel_id][3] * $TREE_SCREEN_HEIGHT + $jewel_offsets[$jewel_id][1]

                ; Draw jewel circle
                Local $hPen = _GDIPlus_PenCreate(0xFFFE0000, 1)
                _GDIPlus_GraphicsDrawEllipse($hTreeAndJewelsBmpCtxt, $jewel_draw_x - 10, $jewel_draw_y - 10, 20, 20, $hPen)
                ; Draw jewel center
                _GDIPlus_GraphicsDrawRect($hTreeAndJewelsBmpCtxt, $jewel_draw_x, $jewel_draw_y, 1, 1, $hPen)
                _GDIPlus_PenDispose($hPen)

                ; Draw jewel id
                _GDIPlus_GraphicsDrawStringColor($hTreeAndJewelsBmpCtxt, $jewel_id, $jewel_draw_x + 4, $jewel_draw_y + 4, "Courier New", 12, 0, 0xFFFE0000)
            Next
        EndIf

        _GDIPlus_GraphicsDispose($hTreeAndJewelsBmpCtxt)

        AddImgToCurrentSection($hTreeAndJewelsBitmap, _GDIPlus_ImageGetWidth($hTreeAndJewelsBitmap), _GDIPlus_ImageGetHeight($hTreeAndJewelsBitmap))
    EndIf

    ; Restore
    ; Ensure window is focused
    PrimaryClickMouseRelative()
    Send("{HOME}")
    Sleep($POPUP_DELAY)
EndFunc

Func CaptureAscendarySkillTree()
    ; Reset mouse pos
    ResetMouseToInventoryStart()

    ; Scroll way down
    Send("{END}")
    Sleep($POPUP_DELAY)

    ; Scroll up to tree position
    for $i = 1 to $STEPS_TO_REACH_SKILL_TREE
        Send("{UP}")
        Sleep($POPUP_DELAY)
    Next

    ; Search for skill tree marker
    $skill_tree_marker_x = 0
    $skill_tree_marker_y = 0
    If _ImageSearch("data\site_tree_points_marker.bmp", 0, $skill_tree_marker_x, $skill_tree_marker_y, 5) Then
        MouseMove($skill_tree_marker_x + $SKILL_TREE_OFFSET_FROM_BOTTOM_X, $skill_tree_marker_y + $SKILL_TREE_OFFSET_FROM_BOTTOM_Y, 0)
        Sleep($POPUP_DELAY)

        ; Scroll out
        MouseWheel("down", 10)
        Sleep($POPUP_DELAY)

        ; Saving mouse pos
        Local $saved_mouse_pos = MouseGetPos()

        ; Search for tree
        $ascendary_search_width = 120
        $ascendary_search_height = 120
        $ascendary_search_x = $saved_mouse_pos[0] - $ascendary_search_width / 2
        $ascendary_search_y = $saved_mouse_pos[1] - $ascendary_search_height / 2
        $ascendary_search_right = $ascendary_search_x + $ascendary_search_width
        $ascendary_search_bottom = $ascendary_search_y + $ascendary_search_height

        $result_ascendary_button_left_x = -1
        $result_ascendary_button_left_y = -1
        $result_ascendary_type = $ASCENDARY_NONE

        If     _ImageSearchArea("data\ascendary_witch.bmp", 1, $ascendary_search_x, $ascendary_search_y, $ascendary_search_right, $ascendary_search_bottom, $result_ascendary_button_left_x, $result_ascendary_button_left_y, $IMAGE_RECOGNITION_TOLERANCE_FOR_ASCENDARY_BUTTONS) Or _
               _ImageSearchArea("data\ascendary_witch_hover.bmp", 1, $ascendary_search_x, $ascendary_search_y, $ascendary_search_right, $ascendary_search_bottom, $result_ascendary_button_left_x, $result_ascendary_button_left_y, $IMAGE_RECOGNITION_TOLERANCE_FOR_ASCENDARY_BUTTONS) Then
            $result_ascendary_type = $ASCENDARY_WITCH
        ElseIf _ImageSearchArea("data\ascendary_marauder.bmp", 1, $ascendary_search_x, $ascendary_search_y, $ascendary_search_right, $ascendary_search_bottom, $result_ascendary_button_left_x, $result_ascendary_button_left_y, $IMAGE_RECOGNITION_TOLERANCE_FOR_ASCENDARY_BUTTONS) Or _
               _ImageSearchArea("data\ascendary_marauder_hover.bmp", 1, $ascendary_search_x, $ascendary_search_y, $ascendary_search_right, $ascendary_search_bottom, $result_ascendary_button_left_x, $result_ascendary_button_left_y, $IMAGE_RECOGNITION_TOLERANCE_FOR_ASCENDARY_BUTTONS) Then
            $result_ascendary_type = $ASCENDARY_MARAUDER
        ElseIf _ImageSearchArea("data\ascendary_ranger.bmp", 1, $ascendary_search_x, $ascendary_search_y, $ascendary_search_right, $ascendary_search_bottom, $result_ascendary_button_left_x, $result_ascendary_button_left_y, $IMAGE_RECOGNITION_TOLERANCE_FOR_ASCENDARY_BUTTONS) Or _
               _ImageSearchArea("data\ascendary_ranger_hover.bmp", 1, $ascendary_search_x, $ascendary_search_y, $ascendary_search_right, $ascendary_search_bottom, $result_ascendary_button_left_x, $result_ascendary_button_left_y, $IMAGE_RECOGNITION_TOLERANCE_FOR_ASCENDARY_BUTTONS) Then
            $result_ascendary_type = $ASCENDARY_RANGER
        ElseIf _ImageSearchArea("data\ascendary_duelist.bmp", 1, $ascendary_search_x, $ascendary_search_y, $ascendary_search_right, $ascendary_search_bottom, $result_ascendary_button_left_x, $result_ascendary_button_left_y, $IMAGE_RECOGNITION_TOLERANCE_FOR_ASCENDARY_BUTTONS) Or _
               _ImageSearchArea("data\ascendary_duelist_hover.bmp", 1, $ascendary_search_x, $ascendary_search_y, $ascendary_search_right, $ascendary_search_bottom, $result_ascendary_button_left_x, $result_ascendary_button_left_y, $IMAGE_RECOGNITION_TOLERANCE_FOR_ASCENDARY_BUTTONS) Then
            $result_ascendary_type = $ASCENDARY_DUELIST
        ElseIf _ImageSearchArea("data\ascendary_templar.bmp", 1, $ascendary_search_x, $ascendary_search_y, $ascendary_search_right, $ascendary_search_bottom, $result_ascendary_button_left_x, $result_ascendary_button_left_y, $IMAGE_RECOGNITION_TOLERANCE_FOR_ASCENDARY_BUTTONS) Or _
               _ImageSearchArea("data\ascendary_templar_hover.bmp", 1, $ascendary_search_x, $ascendary_search_y, $ascendary_search_right, $ascendary_search_bottom, $result_ascendary_button_left_x, $result_ascendary_button_left_y, $IMAGE_RECOGNITION_TOLERANCE_FOR_ASCENDARY_BUTTONS) Then
            $result_ascendary_type = $ASCENDARY_TEMPLAR
        ElseIf _ImageSearchArea("data\ascendary_shadow.bmp", 1, $ascendary_search_x, $ascendary_search_y, $ascendary_search_right, $ascendary_search_bottom, $result_ascendary_button_left_x, $result_ascendary_button_left_y, $IMAGE_RECOGNITION_TOLERANCE_FOR_ASCENDARY_BUTTONS) Or _
               _ImageSearchArea("data\ascendary_shadow_hover.bmp", 1, $ascendary_search_x, $ascendary_search_y, $ascendary_search_right, $ascendary_search_bottom, $result_ascendary_button_left_x, $result_ascendary_button_left_y, $IMAGE_RECOGNITION_TOLERANCE_FOR_ASCENDARY_BUTTONS) Then
            $result_ascendary_type = $ASCENDARY_SHADOW
        ElseIf _ImageSearchArea("data\ascendary_scion.bmp", 1, $ascendary_search_x, $ascendary_search_y, $ascendary_search_right, $ascendary_search_bottom, $result_ascendary_button_left_x, $result_ascendary_button_left_y, $IMAGE_RECOGNITION_TOLERANCE_FOR_ASCENDARY_BUTTONS) Or _
               _ImageSearchArea("data\ascendary_scion_hover.bmp", 1, $ascendary_search_x, $ascendary_search_y, $ascendary_search_right, $ascendary_search_bottom, $result_ascendary_button_left_x, $result_ascendary_button_left_y, $IMAGE_RECOGNITION_TOLERANCE_FOR_ASCENDARY_BUTTONS) Then
            $result_ascendary_type = $ASCENDARY_SCION
        EndIf

        if $result_ascendary_type <> $ASCENDARY_NONE Then
            MouseClick($MOUSE_CLICK_PRIMARY, $result_ascendary_button_left_x, $result_ascendary_button_left_y, 1)
            MouseMove($saved_mouse_pos[0], $saved_mouse_pos[1], 0)
        EndIf

        $ascendary_tree_offset_x = 0
        $ascendary_tree_offset_y = 0

        Switch $result_ascendary_type
            Case $ASCENDARY_WITCH
                $ascendary_tree_offset_x = 0
                $ascendary_tree_offset_y = 112
            Case $ASCENDARY_MARAUDER
                $ascendary_tree_offset_x = 100
                $ascendary_tree_offset_y = -60
            Case $ASCENDARY_RANGER
                $ascendary_tree_offset_x = -98
                $ascendary_tree_offset_y = -60
            Case $ASCENDARY_DUELIST
                $ascendary_tree_offset_x = 0
                $ascendary_tree_offset_y = -116
            Case $ASCENDARY_TEMPLAR
                $ascendary_tree_offset_x = 100
                $ascendary_tree_offset_y = 52
            Case $ASCENDARY_SHADOW
                $ascendary_tree_offset_x = -98
                $ascendary_tree_offset_y = 52
            Case $ASCENDARY_SCION
                $ascendary_tree_offset_x = 0
                $ascendary_tree_offset_y = 128
        EndSwitch

        if $result_ascendary_type <> $ASCENDARY_NONE Then
            ; Scroll in
            DragMouseRelative(-$ascendary_tree_offset_x, -$ascendary_tree_offset_y)
            MouseWheel("up", 2)

            MouseMove($saved_mouse_pos[0], $saved_mouse_pos[1] - 255, 30)
            Sleep($POPUP_DELAY)

            ; Capture here
            $captured_acendary_tree_view_x = $saved_mouse_pos[0] - $ASCENDARY_TREE_SCREEN_WIDTH / 2
            $captured_acendary_tree_view_y = $saved_mouse_pos[1] - $ASCENDARY_TREE_SCREEN_HEIGHT / 2
            $captured_acendary_tree_view = _ScreenCapture_Capture("", $captured_acendary_tree_view_x, $captured_acendary_tree_view_y, $captured_acendary_tree_view_x + $ASCENDARY_TREE_SCREEN_WIDTH, $captured_acendary_tree_view_y + $ASCENDARY_TREE_SCREEN_HEIGHT, false)
            AddImgToCurrentSection(_GDIPlus_BitmapCreateFromHBITMAP($captured_acendary_tree_view), $ASCENDARY_TREE_SCREEN_WIDTH, $ASCENDARY_TREE_SCREEN_HEIGHT)
            _WinAPI_DeleteObject($captured_acendary_tree_view)

            ; Scroll out and restore tree pos
            MouseMove($saved_mouse_pos[0], $saved_mouse_pos[1], 0)
            MouseWheel("down", 2)
            DragMouseRelative($ascendary_tree_offset_x, $ascendary_tree_offset_y)

            ; Restore mouse pos
            MouseClick($MOUSE_CLICK_PRIMARY, $result_ascendary_button_left_x, $result_ascendary_button_left_y, 1)
            MouseMove($saved_mouse_pos[0], $saved_mouse_pos[1], 0)
        EndIf
    EndIf

    ; Restore
    ; Ensure window is focused
    PrimaryClickMouseRelative()
    Send("{HOME}")
    Sleep($POPUP_DELAY)
EndFunc

Func CaptureQRCode()
    ; Reset mouse pos
    ResetMouseToInventoryStart()
    MouseClick($MOUSE_CLICK_PRIMARY, $inventory_x, $inventory_y, 1)
    Send("{End}")
    Sleep($POPUP_DELAY)

    ; Trying to find site bottom area
    $site_bottom_x = 0
    $site_bottom_y = 0
    If _ImageSearch("data\site_bottom_marker.bmp", 1, $site_bottom_x, $site_bottom_y, $IMAGE_RECOGNITION_TOLERANCE) Then
        ; Clear clipboard to prevent accidental data leak
        ClipPut("")

        ; Setup cursor in build link field
        MouseClick($MOUSE_CLICK_PRIMARY, $site_bottom_x - 300, $site_bottom_y - 110, 1)
        Sleep($POPUP_DELAY)
        Send("{HOME}")
        Sleep($POPUP_DELAY)
        Send("{SHIFTDOWN}{END}{SHIFTUP}")
        Sleep($POPUP_DELAY)
        Send("{CTRLDOWN}c{CTRLUP}")
        Sleep(500)

        $captured_qr_code = ""
        $captured_qr_code = ClipGet()

        if $captured_qr_code <> "" Then
            _BcodeQR_GenCode($captured_qr_code, 0xFFFFFFFF, 0xFF000000, $QR_OUTPUT_FILENAME, 7, 2, 'H')

            $qr_code_image = _GDIPlus_ImageLoadFromFile($QR_OUTPUT_FILENAME)
            $qr_code_image_width = _GDIPlus_ImageGetWidth($qr_code_image)
            $qr_code_image_height = _GDIPlus_ImageGetHeight($qr_code_image)
            AddImgToCurrentSection($qr_code_image, $qr_code_image_width, $qr_code_image_height)
        EndIf

        ; Restore position
        PrimaryClickMouseRelative(300, 0)
        Sleep($POPUP_DELAY)
    EndIf

    Send("{HOME}")
    ResetMouseToInventoryStart()
    PrimaryClickMouseRelative()
    Sleep($POPUP_DELAY)
EndFunc

Func SaveBuild()
    ; Calculate total width and height
    $draw_x = 5
    $draw_y = 5

    $index = 0

    $acc_width = 0
    $acc_height = 0

    $build_name = GUICtrlRead($idBuildNameInput)
    $build_author = GUICtrlRead($idBuildAuthorInput)
    $build_notes = GUICtrlRead($idBuildNotesMemo)
    $build_notes_lines_count = _GUICtrlEdit_GetLineCount($idBuildNotesMemo)
    $need_to_draw_notes_underline = ($build_name <> "") or ($build_author <> "") or ($build_notes <> "")

    ; Watermark
    $WATERMARK_HEIGHT = 51
    $draw_y += $WATERMARK_HEIGHT

    ; Notes
    $notes_height = 0

    if $build_name <> "" Then
        $notes_height += 15
    EndIf
    if $build_author <> "" Then
        $notes_height += 15
    EndIf
    if $build_notes <> "" Then
        $notes_height += 15 * $build_notes_lines_count
    EndIf
    if $need_to_draw_notes_underline then
        $notes_height += 3
    EndIf

    $draw_y += $notes_height

    For $section in $sections_to_write_name
        $max_height = 0

        ; Need to skip section?
        $need_to_skip_section = true

        For $i = 0 to UBound($sections_to_write_img_handle, $UBOUND_COLUMNS) - 1
            if $sections_to_write_img_handle[$index][$i] <> 0 then
                $need_to_skip_section = false
                ExitLoop
            EndIf
        Next

        if  Not $need_to_skip_section Then
            ; Section name size
            $draw_y += 35

            For $i = 0 to UBound($sections_to_write_img_handle, $UBOUND_COLUMNS) - 1
                if $sections_to_write_img_handle[$index][$i] <> 0 then
                    $draw_x += $sections_to_write_img_width[$index][$i] + 5
                    $max_height = _Max($max_height, $sections_to_write_img_height[$index][$i])
                EndIf
            Next

            $acc_width = _Max($acc_width, $draw_x)
            $draw_x = 5
            $draw_y += $max_height + 10
            $acc_height = $draw_y
        EndIf

        $index += 1
    Next

    ; Prepare image
    $total_captured_width = $acc_width
    $total_captured_height = $acc_height

    $hBitmap = _GDIPlus_BitmapCreateFromScan0($total_captured_width, $total_captured_height)
    $hBmpCtxt = _GDIPlus_ImageGetGraphicsContext($hBitmap)

    _GDIPlus_GraphicsSetSmoothingMode($hBmpCtxt, $GDIP_SMOOTHINGMODE_HIGHQUALITY)
    _GDIPlus_GraphicsClear($hBmpCtxt, 0xFFC0C0C0)
    _GDIPlus_GraphicsSetTextRenderingHint($hBmpCtxt, $GDIP_TEXTRENDERINGHINT_ANTIALIASGRIDFIT)

    ; Tile bg image
    $bg_image = _GDIPlus_ImageLoadFromFile("data\bg.png")
    $bg_image_width = _GDIPlus_ImageGetWidth($bg_image)
    $bg_image_height = _GDIPlus_ImageGetHeight($bg_image)
    for $i = 0 to int($total_captured_width / $bg_image_width) + 1
        for $j = 0 to int($total_captured_height / $bg_image_height) + 1
            _GDIPlus_GraphicsDrawImageRect($hBmpCtxt, $bg_image, $i * $bg_image_width, $j * $bg_image_height, $bg_image_width, $bg_image_height)
        Next
    Next
    _GDIPlus_ImageDispose($bg_image)

    ; Draw all sections
    $draw_x = 5
    $draw_y = 5

    ; Watermark
    _GDIPlus_GraphicsDrawStringColor($hBmpCtxt, "Build saved with ""Path of Exile - " & $SCRIPT_NAME & " v" & $SCRIPT_VERSION & """", $draw_x, $draw_y, "Courier New", 10, 0, 0xFFAF6025)

    $draw_x += 2
    $draw_y += 15
    _GDIPlus_GraphicsDrawStringColor($hBmpCtxt, "https://www.pathofexile.com/forum/view-thread/" & $FORUM_THREAD_ID, $draw_x, $draw_y, "Courier New", 10, 0, 0xFFAF6025)

    $draw_y += 15
    $reddit_icon_image = _GDIPlus_ImageLoadFromFile("data\reddit_icon.png")
    _GDIPlus_GraphicsDrawImageRect($hBmpCtxt, $reddit_icon_image, $draw_x, $draw_y, 16, 16)
    _GDIPlus_GraphicsDrawStringColor($hBmpCtxt, "Lakmus", $draw_x + 16, $draw_y + 1, "Verdana", 10, 0, 0xFF336699)
    _GDIPlus_ImageDispose($reddit_icon_image)

    $draw_x += 71
    $poe_icon_image = _GDIPlus_ImageLoadFromFile("data\poe_icon.png")
    _GDIPlus_GraphicsDrawImageRect($hBmpCtxt, $poe_icon_image, $draw_x, $draw_y + 2, 16, 16)
    _GDIPlus_GraphicsDrawStringColor($hBmpCtxt, "MisaMisa", $draw_x + 16, $draw_y + 1, "Verdana", 10, 0, 0xFF336699)
    _GDIPlus_ImageDispose($poe_icon_image)

    $draw_x = 5
    $draw_y = 5

    ; Bottom line
    Local $hPen = _GDIPlus_PenCreate(0x38AF6025, 1)
    _GDIPlus_GraphicsDrawLine($hBmpCtxt, $draw_x, $draw_y + $WATERMARK_HEIGHT, $draw_x + 279, $draw_y + $WATERMARK_HEIGHT, $hPen)
    _GDIPlus_PenDispose($hPen)

    $draw_y += $WATERMARK_HEIGHT

    ; Build info
    if $build_name <> "" Then
        _GDIPlus_GraphicsDrawStringColor($hBmpCtxt, "Build name: " & $build_name, $draw_x, $draw_y, "Courier New", 10, 0, 0xFFAF6025)
        $draw_y += 15
    EndIf
    if $build_author <> "" Then
        _GDIPlus_GraphicsDrawStringColor($hBmpCtxt, "Build author: " & $build_author, $draw_x, $draw_y, "Courier New", 10, 0, 0xFFAF6025)
        $draw_y += 15
    EndIf
    if $build_notes <> "" Then
        _GDIPlus_GraphicsDrawStringColor($hBmpCtxt, "Build notes: " & $build_notes, $draw_x, $draw_y, "Courier New", 10, 0, 0xFFAF6025)
        $draw_y += 15 * $build_notes_lines_count
    EndIf

    ; Notes underline
    if $need_to_draw_notes_underline Then
        $draw_y += 3
        Local $hPen = _GDIPlus_PenCreate(0x38AF6025, 1)
        _GDIPlus_GraphicsDrawLine($hBmpCtxt, $draw_x, $draw_y + 1, $draw_x + 279, $draw_y + 1, $hPen)
        _GDIPlus_PenDispose($hPen)
    EndIf

    ; Sections
    $index = 0
    For $section in $sections_to_write_name
        $max_height = 0

        ; Need to skip section?
        $need_to_skip_section = true

        For $i = 0 to UBound($sections_to_write_img_handle, $UBOUND_COLUMNS) - 1
            if $sections_to_write_img_handle[$index][$i] <> 0 then
                $need_to_skip_section = false
                ExitLoop
            EndIf
        Next

        if  Not $need_to_skip_section Then
            ; Draw section name
            _GDIPlus_GraphicsDrawStringColorFromFileFont($hBmpCtxt, $section, $draw_x, $draw_y, "data\fontin.ttf", 20, 0, 0xFFBB9E74)
            $draw_y += 35

            For $i = 0 to UBound($sections_to_write_img_handle, $UBOUND_COLUMNS) - 1
                if $sections_to_write_img_handle[$index][$i] <> 0 then
                    _GDIPlus_GraphicsDrawImage($hBmpCtxt, $sections_to_write_img_handle[$index][$i], $draw_x, $draw_y)

                    $draw_x += $sections_to_write_img_width[$index][$i] + 5
                    $max_height = _Max($max_height, $sections_to_write_img_height[$index][$i])
                EndIf
            Next

            $draw_x = 5
            $draw_y += $max_height + 10
        EndIf

        $index += 1
    Next

    ; Save result file
    $build_saving_name = GetBuildSavingName()
    if Not FileExists(@ScriptDir & "\" & $build_saving_folder) Then
        DirCreate(@ScriptDir & "\" & $build_saving_folder)
    EndIf
    $build_output_full_filename = @ScriptDir & "\" & $build_saving_folder & "\" & $build_saving_name & ".png"
    _GDIPlus_ImageSaveToFile($hBitmap, $build_output_full_filename)

    ; Cleanup GDI+ resources
    _GDIPlus_GraphicsDispose($hBmpCtxt)
    _GDIPlus_BitmapDispose($hBitmap)

    ; Open result file
    ShellExecute($build_output_full_filename)
EndFunc

Func SearchForItemType($item_type, ByRef $result_item_left_x, ByRef $result_item_left_y, ByRef $result_item_width)
    If _ImageSearch("data\item_" & $item_type & "_left.bmp", 0, $result_item_left_x, $result_item_left_y, $IMAGE_RECOGNITION_TOLERANCE) Then
        $item_right_x = 0
        $item_right_y = 0

        If _ImageSearch("data\item_" & $item_type & "_right.bmp", 0, $item_right_x, $item_right_y, $IMAGE_RECOGNITION_TOLERANCE) Then
            $result_item_width = $item_right_x - $result_item_left_x + 25

            Return True
        EndIf
    EndIf

    Return False
EndFunc

Func CaptureGeneralView()
    Const $GENERAL_VIEW_WIDTH = 596
    Const $GENERAL_VIEW_HEIGHT = 530

    ; View with all sockets
    Send("{Alt down}")
    Sleep($POPUP_DELAY)
    Local $hHBmp = _ScreenCapture_Capture("", $inventory_x, $inventory_y, $inventory_x + $GENERAL_VIEW_WIDTH, $inventory_y + $GENERAL_VIEW_HEIGHT, false)
    Send("{Alt up}")
    AddImgToCurrentSection(_GDIPlus_BitmapCreateFromHBITMAP($hHBmp), $GENERAL_VIEW_WIDTH, $GENERAL_VIEW_HEIGHT)
    _WinAPI_DeleteObject($hHBmp)

    ; Twice, because of Firefox
    Send("{Alt down}")
    Sleep($POPUP_DELAY)
    Send("{Alt up}")

    ; View without sockets
    Sleep($POPUP_DELAY)
    Local $hHBmp = _ScreenCapture_Capture("", $inventory_x, $inventory_y, $inventory_x + $GENERAL_VIEW_WIDTH, $inventory_y + $GENERAL_VIEW_HEIGHT, false)
    AddImgToCurrentSection(_GDIPlus_BitmapCreateFromHBITMAP($hHBmp), $GENERAL_VIEW_WIDTH, $GENERAL_VIEW_HEIGHT)
    _WinAPI_DeleteObject($hHBmp)
EndFunc

Func CaptureItemImage($offset_x, $offset_y, $width, $height, $need_show_links)
    if $need_show_links Then
        Send("{Alt down}")
        Sleep($POPUP_DELAY)
    EndIf

    Local $hHBmp = _ScreenCapture_Capture("", $offset_x, $offset_y, $offset_x + $width, $offset_y + $height, false)
    $result = _GDIPlus_BitmapCreateFromHBITMAP($hHBmp)
    _WinAPI_DeleteObject($hHBmp)

    if $need_show_links Then
        Send("{Alt up}")

        ; Twice, because of Firefox
        Send("{Alt down}")
        Sleep($POPUP_DELAY)
        Send("{Alt up}")
    EndIf

    Return $result
EndFunc

Func TryToCaptureGemColor($offset_x, $offset_y)
    $captured_gem = _ScreenCapture_Capture("", $offset_x, $offset_y, $offset_x + $GEM_SLOT_WIDTH, $offset_y + $GEM_SLOT_HEIGHT, false)
    AddImgToCurrentSection(_GDIPlus_BitmapCreateFromHBITMAP($captured_gem), $GEM_SLOT_WIDTH, $GEM_SLOT_HEIGHT)
    _WinAPI_DeleteObject($captured_gem)
EndFunc

Func TryToCaptureGem($gem_number, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $shift_x, $shift_y, ByRef $temp_found_gems, $capture_gem_to_output)
    $item_left_x = -1
    $item_left_y = -1

    $item_width = -1
    $item_height = -1

    MouseMove($offset_x + $shift_x, $offset_y + $shift_y, $MOUSE_SPEED)
    Sleep($POPUP_DELAY)

    ; Search for item tooltip
    SearchForItemType("gem", $item_left_x, $item_left_y, $item_width)

    ; Item found?
    if $item_left_x <> -1 Then
        $temp_found_gems += 1

        if $capture_gem_to_output Then
            ; Setup offset
            Switch $gems_search_type
                Case $GEMS_1L, $GEMS_4L_SQUARE, $GEMS_4L_ARMOUR_SQUARE, $GEMS_2L_HORIZONTAL, $GEMS_6L_ARMOUR
                    $offset_y += 1
                Case $GEMS_3L_WEAPON_SQUARE, $GEMS_4L_WEAPON, $GEMS_6L_WEAPON, $GEMS_4L_VERTICAL, $GEMS_3L_VERTICAL, $GEMS_2L_VERTICAL
                    $offset_y += 4
            EndSwitch

            ; Capture gem color
            Switch $gems_search_type
                Case $GEMS_1L
                    if $size <> $ITEM_SIZE_1x1 Then
                        TryToCaptureGemColor($offset_x + $width / 2 - $GEM_SLOT_WIDTH / 2, $offset_y + $height / 2 - $GEM_SLOT_HEIGHT / 2)
                    EndIf
                Case $GEMS_4L_SQUARE, $GEMS_4L_ARMOUR_SQUARE
                    Switch $gem_number
                        Case 1
                            TryToCaptureGemColor($offset_x, $offset_y + $height / 2 - $GEM_SLOT_HEIGHT)
                        Case 2
                            TryToCaptureGemColor($offset_x + $width - $GEM_SLOT_WIDTH, $offset_y + $height / 2 -  $GEM_SLOT_HEIGHT)
                        Case 3
                            TryToCaptureGemColor($offset_x + $width - $GEM_SLOT_WIDTH, $offset_y + $height / 2)
                        Case 4
                            TryToCaptureGemColor($offset_x, $offset_y + $height / 2)
                    EndSwitch
                Case $GEMS_3L_WEAPON_SQUARE
                    Switch $gem_number
                        Case 1
                            TryToCaptureGemColor($offset_x, $offset_y + $height / 2 - $GEM_SLOT_HEIGHT)
                        Case 2
                            TryToCaptureGemColor($offset_x + $width - $GEM_SLOT_WIDTH, $offset_y + $height / 2 -  $GEM_SLOT_HEIGHT)
                        Case 3
                            TryToCaptureGemColor($offset_x + $width - $GEM_SLOT_WIDTH, $offset_y + $height / 2)
                    EndSwitch
                Case $GEMS_4L_WEAPON
                    Switch $gem_number
                        Case 1
                            TryToCaptureGemColor($offset_x, $offset_y + $height / 2 - $GEM_SLOT_HEIGHT)
                        Case 2
                            TryToCaptureGemColor($offset_x + $width - $GEM_SLOT_WIDTH, $offset_y + $height / 2 -  $GEM_SLOT_HEIGHT)
                        Case 3
                            TryToCaptureGemColor($offset_x + $width - $GEM_SLOT_WIDTH, $offset_y + $height / 2)
                        Case 4
                            TryToCaptureGemColor($offset_x, $offset_y + $height / 2)
                    EndSwitch
                Case $GEMS_2L_HORIZONTAL
                    Switch $gem_number
                        Case 1
                            TryToCaptureGemColor($offset_x, $offset_y + $height / 2 - $GEM_SLOT_HEIGHT / 2)
                        Case 2
                            TryToCaptureGemColor($offset_x + $width - $GEM_SLOT_WIDTH, $offset_y + $height / 2 -  $GEM_SLOT_HEIGHT / 2)
                    EndSwitch
                Case $GEMS_6L_ARMOUR
                    Switch $gem_number
                        Case 1
                            TryToCaptureGemColor($offset_x, $offset_y + $height / 2 - $GEM_SLOT_HEIGHT - $GEM_SLOT_HEIGHT / 2)
                        Case 2
                            TryToCaptureGemColor($offset_x + $width - $GEM_SLOT_WIDTH, $offset_y + $height / 2 -  $GEM_SLOT_HEIGHT - $GEM_SLOT_HEIGHT / 2)
                        Case 3
                            TryToCaptureGemColor($offset_x + $width - $GEM_SLOT_WIDTH, $offset_y + $height / 2 -  $GEM_SLOT_HEIGHT / 2)
                        Case 4
                            TryToCaptureGemColor($offset_x, $offset_y + $height / 2 - $GEM_SLOT_HEIGHT / 2)
                        Case 5
                            TryToCaptureGemColor($offset_x, $offset_y + $height / 2 + $GEM_SLOT_HEIGHT / 2)
                        Case 6
                            TryToCaptureGemColor($offset_x + $width - $GEM_SLOT_WIDTH, $offset_y + $height / 2 + $GEM_SLOT_HEIGHT / 2)
                    EndSwitch
                Case $GEMS_6L_WEAPON
                    Switch $gem_number
                        Case 1
                            TryToCaptureGemColor($offset_x, $offset_y + $height / 2 - $GEM_SLOT_HEIGHT - $GEM_SLOT_HEIGHT / 2)
                        Case 2
                            TryToCaptureGemColor($offset_x + $width - $GEM_SLOT_WIDTH, $offset_y + $height / 2 -  $GEM_SLOT_HEIGHT - $GEM_SLOT_HEIGHT / 2)
                        Case 3
                            TryToCaptureGemColor($offset_x + $width - $GEM_SLOT_WIDTH, $offset_y + $height / 2 -  $GEM_SLOT_HEIGHT / 2)
                        Case 4
                            TryToCaptureGemColor($offset_x, $offset_y + $height / 2 - $GEM_SLOT_HEIGHT / 2)
                        Case 5
                            TryToCaptureGemColor($offset_x, $offset_y + $height / 2 + $GEM_SLOT_HEIGHT / 2)
                        Case 6
                            TryToCaptureGemColor($offset_x + $width - $GEM_SLOT_WIDTH, $offset_y + $height / 2 + $GEM_SLOT_HEIGHT / 2)
                    EndSwitch
                Case $GEMS_4L_VERTICAL
                    Switch $gem_number
                        Case 1
                            TryToCaptureGemColor($offset_x + $width / 2 - $GEM_SLOT_WIDTH / 2, $offset_y + $height / 2 - $GEM_SLOT_HEIGHT * 2)
                        Case 2
                            TryToCaptureGemColor($offset_x + $width / 2 - $GEM_SLOT_WIDTH / 2, $offset_y + $height / 2 - $GEM_SLOT_HEIGHT)
                        Case 3
                            TryToCaptureGemColor($offset_x + $width / 2 - $GEM_SLOT_WIDTH / 2, $offset_y + $height / 2)
                        Case 4
                            TryToCaptureGemColor($offset_x + $width / 2 - $GEM_SLOT_WIDTH / 2, $offset_y + $height / 2 + $GEM_SLOT_HEIGHT)
                    EndSwitch
                Case $GEMS_3L_VERTICAL
                    Switch $gem_number
                        Case 1
                            TryToCaptureGemColor($offset_x + $width / 2 - $GEM_SLOT_WIDTH / 2, $offset_y + $height / 2 - $GEM_SLOT_HEIGHT - $GEM_SLOT_HEIGHT / 2)
                        Case 2
                            TryToCaptureGemColor($offset_x + $width / 2 - $GEM_SLOT_WIDTH / 2, $offset_y + $height / 2 - $GEM_SLOT_HEIGHT / 2)
                        Case 3
                            TryToCaptureGemColor($offset_x + $width / 2 - $GEM_SLOT_WIDTH / 2, $offset_y + $height / 2 + $GEM_SLOT_HEIGHT / 2)
                    EndSwitch
                Case $GEMS_2L_VERTICAL
                    Switch $gem_number
                        Case 1
                            TryToCaptureGemColor($offset_x + $width / 2 - $GEM_SLOT_WIDTH / 2, $offset_y + $height / 2 - $GEM_SLOT_HEIGHT)
                        Case 2
                            TryToCaptureGemColor($offset_x + $width / 2 - $GEM_SLOT_WIDTH / 2, $offset_y + $height / 2)
                    EndSwitch
            EndSwitch

            ; Correct item width and calculate item height
            $item_width -= 1
            $item_height = Abs($item_left_y - $offset_y) - 2

            ; Save gem
            $captured_gem = _ScreenCapture_Capture("", $item_left_x, $item_left_y, $item_left_x + $item_width, $item_left_y + $item_height, false)
            AddImgToCurrentSection(_GDIPlus_BitmapCreateFromHBITMAP($captured_gem), $item_width, $item_height)
            _WinAPI_DeleteObject($captured_gem)
        EndIf
    EndIf
EndFunc

Func SearchForGems($gems_search_type, $size, $offset_x, $offset_y, $width, $height, ByRef $gems_type_result, ByRef $best_gems_found_result, $capture_gems_to_output = false)
    ; Optimization, if highest amount of gems already found
    if Not $capture_gems_to_output Then
        $gems_optimization_amount = -1

        Switch $gems_search_type
            Case $GEMS_1L
                $gems_optimization_amount = 1
            Case $GEMS_4L_SQUARE
                $gems_optimization_amount = 4
            Case $GEMS_2L_HORIZONTAL
                $gems_optimization_amount = 3
            Case $GEMS_6L_ARMOUR
                $gems_optimization_amount = 5
            Case $GEMS_6L_WEAPON
                $gems_optimization_amount = 5
            Case $GEMS_4L_ARMOUR_SQUARE, $GEMS_3L_WEAPON_SQUARE
                $gems_optimization_amount = 4
            Case $GEMS_4L_WEAPON
                $gems_optimization_amount = 5
            Case $GEMS_4L_VERTICAL
                $gems_optimization_amount = 4
            Case $GEMS_3L_VERTICAL
                $gems_optimization_amount = 5 ; Yes, not 4
            Case $GEMS_2L_VERTICAL
                $gems_optimization_amount = 4
        EndSwitch

        if $gems_optimization_amount <> -1 Then
            if $best_gems_found_result >= $gems_optimization_amount Then
                Return
            EndIf
        EndIf
    EndIf

    $gem_hotzone_offset = 6
    $gem_large_y_hotzone_offset = 16

    $temp_found_gems = 0

    Switch $gems_search_type
        Case $GEMS_1L
            TryToCaptureGem(1, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $width / 2, $height / 2, $temp_found_gems, $capture_gems_to_output)
        Case $GEMS_4L_SQUARE
            TryToCaptureGem(1, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $gem_hotzone_offset, $gem_hotzone_offset, $temp_found_gems, $capture_gems_to_output)
            TryToCaptureGem(2, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $width - $gem_hotzone_offset, $gem_hotzone_offset, $temp_found_gems, $capture_gems_to_output)
            TryToCaptureGem(3, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $width - $gem_hotzone_offset, $height - $gem_hotzone_offset, $temp_found_gems, $capture_gems_to_output)
            TryToCaptureGem(4, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, 5, $height - $gem_hotzone_offset, $temp_found_gems, $capture_gems_to_output)
        Case $GEMS_2L_HORIZONTAL
            TryToCaptureGem(1, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $gem_hotzone_offset, $height / 2, $temp_found_gems, $capture_gems_to_output)
            TryToCaptureGem(2, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $width - $gem_hotzone_offset, $height / 2, $temp_found_gems, $capture_gems_to_output)
        Case $GEMS_6L_ARMOUR
            TryToCaptureGem(1, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $gem_hotzone_offset, $gem_hotzone_offset, $temp_found_gems, $capture_gems_to_output)
            TryToCaptureGem(2, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $width - $gem_hotzone_offset, $gem_hotzone_offset, $temp_found_gems, $capture_gems_to_output)
            TryToCaptureGem(3, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $width - $gem_hotzone_offset, $height / 2, $temp_found_gems, $capture_gems_to_output)
            TryToCaptureGem(4, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $gem_hotzone_offset, $height / 2, $temp_found_gems, $capture_gems_to_output)
            TryToCaptureGem(5, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $gem_hotzone_offset, $height - $gem_hotzone_offset, $temp_found_gems, $capture_gems_to_output)
            TryToCaptureGem(6, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $width - $gem_hotzone_offset, $height - $gem_hotzone_offset, $temp_found_gems, $capture_gems_to_output)
        Case $GEMS_6L_WEAPON
            TryToCaptureGem(1, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $gem_hotzone_offset, $height / 2 - $gem_large_y_hotzone_offset * 3, $temp_found_gems, $capture_gems_to_output)
            TryToCaptureGem(2, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $width - $gem_hotzone_offset, $height / 2 - $gem_large_y_hotzone_offset * 3, $temp_found_gems, $capture_gems_to_output)
            TryToCaptureGem(3, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $width - $gem_hotzone_offset, $height / 2 + 2, $temp_found_gems, $capture_gems_to_output)
            TryToCaptureGem(4, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $gem_hotzone_offset, $height / 2 + 2, $temp_found_gems, $capture_gems_to_output)
            TryToCaptureGem(5, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $gem_hotzone_offset, $height / 2 + $gem_large_y_hotzone_offset * 3, $temp_found_gems, $capture_gems_to_output)
            TryToCaptureGem(6, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $width - $gem_hotzone_offset, $height / 2 + $gem_large_y_hotzone_offset * 3, $temp_found_gems, $capture_gems_to_output)
        Case $GEMS_4L_ARMOUR_SQUARE
            TryToCaptureGem(1, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $gem_hotzone_offset, $height / 2 - $gem_large_y_hotzone_offset, $temp_found_gems, $capture_gems_to_output)
            TryToCaptureGem(2, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $width - $gem_hotzone_offset, $height / 2 - $gem_large_y_hotzone_offset, $temp_found_gems, $capture_gems_to_output)
            TryToCaptureGem(3, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $width - $gem_hotzone_offset, $height / 2 + $gem_large_y_hotzone_offset, $temp_found_gems, $capture_gems_to_output)
            TryToCaptureGem(4, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $gem_hotzone_offset, $height / 2 + $gem_large_y_hotzone_offset, $temp_found_gems, $capture_gems_to_output)
        Case $GEMS_3L_WEAPON_SQUARE
            TryToCaptureGem(1, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $gem_hotzone_offset, $height / 2 - $gem_large_y_hotzone_offset - 15, $temp_found_gems, $capture_gems_to_output)
            TryToCaptureGem(2, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $width - $gem_hotzone_offset, $height / 2 - $gem_large_y_hotzone_offset - 15, $temp_found_gems, $capture_gems_to_output)
            TryToCaptureGem(3, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $width - $gem_hotzone_offset, $height / 2 + $gem_large_y_hotzone_offset + 15, $temp_found_gems, $capture_gems_to_output)
        Case $GEMS_4L_WEAPON
            TryToCaptureGem(1, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $gem_hotzone_offset, $height / 2 - $gem_large_y_hotzone_offset - 15, $temp_found_gems, $capture_gems_to_output)
            TryToCaptureGem(2, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $width - $gem_hotzone_offset, $height / 2 - $gem_large_y_hotzone_offset - 15, $temp_found_gems, $capture_gems_to_output)
            TryToCaptureGem(3, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $width - $gem_hotzone_offset, $height / 2 + $gem_large_y_hotzone_offset + 15, $temp_found_gems, $capture_gems_to_output)
            TryToCaptureGem(4, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $gem_hotzone_offset, $height / 2 + $gem_large_y_hotzone_offset + 15, $temp_found_gems, $capture_gems_to_output)
        Case $GEMS_4L_VERTICAL
            TryToCaptureGem(1, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $width / 2, $height / 2 - 72, $temp_found_gems, $capture_gems_to_output)
            TryToCaptureGem(2, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $width / 2, $height / 2 - 22, $temp_found_gems, $capture_gems_to_output)
            TryToCaptureGem(3, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $width / 2, $height / 2 + 24, $temp_found_gems, $capture_gems_to_output)
            TryToCaptureGem(4, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $width / 2, $height / 2 + 72, $temp_found_gems, $capture_gems_to_output)
        Case $GEMS_3L_VERTICAL
            TryToCaptureGem(1, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $width / 2 - 3, $height / 2 - $gem_large_y_hotzone_offset * 3, $temp_found_gems, $capture_gems_to_output)
            TryToCaptureGem(2, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $width / 2 - 3, $height / 2 + 5, $temp_found_gems, $capture_gems_to_output)
            TryToCaptureGem(3, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $width / 2 - 3, $height / 2 + $gem_large_y_hotzone_offset * 3 + 2, $temp_found_gems, $capture_gems_to_output)
        Case $GEMS_2L_VERTICAL
            TryToCaptureGem(1, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $width / 2 - 3, $height / 2 - $gem_large_y_hotzone_offset * 2, $temp_found_gems, $capture_gems_to_output)
            TryToCaptureGem(2, $size, $width, $height, $gems_search_type, $offset_x, $offset_y, $width / 2 - 3, $height / 2 + $gem_large_y_hotzone_offset * 2, $temp_found_gems, $capture_gems_to_output)
    EndSwitch

    if $temp_found_gems >= $best_gems_found_result Then
        $best_gems_found_result = $temp_found_gems
        $gems_type_result = $gems_search_type
    EndIf
EndFunc

Func CaptureItem($offset_x, $offset_y, $size, $need_show_links = true)
    $item_left_x = -1
    $item_left_y = -1

    $item_width = -1
    $item_height = -1

    $width = 0
    $height = 0

    Switch $size
        Case $ITEM_SIZE_1x1
            $width = 44
            $height = 42
        Case $ITEM_SIZE_2x2
            $width = 92
            $height = 90
        Case $ITEM_SIZE_1x2
            $width = 43
            $height = 90
        Case $ITEM_SIZE_2x1
            $width = 92
            $height = 42
        Case $ITEM_SIZE_2x6
            $width = 92
            $height = 180
        Case $ITEM_SIZE_2x4
            $width = 92
            $height = 138
    EndSwitch

    ; Capture image preview to save it for later
    $item_image = CaptureItemImage($inventory_x + $offset_x, $inventory_y + $offset_y, $width, $height, $need_show_links)

    ; Offset mouse to get popup
    MouseMove($inventory_x + $offset_x, $inventory_y + $offset_y, 0)
    Switch $size
        Case $ITEM_SIZE_2x2, $ITEM_SIZE_2x4
            MouseMoveRelative(6, $height + 6)
        Case $ITEM_SIZE_2x6
            MouseMoveRelative(6, $height + 10)
        Case $ITEM_SIZE_1x1
            MouseMoveRelative(6, $height + 7)
        Case $ITEM_SIZE_2x1, $ITEM_SIZE_1x2
            MouseMoveRelative($width / 2, $height / 2)
    EndSwitch
    Sleep($POPUP_DELAY)

    ; Search for item tooltip
    if     SearchForItemType("unique", $item_left_x, $item_left_y, $item_width) Then
    ElseIf SearchForItemType("rare", $item_left_x, $item_left_y, $item_width) Then
    ElseIf SearchForItemType("magic", $item_left_x, $item_left_y, $item_width) Then
    ElseIf SearchForItemType("white", $item_left_x, $item_left_y, $item_width) Then
    EndIf

    ; Item found?
    if $item_left_x <> -1 Then
        ; Save item image if item found
        AddImgToCurrentSection($item_image, $width, $height)

        ; Correct item width and calculate item height
        $item_width -= 1
        $item_height = Abs($item_left_y - $offset_y - $inventory_y) - 2

        ; Save item
        $captured_item = _ScreenCapture_Capture("", $item_left_x, $item_left_y, $item_left_x + $item_width, $item_left_y + $item_height, False)
        AddImgToCurrentSection(_GDIPlus_BitmapCreateFromHBITMAP($captured_item), $item_width, $item_height)
        _WinAPI_DeleteObject($captured_item)

        ; Gems
        $gems_type_result = $GEMS_NO_GEMS_FOUND
        $best_gems_found_result = 0

        Switch $size
            Case $ITEM_SIZE_1x1
                SearchForGems($GEMS_1L, $size, $inventory_x + $offset_x, $inventory_y + $offset_y, $width, $height, $gems_type_result, $best_gems_found_result)
            Case $ITEM_SIZE_2x2
                SearchForGems($GEMS_4L_SQUARE, $size, $inventory_x + $offset_x, $inventory_y + $offset_y, $width, $height, $gems_type_result, $best_gems_found_result)
                SearchForGems($GEMS_2L_HORIZONTAL, $size, $inventory_x + $offset_x, $inventory_y + $offset_y, $width, $height, $gems_type_result, $best_gems_found_result)
                SearchForGems($GEMS_1L, $size, $inventory_x + $offset_x, $inventory_y + $offset_y, $width, $height, $gems_type_result, $best_gems_found_result)
            Case $ITEM_SIZE_2x6
                SearchForGems($GEMS_6L_WEAPON, $size, $inventory_x + $offset_x, $inventory_y + $offset_y, $width, $height, $gems_type_result, $best_gems_found_result)
                SearchForGems($GEMS_4L_VERTICAL, $size, $inventory_x + $offset_x, $inventory_y + $offset_y, $width, $height, $gems_type_result, $best_gems_found_result)
                SearchForGems($GEMS_4L_WEAPON, $size, $inventory_x + $offset_x, $inventory_y + $offset_y, $width, $height, $gems_type_result, $best_gems_found_result)
                SearchForGems($GEMS_3L_WEAPON_SQUARE, $size, $inventory_x + $offset_x, $inventory_y + $offset_y, $width, $height, $gems_type_result, $best_gems_found_result)
                SearchForGems($GEMS_2L_HORIZONTAL, $size, $inventory_x + $offset_x, $inventory_y + $offset_y, $width, $height, $gems_type_result, $best_gems_found_result)
                SearchForGems($GEMS_3L_VERTICAL, $size, $inventory_x + $offset_x, $inventory_y + $offset_y, $width, $height, $gems_type_result, $best_gems_found_result)
                SearchForGems($GEMS_2L_VERTICAL, $size, $inventory_x + $offset_x, $inventory_y + $offset_y, $width, $height, $gems_type_result, $best_gems_found_result)
                SearchForGems($GEMS_1L, $size, $inventory_x + $offset_x, $inventory_y + $offset_y, $width, $height, $gems_type_result, $best_gems_found_result)
            Case $ITEM_SIZE_2x4
                SearchForGems($GEMS_6L_ARMOUR, $size, $inventory_x + $offset_x, $inventory_y + $offset_y, $width, $height, $gems_type_result, $best_gems_found_result)
                SearchForGems($GEMS_4L_ARMOUR_SQUARE, $size, $inventory_x + $offset_x, $inventory_y + $offset_y, $width, $height, $gems_type_result, $best_gems_found_result)
                SearchForGems($GEMS_2L_HORIZONTAL, $size, $inventory_x + $offset_x, $inventory_y + $offset_y, $width, $height, $gems_type_result, $best_gems_found_result)
                SearchForGems($GEMS_1L, $size, $inventory_x + $offset_x, $inventory_y + $offset_y, $width, $height, $gems_type_result, $best_gems_found_result)
        EndSwitch

        if $gems_type_result <> $GEMS_NO_GEMS_FOUND Then
            SearchForGems($gems_type_result,  $size, $inventory_x + $offset_x, $inventory_y + $offset_y, $width, $height, $gems_type_result, $best_gems_found_result, True)
        EndIf
    EndIf
EndFunc

Func ResetMouseToInventoryStart()
    MouseMove($inventory_x, $inventory_y, $MOUSE_SPEED)
EndFunc

Func GetBuildSavingName()
    Local $build_name = GUICtrlRead($idBuildNameInput)
    Local $build_author = GUICtrlRead($idBuildAuthorInput)
    Local $total_result = "build"

    if ($build_name <> "") Then
        $total_result = $build_name
    EndIf
    if ($build_author <> "") Then
        $total_result = $total_result & " by " & $build_author
    EndIf

    $total_result = StringRegExpReplace($total_result, '[\\/:*?"<>|]', '')

    Return $total_result
EndFunc

Func FindInventory()
    $x = 0
    $y = 0

    If _ImageSearch("data\inventory.bmp", 0, $x, $y, 10) Then
        $inventory_x = $x - 222
        $inventory_y = $y - 5

        ResetMouseToInventoryStart()
        Return true
    Else
        ShowErrorMessage("Can't find character inventory", false)
        Return false
    EndIf
EndFunc

Func ConsoleWriteLn($text)
    ConsoleWrite($text & @LF)
EndFunc

Func ShowErrorMessage($error_msg, $terminate = true)
    If Not $error_msg = "" Then
        MsgBox(4096, "Error", "Error: " & $error_msg)
    EndIf

    if $terminate Then
        StopProgram()
    EndIf
EndFunc

Func StopProgram()
    Exit 0
EndFunc

; Make sure process is checking system DPI settings when moves mouse
DllCall("User32.dll", "bool", "SetProcessDPIAware")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; GUI Section
_GDIPlus_Startup()
Local Const $GUI_WINDOW_WIDTH = 460
Local Const $GUI_WINDOW_HEIGHT = 500 
Local $hGUI = GUICreate($SCRIPT_NAME & " - " & $SCRIPT_VERSION, $GUI_WINDOW_WIDTH, $GUI_WINDOW_HEIGHT , 15, _Max(75, @DesktopHeight / 4 - $GUI_WINDOW_HEIGHT / 2), -1, BitOR($WS_EX_TOPMOST, $WS_EX_COMPOSITED))

GUISetIcon("data\poe_icon.ico")
TraySetIcon("data\poe_icon.ico")

Local $idCloseButton = GUICtrlCreateButton("Close", $GUI_WINDOW_WIDTH - 100 - 8, $GUI_WINDOW_HEIGHT - 30 - 3, 100, 30, $BS_DEFPUSHBUTTON)

; Dummy button to not make "Close" button by default
GUICtrlCreateButton("", 0, 0, 1, 1)
GUICtrlSetState(-1, $GUI_HIDE)
GUICtrlSetState(-1, $GUI_DEFBUTTON)

Local $gui_offset_x = 0
Local $gui_offset_y = 0

GUICtrlCreatePic("data\logo.jpg", $gui_offset_x, $gui_offset_y, 460, 88)
$gui_offset_y += 88

$gui_offset_x += 10
$gui_offset_y += 8
Local $idStatusLabel = GUICtrlCreateLabel("Updating status...", $gui_offset_x, $gui_offset_y, $GUI_WINDOW_WIDTH, 20)
GUICtrlSetFont($idStatusLabel, 10, $FW_NORMAL, 0, "Tahoma")

$gui_offset_y += 20
Local $idWarningLabel = GUICtrlCreateLabel("Please don't touch your mouse while this script works", $gui_offset_x, $gui_offset_y, $GUI_WINDOW_WIDTH, 18)
GUICtrlSetFont(-1, 10, $FW_NORMAL, 0, "Tahoma")
GUICtrlSetState(-1, $GUI_HIDE)

Local $idScaleLabel = GUICtrlCreateLabel("Make sure that system UI and browser page scale is reset to 100%", $gui_offset_x, $gui_offset_y, $GUI_WINDOW_WIDTH, 18)
GUICtrlSetFont(-1, 10, $FW_NORMAL, 0, "Tahoma")
GUICtrlSetColor(-1, 0xFF3030)
GUICtrlSetState(-1, $GUI_HIDE)

$gui_offset_y += 20
Local $idExitInfoLabel = GUICtrlCreateLabel("You can always stop this script by pressing Esc", $gui_offset_x, $gui_offset_y, $GUI_WINDOW_WIDTH, 18)
GUICtrlSetFont(-1, 10, $FW_NORMAL, 0, "Tahoma")
GUICtrlSetState(-1, $GUI_HIDE)

$gui_offset_y += 24

$gui_offset_y += 5
GUICtrlCreateLabel("You can setup this fields to add additional info", $gui_offset_x, $gui_offset_y, $GUI_WINDOW_WIDTH, 18)
GUICtrlSetFont(-1, 10, $FW_NORMAL, 0, "Tahoma")
$gui_offset_y += 18

GUICtrlCreateLabel("Build name:", $gui_offset_x, $gui_offset_y, $GUI_WINDOW_WIDTH, 18)
GUICtrlSetFont(-1, 10, $FW_NORMAL, 0, "Tahoma")
$gui_offset_y += 18
Local $idBuildNameInput = GUICtrlCreateInput("", $gui_offset_x, $gui_offset_y, $GUI_WINDOW_WIDTH - 21, 20)
$gui_offset_y += 22

GUICtrlCreateLabel("Build author:", $gui_offset_x, $gui_offset_y, $GUI_WINDOW_WIDTH, 18)
GUICtrlSetFont(-1, 10, $FW_NORMAL, 0, "Tahoma")
$gui_offset_y += 18
Local $idBuildAuthorInput = GUICtrlCreateInput("", $gui_offset_x, $gui_offset_y, $GUI_WINDOW_WIDTH - 21, 20)
$gui_offset_y += 22

GUICtrlCreateLabel("Build notes:", $gui_offset_x, $gui_offset_y, $GUI_WINDOW_WIDTH, 18)
GUICtrlSetFont(-1, 10, $FW_NORMAL, 0, "Tahoma")
$gui_offset_y += 18
Local $idBuildNotesMemo = GuiCtrlCreateEdit("", $gui_offset_x, $gui_offset_y, $GUI_WINDOW_WIDTH - 21, 120, $ES_AUTOVSCROLL + $WS_VSCROLL + $ES_NOHIDESEL + $ES_WANTRETURN)
$gui_offset_y += 124

Local $idCaptureWeaponSwapCheckbox = GUICtrlCreateCheckbox("Capture weapon swap items", $gui_offset_x, $gui_offset_y, $GUI_WINDOW_WIDTH, 18)
GUICtrlSetFont(-1, 10, $FW_NORMAL, 0, "Tahoma")
$gui_offset_y += 20
$gui_offset_y += 5

Local $idBuildSavefileLabel = GUICtrlCreateLabel("", $gui_offset_x, $gui_offset_y, $GUI_WINDOW_WIDTH, 18)
GUICtrlSetFont(-1, 10, $FW_NORMAL, 0, "Tahoma")
$gui_offset_y += 18
GUICtrlCreateLabel("If file exists it will be overwritten", $gui_offset_x, $gui_offset_y, $GUI_WINDOW_WIDTH, 18)
GUICtrlSetFont(-1, 10, $FW_NORMAL, 0, "Tahoma")

; Paypal donate
;Local $idDonateButton = GUICtrlCreatePic("data\donate.bmp", 7, $GUI_WINDOW_HEIGHT - 30 - 4, 155, 30)

; Focus input on build name
GUICtrlSetState($idBuildNameInput, $GUI_FOCUS)
UpdateBuildSavingName()

_GUICtrlPanel_Create($hGUI, "", 10, 160, $GUI_WINDOW_WIDTH - 20, 0, 0, @SW_SHOWNA)
_GUICtrlPanel_Create($hGUI, "", 10, $GUI_WINDOW_HEIGHT - 74, $GUI_WINDOW_WIDTH - 20, 0, 0, @SW_SHOWNA)

Func UpdateBuildSavingName()
    ControlSetText($hGUI, "", $idBuildSavefileLabel , "Build will be saved as: " & $build_saving_folder & "\" & GetBuildSavingName() & ".png" , 1)
EndFunc

Func _GUIProcessTimer($hWnd, $iMsg, $iIDTimer, $iTime)
    ; Check for inventory
    Local $x = 0
    Local $y = 0

    If _ImageSearch("data\inventory.bmp", 0, $x, $y, 10) Then
        ControlSetText($hGUI, "", $idStatusLabel, "Status: inventory found. Wait for page to load and Press F2 to start", 1)
        GUICtrlSetColor($idStatusLabel, 0x000000)
        
        GUICtrlSetState($idWarningLabel, $GUI_SHOW)
        GUICtrlSetState($idExitInfoLabel, $GUI_SHOW)
        
        GUICtrlSetState($idScaleLabel, $GUI_HIDE)
    Else
        ControlSetText($hGUI, "", $idStatusLabel, "Status: inventory not found. Open browser page with inventory opened", 1)
        GUICtrlSetColor($idStatusLabel, 0xFF3030)
        
        GUICtrlSetState($idWarningLabel, $GUI_HIDE)
        GUICtrlSetState($idExitInfoLabel, $GUI_HIDE)
        
        GUICtrlSetState($idScaleLabel, $GUI_SHOW)
    EndIf

    ; Generate saved build name
    UpdateBuildSavingName()
EndFunc

Func _IsChecked($idControlID)
    Return BitAND(GUICtrlRead($idControlID), $GUI_CHECKED) = $GUI_CHECKED
EndFunc 

Func PROCESS_WM_COMMAND($hWnd, $imsg, $iwParam, $ilParam)
    $nNotifyCode = BitShift($iwParam, 16)

    If ($nNotifyCode == $EN_CHANGE) Then
        Switch $ilParam
            Case GUICtrlGetHandle($idBuildNameInput), GUICtrlGetHandle($idBuildAuthorInput)
                UpdateBuildSavingName()
        EndSwitch
    EndIf

    Return $GUI_RUNDEFMSG
EndFunc

GUIRegisterMsg($WM_COMMAND, "PROCESS_WM_COMMAND")

GUISetState(@SW_SHOW, $hGUI)
_Timer_SetTimer($hGUI, 1000, "_GUIProcessTimer")

While 1
    Switch GUIGetMsg()
        Case $GUI_EVENT_CLOSE, $idCloseButton
            ExitLoop
        ;Case $idDonateButton
        ;	ShellExecute("https://www.paypal.me/POEMisaMisa")
    EndSwitch
WEnd

GUIDelete($hGUI)
_GDIPlus_Shutdown()