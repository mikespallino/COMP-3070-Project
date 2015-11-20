TITLE PacMan, Authors: Andrew Hart, Diego Prates, Mike Spallino, Josh Sullivan

INCLUDE irvine32.inc
INCLUDE macros.inc

MapObject Struct
	MapFile byte 10 Dup(0)
	PacDots word ?
MapObject Ends

BUFFER_SIZE = 1000
MAX_COORD = 23
MAP_WIDTH = 25

.data
Main_MenuStr byte "main menu.txt"
buffer      BYTE   BUFFER_SIZE DUP(?)
filenamePtr Dword offset Main_MenuStr
fileHandle  HANDLE ?
PacManX     BYTE   11
PacManY     BYTE   16
PrevX       BYTE   11
PrevY       BYTE   16
deltaX      SBYTE  0
deltaY      SBYTE  0
tempLoc     BYTE   ?
score       DWORD  0
pointsToAdd DWORD  0
Strscre     BYTE  "Score: "
cherryItem  BYTE 224
stwbryItem  BYTE 225
orangeItem  BYTE 226
appleItem   BYTE 227
melonItem   BYTE 228
galBssItem  BYTE 229
bellItem    BYTE 230
keyItem     BYTE 231
ticks       DWORD 0
Map1 MapObject<"Map1.txt",223>
Map2 MapObject<"Map2.txt",204>
Map3 MapObject<"Map3.txt",232>
Level byte ?
PacDotsConsumed Dword 0
PacDotCount Dword 0

.code
main proc
	Call ReadMapFile
	Call ReadChar
	mov ecx,3
	MapLoop:
		push ecx
		mov level, cl
		Call GetLevel						 ;sets the right map to be loaded

		call ReadMapFile                     ; Get a map
		call DrawPacMan
		MainLoop:                            ; Main loop
			call Render
			call DelayPacMan                 ; delays pacman
			call Update
			mov eax, PacDotCount
			cmp eax, PacDotsConsumed
			jg MainLoop
			Call ResetGame					  ;resets game from the begining
			pop ecx
			Loop MapLoop
		  mWrite <"You Won!">
		exit
main endp

; All procedures related to updating game state will
; be called from here.
Update proc
	call GetKey
	call MovePacMan
	call CheckMapLoc
	ret
Update endp

; All procedures related to rendering the game will
; be called from here.
Render proc
	call DrawPacMan
	call HandleFruit
	ret
Render endp

DelayPacMan proc USES eax
	mov eax,150
	add ticks, 5
	call Delay
	ret
DelayPacMan endp

; Map key presses to W,A,S,D
GetKey proc
	mov deltaX, 0
	mov deltaY, 0
	call ReadChar
	cmp al, "w"
	je Up
	jne NotUp

	Up:
		mov deltaX, 0
		mov deltaY, -1
		jmp EndOfGetKeyProc

	NotUp:
		cmp al,"s"
		je Down
		jmp NotDown

	Down:
		mov deltaX, 0
		mov deltaY, 1
		jmp EndOfGetKeyProc

	NotDown:
		cmp al, "a"
		je Left
		jne NotLeft

	Left:
		mov deltaX, -1
		mov deltaY, 0
		jmp EndOfGetKeyProc

	NotLeft:
		cmp al, "d"
		je Right
		jne Invalid

	Right:
		mov deltaX, 1
		mov deltaY, 0
		jmp EndOfGetKeyProc

	Invalid:
		mov deltaX, 0
		mov deltaY, 0
		jmp EndOfGetKeyProc

	EndOfGetKeyProc:
		ret
GetKey endp

; Check to make sure this is a valid location to move the player to
CheckMapLoc proc USES eax ebx
	mov edx, OFFSET buffer
	cmp PacManX, MAX_COORD
	jg DecX
	je WrapPosBack
	cmp PacManY, MAX_COORD
	jg DecY
	jmp CheckZero

	; We've moved too far forward in the X
	DecX:
		sub PacManX, 1
		jmp EndOfCheckMapLoc

	WrapPosBack:
		mov PacManX, 0
		jmp RemoveChar

	; We've moved too far forward in the Y
	DecY:
		sub PacManY, 1
		jmp EndOfCheckMapLoc

	CheckZero:
		cmp PacManX, -1
		je WrapPosForward
		cmp PacManX, 0
		jl IncX
		cmp PacManY, 0
		jl IncY
		jmp GetCoordChar

	WrapPosForward:
		mov PacManX, 22
		jmp RemoveChar

	; We've moved to far back in the Y
	IncX:
		add PacManX, 1
		jmp EndOfCheckMapLoc

	; We've moved too far back in the Y
	IncY:
		add PacManY, 1
		jmp EndOfCheckMapLoc

	GetCoordChar:
		mov ecx, MAP_WIDTH
		movzx ax, PacManY
		mul ecx
		mov edx, OFFSET buffer
		movsx ecx, PacManX
		add eax, ecx
		add edx, eax
		mov bl, [edx]
		mov tempLoc, bl
		cmp bl, '²'                      ; Was this a wall?
		je ResetPos                      ; Move back
		jmp CheckTile                    ; It's probably consumable.

		ResetPos:
			call MoveBack 
			jmp EndOfCheckMapLoc

		CheckTile:
			cmp bl, '.'
			je PacDot
			cmp bl, cherryItem
			je Cherry
			cmp bl, stwbryItem
			je Strawberry
			cmp bl, orangeItem
			je Orange
			cmp bl, appleItem
			je Apple
			cmp bl, melonItem
			je Melon
			cmp bl, galBssItem
			je Boss
			cmp bl, bellItem
			je Bell
			cmp bl, keyItem
			je Key
			jmp InvalidChar

			PacDot:
				add PacDotsConsumed, 1
				mov pointsToAdd, 10
				jmp RemoveChar

			Cherry:
				mov pointsToAdd, 100
				jmp RemoveChar

			Strawberry:
				mov pointsToAdd, 300
				jmp RemoveChar

			Orange:
				mov pointsToAdd, 500
				jmp RemoveChar

			Apple:
				mov pointsToAdd, 700
				jmp RemoveChar

			Melon:
				mov pointsToAdd, 1000
				jmp RemoveChar

			Boss:
				mov pointsToAdd, 2000
				jmp RemoveChar

			Bell:
				mov pointsToAdd, 3000
				jmp RemoveChar

			Key:
				mov pointsToAdd, 5000
				jmp RemoveChar

			InvalidChar:
				mov pointsToAdd, 0       ; We probably don't wont this on the map anyway.
				jmp RemoveChar


		RemoveChar:
			mov al, ' '
			mov [edx], al
			mov dl, PrevX
			mov dh, PrevY
			call GotoXY
			call WriteChar
			mov eax, pointsToAdd
			add score, eax               ; increments the score by one
			mov pointsToAdd, 0
			call UpdateScore             ; updates score
			jmp EndOfCheckMapLoc
		
	EndOfCheckMapLoc:
		ret
CheckMapLoc endp

; Move Pac Man to another location
; Keep track of the previous location
MovePacMan proc USES eax ebx
	; Get previous coordinate
	mov bl, PacManX
	mov PrevX, bl
	mov bl, PacManY
	mov PrevY, bl

	; Move to new coordinate
	mov al, deltaX
	add PacManX, al
	mov al, deltaY
	add PacManY, al
	ret
MovePacMan endp

; Move the player back to their previous location
; because an invalid location was tried.
MoveBack proc USES eax
	mov eax, 0
	mov al, PrevX
	mov PacManX, al
	mov al, PrevY
	mov PacManY, al
	ret
MoveBack endp

; Draw Pac Man
DrawPacMan proc USES eax edx ecx
	mov dl, PacManX                      ; Get Coordinates
	mov dh, PacManY                      ; Get Coordinates
	call GotoXY
	mov eax, yellow + (black * 16)
	call SetTextColor
	mov eax, 1
	call WriteChar                       ; Draw Yellow Smiley at X,Y
	mov eax, white + (black * 16)
	call SetTextColor                    ; Set the text color back to white on black
	mov ecx, 23
	sub cl, PacManY
	ClearCRLF:                           ; Clear a bunch of lines to print at the bottom
		call CRLF
	Loop ClearCRLF
	movsx eax, PacManX                   ; Print x, y, and character you last attempted a move to (debug)
	call WriteInt
	movsx eax, PacManY
	call WriteInt
	mov eax, 0
	mov al, tempLoc
	call WriteChar
	ret
DrawPacMan endp

; Read File from the book
ReadMapFile proc USES edx eax ecx
	; Open the file for input.
	mov	edx, filenamePtr
	call	OpenInputFile
	mov	fileHandle,eax

	; Check for errors.
	cmp	eax,INVALID_HANDLE_VALUE		 ; error opening file?
	jne	file_ok					         ; no: skip
	mWrite <"Cannot open file",0dh,0ah>
	jmp	quit						     ; and quit
	
	file_ok:
		; Read the file into a buffer.
		mov	edx,OFFSET buffer
		mov	ecx,BUFFER_SIZE
		call ReadFromFile
		jnc	check_buffer_size			 ; error reading?
		mWrite "Error reading file. "	 ; yes: show error message
		call WriteWindowsMsg
		jmp	close_file
	
		check_buffer_size:
			cmp	eax,BUFFER_SIZE			 ; buffer large enough?
			jb buf_size_ok				 ; yes
			mWrite <"Error: Buffer too small for the file",0dh,0ah>
			jmp	quit				     ; and quit
	
		buf_size_ok:	
			mov edx, OFFSET buffer
			call ClrScr
			call WriteString

	close_file:
		mov	eax,fileHandle
		call CloseFile

	quit:
		call UpdateScore
		ret
ReadMapFile endp

UpdateScore proc USES eax edx
	mov dh, 20
	mov dl, 35
	call GotoXY
	mWrite "Score: "
	mov eax, PacDotsConsumed
	Call WriteHex
	mov dh, 20
	mov dl, 35
	call GotoXY
	mov eax, PacDotCount
	call WriteHex
	ret
UpdateScore endp

HandleFruit proc USES eax
	mov eax, ticks
	call WriteInt
	cmp eax, 180
	je DwChr
	cmp eax, 360
	je DwStr
	cmp eax, 540
	je DwOrg
	cmp eax, 720
	je DwApp
	cmp eax, 900
	je DwMel
	cmp eax, 1080
	je DwGB
	cmp eax, 1260
	je DwBl
	cmp eax, 1440
	je DwKey
	jmp EndOfHandleFruit

	DwChr:
		call DrawCherry
		jmp EndOfHandleFruit

	DwStr:
		call DrawStrawberry
		jmp EndOfHandleFruit

	DwOrg:
		call DrawOrange
		jmp EndOfHandleFruit

	DwApp:
		call DrawApple
		jmp EndOfHandleFruit

	DwMel:
		call DrawMelon
		jmp EndOfHandleFruit

	DwGB:
		call DrawGalaxianBoss
		jmp EndOfHandleFruit

	DwBl:
		call DrawBell
		jmp EndOfHandleFruit

	DwKey:
		call DrawKey
		jmp EndOfHandleFruit

	EndOfHandleFruit:
		ret
HandleFruit endp

DrawCherry proc USES eax ecx edx
	mov eax, magenta + (black * 16)
	call SetTextColor
	mov eax, 0
	mov ebx, 0

	mov ecx, MAP_WIDTH
	mov ax, 12
	
	mul ecx
	mov edx, OFFSET buffer
	mov ecx, 11
	add eax, ecx
	add edx, eax
	mov bl,[edx]
	cmp bl, '.'
	jne NoDot
	sub PacDotCount, 1
	NoDot:
	mov bl, cherryItem
	mov [edx], bl
	mov dl, 11
	mov dh, 12
	call GotoXY
	movzx eax, cherryItem
	call WriteChar
	ret
DrawCherry endp

DrawStrawberry proc USES eax ecx edx
	movzx eax, cherryItem
	mov cherryItem, ' '
	call DrawCherry
	mov cherryItem, al

	mov eax, red + (black * 16)
	call SetTextColor
	mov eax, 0
	mov ebx, 0

	mov ecx, MAP_WIDTH
	mov ax, 10
	
	mul ecx
	mov edx, OFFSET buffer
	mov ecx, 5
	add eax, ecx
	add edx, eax
	mov bl,[edx]
	cmp bl, '.'
	jne NoDot
	sub PacDotCount, 1
	NoDot:
	mov bl, stwbryItem
	mov [edx], bl
	mov dl, 5
	mov dh, 10
	call GotoXY
	movzx eax, stwbryItem
	call WriteChar
	ret
DrawStrawberry endp

DrawOrange proc USES eax ecx edx
	
	movzx eax, stwbryItem
	mov stwbryItem, ' '
	call DrawStrawberry
	mov stwbryItem, al

	mov eax, brown + (black * 16)
	call SetTextColor
	mov eax, 0
	mov ebx, 0

	mov ecx, MAP_WIDTH
	mov ax, 6
	
	mul ecx
	mov edx, OFFSET buffer
	mov ecx, 14
	add eax, ecx
	add edx, eax
	mov bl,[edx]
	cmp bl, '.'
	jne NoDot
	sub PacDotCount, 1
	NoDot:
	mov bl, orangeItem
	mov [edx], bl
	mov dl, 14
	mov dh, 6
	call GotoXY
	movzx eax, orangeItem
	call WriteChar
	ret
DrawOrange endp

DrawApple proc USES eax ecx edx
	movzx eax, orangeItem
	mov orangeItem, ' '
	call DrawOrange
	mov orangeItem, al

	mov eax, green + (black * 16)
	call SetTextColor
	mov eax, 0
	mov ebx, 0

	mov ecx, MAP_WIDTH
	mov ax, 3
	
	mul ecx
	mov edx, OFFSET buffer
	mov ecx, 5
	add eax, ecx
	add edx, eax
	mov bl,[edx]
	cmp bl, '.'
	jne NoDot
	sub PacDotCount, 1
	NoDot:
	mov bl, appleItem
	mov [edx], bl
	mov dl, 5
	mov dh, 3
	call GotoXY
	movzx eax, appleItem
	call WriteChar
	ret
DrawApple endp

DrawMelon proc USES eax ecx edx
	movzx eax, appleItem
	mov appleItem, ' '
	call DrawApple
	mov appleItem, al

	mov eax, yellow + (black * 16)
	call SetTextColor
	mov eax, 0
	mov ebx, 0

	mov ecx, MAP_WIDTH
	mov ax, 18
	
	mul ecx
	mov edx, OFFSET buffer
	mov ecx, 20
	add eax, ecx
	add edx, eax
	mov bl,[edx]
	cmp bl, '.'
	jne NoDot
	sub PacDotCount, 1
	NoDot:
	mov bl, melonItem
	mov [edx], bl
	mov dl, 20
	mov dh, 18
	call GotoXY
	movzx eax, melonItem
	call WriteChar
	ret
DrawMelon endp

DrawGalaxianBoss proc USES eax ecx edx
	movzx eax, melonItem
	mov melonItem, ' '
	call DrawMelon
	mov melonItem, al

	mov eax, lightBlue + (black * 16)
	call SetTextColor
	mov eax, 0
	mov ebx, 0
	mov ecx, MAP_WIDTH
	mov ax, 14
	
	mul ecx
	mov edx, OFFSET buffer
	mov ecx, 3
	add eax, ecx
	add edx, eax
	mov bl,[edx]
	cmp bl, '.'
	jne NoDot
	sub PacDotCount, 1
	NoDot:
	mov bl, galBssItem
	mov [edx], bl
	mov dl, 3
	mov dh, 14
	call GotoXY
	movzx eax, galBssItem
	call WriteChar
	ret
DrawGalaxianBoss endp

DrawBell proc USES eax ecx edx
	
	movzx eax, galBssItem
	mov galBssItem, ' '
	call DrawGalaxianBoss
	mov galBssItem, al

	mov eax, yellow + (black * 16)
	call SetTextColor
	mov eax, 0
	mov ebx, 0

	mov ecx, MAP_WIDTH
	mov ax, 1
	
	mul ecx
	mov edx, OFFSET buffer
	mov ecx, 6
	add eax, ecx
	add edx, eax
	mov bl,[edx]
	cmp bl, '.'
	jne NoDot
	sub PacDotCount, 1
	NoDot:
	mov bl, bellItem
	mov [edx], bl
	mov dl, 6
	mov dh, 1
	call GotoXY
	movzx eax, bellItem
	call WriteChar
	ret
DrawBell endp

DrawKey proc USES eax ecx edx
	
	movzx eax, bellItem
	mov bellItem, ' '
	call DrawBell
	mov bellItem, al

	mov eax, yellow + (black * 16)
	call SetTextColor
	mov eax, 0
	mov ebx, 0

	mov ecx, MAP_WIDTH
	mov ax, 4
	
	mul ecx
	mov edx, OFFSET buffer
	mov ecx, 12
	add eax, ecx
	add edx, eax
	mov bl,[edx]
	cmp bl, '.'
	jne NoDot
	sub PacDotCount, 1
	NoDot:
	mov bl, keyItem
	mov [edx], bl
	mov dl, 12
	mov dh, 4
	call GotoXY
	movzx eax, keyItem
	call WriteChar
	ret
DrawKey endp

;Since ecx goes from 3 to 1, this function uses 3 to load the first map
;and 1 to load the last map
GetLevel proc uses eax		
	cmp Level,3
	je Down1
	cmp Level,2
	je Down2
	cmp Level,1
	mov fileNamePtr, offset map3.MapFile
	movzx eax, map3.PAcDots
	mov PacDotCount, eax
	jmp endprog
	Down2:
		mov fileNamePtr, offset map2.MapFile
		movzx eax, map2.PacDots
		mov PacDotCount, eax
	jmp endprog
	Down1:
		mov fileNamePtr, offset map1.MapFile
		movzx eax , map1.PacDots
		mov PacDotCount, eax
		endprog:
		ret

GetLevel endp

ResetGame proc
		mov score, 0
		call clrscr
		mov PacManX, 11
		mov PacManY, 16
		mov PacDotsConsumed, 0
	ret
ResetGame endp

end main