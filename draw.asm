; tile type in param1, X and Y position of tile in param2 and param3
; you should only call this during vblank or while bulk drawing with ppu off
drawTile:
	tya ; This is Y clobber prevention so that you can keep using Y to do other things if you like.
	pha

	lda param2
	asl a ; x multiplied by 0x02
	sta param2
	
	lda #$00
	sta tilePPUAddress
	lda param3
	sta tilePPUAddress + 1
	
	asl tilePPUAddress + 1 ; y multiplied by 0x40 (16 bit left shift six times)
	rol tilePPUAddress
	asl tilePPUAddress + 1
	rol tilePPUAddress 
	asl tilePPUAddress + 1 
	rol tilePPUAddress
	asl tilePPUAddress + 1
	rol tilePPUAddress 
	asl tilePPUAddress + 1
	rol tilePPUAddress 
	asl tilePPUAddress + 1
	rol tilePPUAddress
	
	clc ; x and y are added together
	lda param2
	adc tilePPUAddress + 1
	sta tilePPUAddress + 1
	bcc addDone
	inc tilePPUAddress
addDone:
	
	clc	; the sum of x and y are added to the value $20c0 which is the top part of the map screen
	lda tilePPUAddress + 1
	adc #$00
	sta tilePPUAddress + 1	
	
	lda tilePPUAddress
	adc #$20			
	sta tilePPUAddress
	
drawTileTop:
	lda $2002
	lda tilePPUAddress
	sta $2006
	lda tilePPUAddress + 1
	sta $2006	
	
	lda param1
	asl a
	asl a
	tay
	
	lda MetaTiles, y
	sta $2007
	iny
	lda MetaTiles, y
	sta $2007
	iny
	
	clc ; go down a row
	lda tilePPUAddress + 1
	adc #$20
	sta tilePPUAddress + 1
	
	bcc drawTileBottom
	inc tilePPUAddress
	
drawTileBottom:
	lda $2002
	lda tilePPUAddress
	sta $2006
	lda tilePPUAddress + 1
	sta $2006	

	lda MetaTiles, y
	sta $2007
	iny
	lda MetaTiles, y
	sta $2007
	iny
	
drawTileDone:
	pla ; This is the second and concluding portion of the Y clobber prevention.
	tay

	rts
	
; no arguments, draws the entire map (bulk drawing only! this is far too much to fit in vblank!)
drawMap:

	ldx #$00
mapByteLoop:
	
	lda MapData, x
	sta currentMapByte
	sta param1
	
	txa ; x coordinate (modulo 16)
	and #%00001111
	sta param2
	
	txa ; y coordinate (divided by 16 and floored)
	lsr a
	lsr a
	lsr a
	lsr a
	clc
	adc #MAP_DRAW_Y ; 3 metatiles added on to the position of the tile because hotbar
	sta param3
	
	jsr drawTile
	
	inx
	cpx #$c0
	bne mapByteLoop
	
drawUnits:
	
	ldx #$00
unitDrawLoop:
	
	
	rts
	
; this is like a bulk drawing version of something which will be done with a buffer soon
; param4/5: x and y position
; param6/7: width and height

; param2 temporarily used as the sum of the x+plus width
; param3 temporarily used as the sum of the y+plus height
drawTextBox:

	ldy param5
drawTextBoxYLoop:

	ldx param4
drawTextBoxXLoop:

	jsr loadTextboxTileToA
	sta param1 ; param1 holds the tiletype for now, which was previously loaded into A
	stx param2 ; param2 holds the x position for a little while, since X is occupied
	
	;sta param1 ; these lines uncommented would produce a bulk drawing result.
	;stx param2 ; maybe in the future there can be an additional parameter to switch between
	;sty param3 ; buffered textbox drawing and bulk textbox drawing. that would be pretty cool.
	;jsr drawTile
	
	txa ; x is temporarily used for indexing the tile buffer
	pha
	
	lda tileBufferLength ; bufferlength * 4 is the start position of the new item in the buffer to place
	asl a
	asl a
	tax 
	lda param1
	sta tileBuffer, x ; tiletype stored in param1 for now
	inx
	lda param2
	sta tileBuffer, x ; x value stored in param2 for now 
	inx
	tya
	sta tileBuffer, x ; y value directly stored in Y
	
	inc tileBufferLength
	
	pla ; the old x returns
	tax
	
	lda param4 ; param2 = (x + width)
	clc
	adc param6
	sta param2
	
	inx
	cpx param2
	bne drawTextBoxXLoop

	lda param5 ; param3 = (y + height)
	clc
	adc param7
	sta param3

	iny
	cpy param3
	bne drawTextBoxYLoop
	
	rts
	
loadTextboxTileToA:
	lda param4 ; param2 = (x + width)
	clc
	adc param6
	sta param2
	lda param5 ; param3 = (y + height)
	clc
	adc param7
	sta param3

checkX:
	cpx param4
	bne checkXSummed
	
	lda #$08
	cpy param5
	beq textBoxTileLoaded
	
	lda #$0e
	dec param3
	cpy param3
	beq textBoxTileLoaded
	
	lda #$0b
	jmp textBoxTileLoaded
	
checkXSummed:
	dec param2 ; its evaluating (width+x)-1
	lda param2

	cpx param2
	bne checkXOther
	
	lda #$0a
	cpy param5
	beq textBoxTileLoaded
	
	lda #$10
	dec param3
	cpy param3
	beq textBoxTileLoaded
	
	lda #$0d
	jmp textBoxTileLoaded
	
checkXOther:
	lda #$09
	cpy param5
	beq textBoxTileLoaded
	
	lda #$0f
	dec param3
	cpy param3
	beq textBoxTileLoaded
	
	lda #$0c
	
textBoxTileLoaded:	
	rts
	
; drawString works like this: you set stringPtr and strPPUAddress
; before you call this subroutine. As long as you do that, you're good to go!
; Oh, and make sure all your strings end in $ff, or else you get corrupto!!
; Also, newline character is $fe.

drawString:
	ldy #$00
	
setStringAddr:
	ldx strPPUAddress
	stx $2006
	ldx strPPUAddress + 1
	stx $2006

drawStringLoop:
	lda [stringPtr], y
	cmp #$ff
	beq drawStringDone
	
	cmp #$fe
	beq newLine
	
writeChar: 
	sta $2007
	iny

	jmp drawStringLoop

; newLine adds 40 to the initial nametable address where text starts rendering,
; moving it down 2 tiles = 16 pixels
newLine:	
	clc
	lda strPPUAddress + 1
	adc #$40
	sta strPPUAddress + 1
	
	bcc newLineDone
	inc strPPUAddress
	
newLineDone:
	iny
	jmp setStringAddr
	
drawStringDone:
	rts
	
; drawMapChunk behaves just like drawTextBox!
; param4/5: x and y position
; param6/7: width and height

; param2 temporarily used as the sum of the x+plus width
; param3 temporarily used as the sum of the y+plus height
drawMapChunk:

	ldy param5
drawMapChunkYLoop:

	ldx param4
drawMapChunkXLoop:

	; map tile has to get to A so here goes...
	tya
	sec
	sbc #MAP_DRAW_Y
	
	asl a
	asl a
	asl a
	asl a 
	stx param2
	clc
	adc param2 ; mapdata index = (y*16)+x
	sta param2 ; param2 stores the mapdata index temporarily
	
	txa ; frees x to be used for indexing the mapdata
	pha
	
	ldx param2
	lda MapData, x ; now A has the tile value, which is now given to param1
	sta param1
	
	pla ; x is back in business
	tax

	;jsr loadTextboxTileToA
	stx param2 ; param2 holds the x position for a little while, since X is occupied
	
	txa ; x is temporarily used for indexing the tile buffer
	pha
	
	lda tileBufferLength ; bufferlength * 4 is the start position of the new item in the buffer to place
	asl a
	asl a
	tax 
	lda param1
	sta tileBuffer, x ; tiletype stored in param1 for now
	inx
	lda param2
	sta tileBuffer, x ; x value stored in param2 for now 
	inx
	tya
	sta tileBuffer, x ; y value directly stored in Y
	
	inc tileBufferLength
	
	pla ; the old x returns
	tax
	
	lda param4 ; param2 = (x + width)
	clc
	adc param6
	sta param2
	
	inx
	cpx param2
	bne drawMapChunkXLoop

	lda param5 ; param3 = (y + height)
	clc
	adc param7
	sta param3

	iny
	cpy param3
	bne drawMapChunkYLoop
	
	rts