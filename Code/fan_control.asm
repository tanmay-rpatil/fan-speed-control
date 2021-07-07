#make_bin#

#LOAD_SEGMENT=FFFFh#
#LOAD_OFFSET=0000h#

#CS=0000h#
#IP=0000h#

#DS=0000h#
#ES=0000h#

#SS=0000h#
#SP=FFFEh#

#AX=0000h#
#BX=0000h#
#CX=0000h#
#DX=0000h#
#SI=0000h#
#DI=0000h#
#BP=0000h#

; add your code here 
;jump to the start of the code - reset address is kept at 0000:0000
;as this is only a limited simulation
;ffffe
         jmp     st1 ; go to rom start
;jmp st1 - takes 3 bytes followed by nop that is 4 bytes
         nop  
;int 1 is not used so 1 x4 = 00004h - it is stored with 0
         dw      0000
         dw      0000   
;nmi - is unused,
;remain at 0000 
		dw      0000
		dw      0000
		;then 3 are used up
		;EOC from ADC;int 3
		dw hrs_isr ;int 3
		dw 0000	
		dw eoc_isr ;4
		dw 0000  
		;1 sec speed control
		dw speed_isr ;int 5 
		dw 0000
			

;int 6 to int 255 unused so ip and cs intialized to 0000
;from 24 used	 
		 db   1000   dup(0) ; 

;memory allocations
org 1000h
	mod db 0; current mode of operation
	cur dw 0; current rpm read from sensor
	tar dw 100; target rpm 
	tub dw 120; 
	tlb dw 80; ?  
	hrs db 1; num from 1 to 9
	lv db 1; num from 1 to 5
	pwm db 80; num b/w 0 to 100 indicating 100-% duty cycle 
	modkey dw 0; store the current mode (8 bit) + current key ( 8 bit )  
	t_kbrd db  0eeh, 0edh, 0ebh, 0e7h, 0deh, 0ddh, 0dbh, 0d7h, 0beh, 0bdh, 0bbh, 0b7h, 7eh, 7dh, 7bh, 77h
	eocfl db 0
;set some macros for io devices 

	porta equ 0h ; 8255#1 7seg
	portb equ 2h ; 8255#1 adc 
	portc equ 4h ; 8255#1 keypad 
	cw155 equ 6h ; 8255#1 CW 
 
	bsrc equ 0ch ; 8255#2 BSR 
	cw255 equ 0eh ; 8255#2 CW 

	c041 equ 10h ; c0 54#1
	c141 equ 12h ; c1 54#1
	c241 equ 14h ; c2 54#1
	cw41 equ 16h ; cwd 54#1

	c042 equ 18h ; c0 54#2
	c142 equ 1ah ; c1 54#2
	c242 equ 1ch ; c2 54#2
	cw42 equ 1eh ; cwd 54#2

	pic1 equ 20h ;8259 
	pic2 equ 22h ;8259

org 0400h ; 
;main program
          
st1:      sti 
; intialize ds, es,ss to start of RAM
          mov       ax,0100h ;
          mov       ds,ax
          mov       es,ax
          mov       ss,ax
          mov       sp,0FFFEH ; 
          mov       si,0000 
          
;intialise 8255#1 A to op, B to ip , cup to i/p, cdown o/p
	mov al,10001010b
	out cw155, al
; intialise 8255#2 A to ip, B to i/p , c as o/p (to be used in BSR)
	mov al,10010010b ; 
	out cw255, al
; init the 8259	
	mov al,13h
	out pic1,al
	mov al,00h; take the Int ports down from 0 to 3
	out pic2,al
	mov al,01h
	out pic2,al
	mov al,11000111b ;ocw to mask interrupts
	out pic2,al
; diable times via BSR
	mov al,00000110b ;pwm disable
	out cw255,al
	mov al,00001000b ; 1hz disable
	out cw255,al
	mov al,00001010b ; hrs disable
	out cw255,al
; prog all timers in 8254 
	mov al,00110110b   ;prog c041 mod 3 l+m bin 1000 count
	out cw41,al
	;load lsb and Msb 1000d = 03e8h
	mov al,0e8h
	out c041,al
	mov al,03h
	out c041,al
	
	mov al,01110110b   ;prog c141 mod 3 l+m bin 100 count
	out cw41,al
	;load lsb and Msb 100 = 0064h
	mov al,64h
	out c141,al
	mov al,00h
	out c141,al

	mov al,10110010b   ;prog c241 mod 1 l+m bin
	out cw41,al
	;load lsb and Msb pwm (8bit val)
	mov al,pwm
	out c241,al
	mov al,00h
	out c241,al

	mov al,00110100b   ;prog c042 mod 2 l+m bin 
	out cw42,al ;
	;load lsb and Msb 50 = 32h
	mov al,32h
	out c042,al
	mov al,00h
	out c042,al

	mov al,01110100b   ;prog c142 mod 2 l+m bin
	out cw42,al ;
	;load lsb and Msb hrs * 3600
	mov ax,0e10h ;3600
	mov cl,hrs ; 1 to 5
	mov ch,0
	mul cx ; ax now has n*3600
	out c142,al
	ror ax,4 ; get MSB in al
	out c142,al


;check for keyboard ip
	a0: ;display the lv, then take ip 
		; if mode==off disp 0 TODO
		cmp mod, 0
		je dis0
		;not 0
		mov		al,lv
		out		porta,al 
		dis0: mov al,0
			out porta,al 

		mov     al, 00h
		out     portc, al
	a1: in      al, portc
		and     al, 0f0h
		cmp     al, 0f0h    ;check for key release
		jnz     a1
		call    delay20 	  
		mov     al, 00h
		out     portc, al
	a2: in      al, portc
		and     al, 0f0h
		cmp     al, 0f0h
		jz      a2
		call    delay20 	
		
		;validity of key press
		mov     al, 00h
		out     portc, al
		in      al, portc
		and     al, 0f0h
		cmp     al, 0f0h
		jz      a2
		
		;key press column 1
		mov     al, 0eh
		mov     bl, al
		out     portc, al
		in      al, portc
		and     al, 0f0h
		cmp     al, 0f0h
		jnz     a3
		
		;press column 2
		mov     al, 0dh
		mov     bl, al
		out     portc, al
		in      al, portc
		and     al, 0f0h
		cmp     al, 0f0h
		jnz     a3
		
		;key press column 3
		mov     al, 0bh
		mov     bl, al
		out     portc, al
		in      al, portc
		and     al, 0f0h
		cmp     al, 0f0h
		jnz     a3
		
		;key press column 4
		mov     al, 07h
		mov     bl, al
		out     portc, al
		in      al, portc
		and     al, 0f0h
		cmp     al, 0f0h
		jz      a2
		
		;decode key
	a3: or      al, bl
		mov     cx, 0fh
		mov     di, 00h
		lea     di, ds:t_kbrd
		
	a4: cmp     al, [di]
		jz      a5
		inc     di
		loop    a4
	a5: ;save key value in mem
		mov ah,mod
		mov modkey,ax ;save curr mode and key in mem
		jmp key_proc
		;
;processes for keypress     
	off:
		mov mod,0
		mov al,00000110b ;pwm disable
		out cw255,al
		mov al,00001000b ; 1hz disable
		out cw255,al
		mov al,00001010b ; hrs disable
		out cw255,al
		jmp a0
	on:
		mov mod,1
		start:mov al,00000111b ;pwm enable
			out cw255,al
			mov al,00001001b ; 1hz enable
			out cw255,al
			int 5h ; 
			jmp a0
	auto:
		mov mod,3
		;write hours into 8254#2
		mov ax,0e10h ;3600
		mov cl,hrs ; 1 to 9
		mov ch,0
		mul cx ; ax now has n*3600
		out c142,al
		ror ax,4 ; get MSB in al
		out c142,al
			mov al,00000111b ;pwm enable
			out cw255,al
			mov al,00001001b ; 1hz enable
			out cw255,al
			mov al,00001011b ; hrs enable
			out cw255,al
			jmp a0
	aut_1: 
		mov hrs,1
		jmp auto
	aut_2: 
		mov hrs,2
		jmp auto
	aut_3: 
		mov hrs,3
		jmp auto
	aut_4: 
		mov hrs,4
		jmp auto
	aut_5: 
		mov hrs,5
		jmp auto
	aut_6: 
		mov hrs,6
		jmp auto
	aut_7: 
		mov hrs,7
		jmp auto
	aut_8: 
		mov hrs,8
		jmp auto
	aut_9: 
		mov hrs,9
		jmp auto
	lv_1:
		mov lv,1
		mov tar,100
		mov tub,120
		mov tlb,80
		;check if mode is not off
		cmp mod,0
		je a0
		;else go for a speed check
		int 5h ; 
		jmp a0 ; ????????????? call int?
	lv_2:
		mov lv,2
		mov tar,200
		mov tub,220
		mov tlb,180
		;check if mode is not off
		cmp mod,0
		je a0
		;else go for a speed check
		int 5h ; 
		jmp a0 ; ????????????? call int?
	lv_3:
		mov lv,3
		mov tar,300
		mov tub,320
		mov tlb,280
		;check if mode is not off
		cmp mod,0
		je a0
		;else go for a speed check
		int 5h ; 
		jmp a0 ; 
	lv_4:
		mov lv,4
		mov tar,400
		mov tub,420
		mov tlb,380
		;check if mode is not off
		cmp mod,0
		je a0
		;else go for a speed check
		int 5h ; 
		jmp a0 ; 
	lv_5:
		mov lv,5
		mov tar,500
		mov tub,510 ; ??????????? target rpm BT
		mov tlb,480
		;check if mode is not off
		cmp mod,0
		je a0
		;else go for a speed check
		int 5h ; 
		jmp a0
	up: 
		cmp lv,5
		je a0 ; no change if max level
		inc lv
		add tar,100
		add tub,100
		add tlb,100
		;check if mode is not off
		cmp mod,0
		je a0
		;else go for a speed check
		int 5h ; 
		jmp a0 ; 
	down:
		cmp lv,1
		je a0 ; no change if min level
		dec lv
		sub tar,100
		sub tub,100
		sub tlb,100
		;check if mode is not off
		cmp mod,0
		je a0
		;else go for a speed check
		int 5h ; 
		jmp a0 ; 
	wt_4:
		mov mod,2
		jmp a0

key_proc: mov ax,modkey ;check what action to take
	cmp al,0eeh; check if off button
	je off
	cmp ax,00bbh; off->on
	je on
	cmp ax,02bbh; wt_4_auto->on
	je auto
	cmp ax,007dh; off->auto
	je wt_4
	cmp ax,017dh; normal->auto
	je wt_4
	cmp al,0b7h; up
	je up
	cmp al,07eh; down
	je down
	cmp ax,02edh; wt_4_auto -> num
	je aut_1
	cmp ax,02ebh; wt_4_auto -> num
	je aut_2
	cmp ax,02e7h; wt_4_auto -> num
	je aut_3
	cmp ax,02deh; wt_4_auto -> num
	je aut_4
	cmp ax,02ddh; wt_4_auto -> num
	je aut_5
	cmp ax,02dbh; wt_4_auto -> num
	je aut_6
	cmp ax,02d7h; wt_4_auto -> num
	je aut_7
	cmp ax,02beh; wt_4_auto -> num
	je aut_8
	cmp ax,02edh; wt_4_auto -> num
	je aut_9
	;nums here mean speed lv
	cmp al,0edh;  num
	je lv_1
	cmp al,0ebh;  num
	je lv_2
	cmp al,0e7h;  num
	je lv_3
	cmp al,0deh;  num
	je lv_4
	cmp al,0ddh;  num
	je lv_5

	;reached at end means not significant
	jmp a0

;Delay of 20ms Proc
delay20 proc near
    mov     cx, 2220 ;redo this calculation
x9: loop    x9
    ret
delay20 endp

;ISRs 
speed_isr: ;read speed, and adjust op
	sti ; to allow intr
	;cs' low pc0 low
	mov al,00000000b
	out cw255,al
	nop ;wait

	;wr' low pc2 low
	mov al,00000100b
	out cw255,al
	nop ;wait appx .6microsec > [tw*(wr') = 100ns]

	;wr' high pc2 high
	mov al,00000101b
	out cw255,al
		
	wt:	nop ;wait
		cmp eocfl,0
		je wt

	mov eocfl,0
	;cur has current rpm
	mov ax,cur
	cmp ax, tub
	jg dec_pwm
	cmp ax, tlb
	jl inc_pwm 
	;here if in range
	jmp quit

	dec_pwm: ;here to dec pwm
		cmp pwm,91 ;so doesn't go above 94, hence min is 6%
		jge quit
		add pwm,4 ; because 100-pwm has to decrease
		mov al,pwm
		out c241,al
		jmp quit
	inc_pwm: ;here to inc pwm
		cmp pwm,9 ; so doesn't go below 6, max is 94%
		jle quit
		sub pwm,4 ; because 100-pwm has to inc
		mov al,pwm
		out c241,al

	quit:	; OCW 2 Non spec EOI
			mov al,00100000b
			out pic1,al
			iret

eoc_isr: ;read data from adc 
	;cs' low pc0 low
	mov al,00000000b
	out cw255,al
	nop ;wait

		mov CX,20
	rdwt:	nop 
			loop rdwt  ; time delay of 20*0.6 > [8 clk pds of adc apx 10microsec ]

	;rd' low pc1 low
	mov al,00000010b
	out cw255,al
	nop ;wait for tacc > 200ns 

	in al,portb
	mov ah,0
	shl ax,1 ; rpm = 2*adc_value
	mov cur,ax ;save current reading

	;rd' high pc1 high
	mov al,00000011b
	out cw255,al
	;cs' high pc0 high
	mov al,00000001b
	out cw255,al

	mov eocfl,1
	; OCW 2 Non spec EOI
	mov al,00100000b
	out pic1,al
	iret


hrs_isr: ; here if hours has expired
	; disable everything
	mov mod,0; set mode to off
	mov al,00000110b ;pwm disable
	out cw255,al
	mov al,00001000b ; 1hz disable
	out cw255,al
	mov al,00001010b ; hrs disable
	out cw255,al
	;done disabling devices, return
	; OCW 2 Non spec EOI
	mov al,00100000b
	out pic1,al
	iret