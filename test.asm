;VARIABLES

PPU_CTRL    =   $2000	; PPU
PPU_MASK    =   $2001
PPU_STATUS  =   $2002	;can be used for vBlank checks
OAM_ADDR    =   $2003
OAM_DATA    =   $2004
PPU_SCROLL  =   $2005
PPU_ADDR    =   $2006
PPU_DATA    =   $2007
OAM_DMA     =   $4014

SQR1_VOLUME =   $4000	; APU
SQR1_SWEEP  =   $4001
SQR1_LOW    =   $4002
SQR1_HIGH   =   $4003
DMC_CONFIG  =   $4010
APU_STATUS  =   $4015
CONTROLLER_1=   $4016
CONTROLLER_2=   $4017
APU_FRAMES  =   $4017


	;my variables
INPUT_TEMP  =   $00
INPUT_1     =   $01
INPUT_2     =   $02

TETRO       =   $90
T_ID        =   TETRO
T_X         =   TETRO + $01
T_Y         =   TETRO + $02
T_COUNT     =   TETRO + $03
T_NEXT      =   TETRO + $04
T_RANDOM    =   TETRO + $05
T_TEMP      =   TETRO + $0a
RELATIVE_X  =   $a0
RELATIVE_Y  =   RELATIVE_X + $03

LEVEL_TEMP  =   $ff
LEVEL_TILES =   $0100

.segment "HEADER"
  ; .byte "NES", $1A      ; iNES header identifier
  .byte $4E, $45, $53, $1A
  .byte 2               ; 2x 16KB PRG code
  .byte 1               ; 1x  8KB CHR data
  .byte $01, $00        ; mapper 0, vertical mirroring

.segment "VECTORS"
  ;; When an NMI happens (once per frame if enabled) the label nmi:
  .addr nmi
  ;; When the processor first turns on or is reset, it will jump to the label reset:
  .addr reset
  ;; External interrupt IRQ (unused)
  .addr 0

; "nes" linker config requires a STARTUP section, even if it's empty
.segment "STARTUP"

; Main code segement for the program
.segment "CODE"

reset:
  sei		; disable IRQs
  cld		; disable decimal mode
  ldx #$40
  stx APU_FRAMES; disable APU frame IRQ
  ldx #$ff 	; Set up stack
  txs		;  .
  inx		; now X = 0
  stx PPU_CTRL	; disable NMI
  stx PPU_MASK 	; disable rendering
  stx DMC_CONFIG; disable DMC IRQs

;; first wait for vblank to make sure PPU is ready
vblankwait1:
  bit PPU_STATUS
  bpl vblankwait1

clear_memory:
  lda #$00
  sta $0000, x
  sta $0100, x
  sta $0200, x
  sta $0300, x
  sta $0400, x
  sta $0500, x
  sta $0600, x
  sta $0700, x
  inx
  bne clear_memory

;; second wait for vblank, PPU is ready after this
vblankwait2:
  bit PPU_STATUS
  bpl vblankwait2

;████████████████████████████████████████████████████████████████

main:

load_palletes:
 lda PPU_STATUS
 lda #$3f
 sta PPU_ADDR
 lda #$10
 sta PPU_ADDR

 ldx #$00
 @loop:
 lda palletes,x
 sta PPU_DATA
 inx
 cpx #$20
 bne @loop

enable_rendering:
 lda #%00000001 	;select nametables
 sta PPU_CTRL
 lda #%00011010
 sta PPU_MASK


init_sound:
 lda #$01		;music n stuff
 sta APU_STATUS
 lda #%00000000
 sta SQR1_SWEEP
 sta SQR1_VOLUME
 lda #$40
 sta APU_FRAMES

;████████████████████████████████████████████████████████████████

play_init:
 ldx #$00
 @vertical_border:
 lda #$01
 sta LEVEL_TILES, x
 sta LEVEL_TILES + $0d, x
 sta LEVEL_TILES + $0e, x
 sta LEVEL_TILES + $0f, x

 txa
 clc
 adc #$10
 tax
 cpx #$e0
 bne @vertical_border

 lda #$01
 ldx #$00
 @horizontal_border:
 sta LEVEL_TILES + $e0, x

 inx
 cpx #$10
 bne @horizontal_border

	;background palettes
 lda #$23
 sta PPU_ADDR
 lda #$c0
 sta PPU_ADDR

 ldx #$00
 @colors_loop:
 lda #%11001100
 sta PPU_DATA
 lda #%11111111
 sta PPU_DATA
 sta PPU_DATA
 sta PPU_DATA
 sta PPU_DATA
 sta PPU_DATA
 lda #%00110011
 sta PPU_DATA
 lda #%00000000
 sta PPU_DATA

 inx
 cpx #$07
 bne @colors_loop

 ldx #$00
 @colors_final_loop:
 sta PPU_DATA

 inx
 cpx #$08
 bne @colors_final_loop

 jsr update_bg
 jmp play_frame_do

;████████████████████████████████████████████████████████████████

update_bg:

 lda #$00
 sta LEVEL_TEMP
 @level_wait:
 bit PPU_STATUS
 bmi @level_do
 jmp @level_wait

 @level_do:

 @row:
 lda LEVEL_TEMP
 lsr
 lsr
 lsr
 lsr
 clc
 adc #$20
 sta PPU_ADDR
 lda LEVEL_TEMP
 asl
 asl
 asl
 asl
 sta PPU_ADDR
 lda LEVEL_TEMP
 asl
 asl
 tax

 @x_1:
 lda LEVEL_TILES, x
 sta PPU_DATA
 sta PPU_DATA
 
 inx
 txa
 and #$0f
 cmp #$00
 bne @x_1

 lda LEVEL_TEMP
 asl
 asl
 tax
 @x_2:
 lda LEVEL_TILES, x
 sta PPU_DATA
 sta PPU_DATA
 
 inx
 txa
 and #$0f
 cmp #$00
 bne @x_2

 inc LEVEL_TEMP
 inc LEVEL_TEMP
 inc LEVEL_TEMP
 inc LEVEL_TEMP

 lda LEVEL_TEMP
 cmp #$3c
 beq @load_end

 lda LEVEL_TEMP 
 and #%00000111
 cmp #$00
 bne @level_wait
 jmp @row

 @load_end:

 lda #$00
 sta PPU_SCROLL
 sta PPU_SCROLL

 rts

;████████████████████████████████████████████████████████████████

play_frame_do:

 lda INPUT_1
 and #%00000001
 cmp #%00000001
 bne @not_press

 jsr update_bg

 @not_press:

 inc T_RANDOM

;████████████████████████████████████████████████████████████████
 
play_loop:

 jsr controller

 bit PPU_STATUS
 bmi vBlankDo
 
 jmp play_loop

vBlankDo:
 lda #$00
 sta OAM_ADDR

 lda T_Y
 sta OAM_DATA
 lda #%00000001
 sta OAM_DATA
 lda #%00000000
 sta OAM_DATA
 lda T_X
 sta OAM_DATA

 ldx #$00
 @other_3_blocks_loop:
 lda T_Y
 clc
 adc RELATIVE_Y, x
 sta OAM_DATA
 lda #%00000001
 sta OAM_DATA
 lda #%00000000
 sta OAM_DATA
 lda T_X
 clc
 adc RELATIVE_X, x
 sta OAM_DATA

 inx
 cpx #$03
 bne @other_3_blocks_loop

 jmp play_frame_do


;████████████████████████████████████████████████████████████████

controller:
 lda #$01	;init controller 1
 sta CONTROLLER_1
 sta INPUT_TEMP
 lda #$00
 sta CONTROLLER_1
 
 @controller_loop_1:
 lda CONTROLLER_1
 lsr
 rol INPUT_TEMP
 bcc @controller_loop_1
 lda INPUT_TEMP
 sta INPUT_1

 lda #$01	;init controller 2
 sta CONTROLLER_2
 sta INPUT_TEMP
 lda #$00
 sta CONTROLLER_2
 
 @controller_loop_2:
 lda CONTROLLER_2
 lsr
 rol INPUT_TEMP
 bcc @controller_loop_2
 lda INPUT_TEMP
 sta INPUT_2

 rts

;████████████████████████████████████████████████████████████████

nmi:
 rti

;████████████████████████████████████████████████████████████████

	;palletes and stuff
palletes:
	;oem sprites
 .byte $0f, $03, $13, $23
 .byte $0f, $04, $14, $24
 .byte $0f, $06, $16, $26
 .byte $0f, $00, $10, $20

	;background
 .byte $2c, $04, $14, $34
 .byte $20, $04, $14, $34
 .byte $0f, $04, $14, $24
 .byte $0f, $06, $16, $26

tetrominoes:	;2 bytes per tetromino in 4x4 grid
 .byte %01000100, %01000100	;|
 .byte %11000100, %01000000	;ꓶ
 .byte %11001000, %10000000	;Γ
 .byte %01001110, %00000000	;ꓕ
 .byte %01101100, %00000000	;s
 .byte %11000110, %00000000	;z
 .byte %11001100, %00000000	;█

;████████████████████████████████████████████████████████████████

; Character memory
.segment "CHARS"

  .byte %00000000; empty but in binary
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000;
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000

  .byte %11111111; full
  .byte %11111111
  .byte %11111111
  .byte %11111111
  .byte %11111111
  .byte %11111111
  .byte %11111111
  .byte %11111111
  .byte %11111111;
  .byte %11111111
  .byte %11111111
  .byte %11111111
  .byte %11111111
  .byte %11111111
  .byte %11111111
  .byte %11111111

  .byte %00000000; |
  .byte %00011000
  .byte %00011000
  .byte %00011000
  .byte %00011000
  .byte %00011000
  .byte %00011000
  .byte %00000000
  .byte %00000000;
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000

  .byte %00000000; ꓶ
  .byte %00111100
  .byte %00111100
  .byte %00001100
  .byte %00001100
  .byte %00001100
  .byte %00000000
  .byte %00000000
  .byte %00000000;
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000

  .byte %00000000; Γ
  .byte %00111100
  .byte %00111100
  .byte %00110000
  .byte %00110000
  .byte %00110000
  .byte %00000000
  .byte %00000000
  .byte %00000000;
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000

  .byte %00000000; ꓕ
  .byte %00000000
  .byte %00111100
  .byte %00111100
  .byte %01111110
  .byte %01111110
  .byte %00000000
  .byte %00000000
  .byte %00000000;
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000

  .byte %00000000; s
  .byte %00000000
  .byte %00001100
  .byte %00011110
  .byte %01011010
  .byte %01111000
  .byte %00110000
  .byte %00000000
  .byte %00000000;
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000

  .byte %00000000; z
  .byte %00000000
  .byte %00110000
  .byte %01111000
  .byte %01011010
  .byte %00011110
  .byte %00001100
  .byte %00000000
  .byte %00000000;
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000

  .byte %00000000; █
  .byte %00111100
  .byte %01011010
  .byte %01111110
  .byte %01111110
  .byte %01011010
  .byte %00111100
  .byte %00000000
  .byte %00000000;
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
