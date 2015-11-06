TITLE PacMan, Authors: Mike Spallino

INCLUDE irvine32.inc
INCLUDE macros.inc

BUFFER_SIZE = 750
MAX_COORD = 22
MAP_WIDTH = 25

.data
buffer      BYTE   BUFFER_SIZE DUP(?)
filename    BYTE   80 DUP(0)
fileHandle  HANDLE ?
PacManX     BYTE   11
PacManY     BYTE   16
PrevX       BYTE   11
PrevY       BYTE   16
deltaX      SBYTE  0
deltaY      SBYTE  0
tempLoc     BYTE   ?

.code
main proc
	mWrite "Enter an input filename: "
	mov	edx,OFFSET filename
	mov	ecx,SIZEOF filename
	call ReadString
	call ReadMapFile                     ; Get a map
	call DrawPacMan
	MainLoop:                            ; Main loop
		call Render
		call Update
		jmp MainLoop
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
	call DrawMap
	call DrawPacMan
	ret
Render endp

; Map key presses to W,A,S,D
GetKey proc
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
CheckMapLoc proc
	mov edx, OFFSET buffer
	cmp PacManX, MAX_COORD
	jg DecX
	cmp PacManY, MAX_COORD
	jg DecY
	jmp CheckZero

	; We've moved too far forward in the X
	DecX:
		sub PacManX, 1
		jmp EndOfCheckMapLoc

	; We've moved too far forward in the Y
	DecY:
		sub PacManY, 1
		jmp EndOfCheckMapLoc

	CheckZero:
		cmp PacManX, 0
		jl IncX
		cmp PacManY, 0
		jl IncY
		jmp GetCoordChar

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
		cmp bl, '#'                      ; Was this a wall?
		je ResetPos                      ; Move back
		jmp RemoveChar                   ; It was consumable.

		ResetPos:
			call MoveBack 
			jmp EndOfCheckMapLoc

		RemoveChar:
			mov al, ' '
			mov [edx], al
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

; We should probably change this soon
; We won't want the ugly refresh thing we have now.
DrawMap proc USES edx
	call ClrScr
	mov	edx,OFFSET buffer	; display the buffer
	call	WriteString
	call	Crlf
	ret
DrawMap endp

; Draw Pac Man
DrawPacMan proc
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
	mov	edx,OFFSET filename
	call	OpenInputFile
	mov	fileHandle,eax

	; Check for errors.
	cmp	eax,INVALID_HANDLE_VALUE		; error opening file?
	jne	file_ok					; no: skip
	mWrite <"Cannot open file",0dh,0ah>
	jmp	quit						; and quit
	
	file_ok:

		; Read the file into a buffer.
		mov	edx,OFFSET buffer
		mov	ecx,BUFFER_SIZE
		call	ReadFromFile
		jnc	check_buffer_size			; error reading?
		mWrite "Error reading file. "		; yes: show error message
		call	WriteWindowsMsg
		jmp	close_file
	
		check_buffer_size:
			cmp	eax,BUFFER_SIZE			; buffer large enough?
			jb	buf_size_ok				; yes
			mWrite <"Error: Buffer too small for the file",0dh,0ah>
			jmp	quit						; and quit
	
		buf_size_ok:	
			mov	buffer[eax],0		; insert null terminator
			mWrite "File size: "
			call	WriteDec			; display file size
			call	Crlf

			; Display the buffer.
			mWrite <"Buffer:",0dh,0ah,0dh,0ah>
			call ClrScr
			call	WriteString

	close_file:
		mov	eax,fileHandle
		call	CloseFile

	quit:
		ret
ReadMapFile endp

end main