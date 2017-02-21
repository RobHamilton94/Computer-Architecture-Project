macro define/2
	asect $2
	$1:
mend

define stack, 0xf0 	# Gives the address 0xf0 the symbolic name stack
	
define HOReg, 0xf8 	# higher order address bits
define LOReg, 0xf9  	# lower order address bits

define IOData, 0xfa	# data to be written/read

define TTYKey, 0xfb	# TTY output or keyboard input

	asect 0x80
stringEnd: dc 0


		
	asect 0x00
start:
	ldi r0,stack
	stsp r0 # Sets the initial value of SP to 0xf0
	
	jsr getKey
	#jsr ramTest	# run test subroutine

halt

ramTest:
	# store value 22 in ram address 0x0010
	ldi r0, 0x00
	ldi r1, 0x10
	ldi r2, 22
	jsr ramStore

	# read value from address 0x0100
	ldi r0, 0x01
	ldi r1, 0x00
	jsr ramLoad
	
	# store value 49 in ram address 0x0110
	ldi r0, 0x01
	ldi r1, 0x10
	ldi r2, 49
	jsr ramStore	

	# read value from address 0x0101
	ldi r0, 0x01
	ldi r1, 0x01
	jsr ramLoad

# Saves r2 to address in (r1<<8) + r0
ramStore:
	save r3	# keep Subroutine clean
	
	ldi r3, HOReg
	st r3, r0		# load high order address bits into register
	
	ldi r3, LOReg	# load low order address bits into register
	st r3, r1
	
	ldi r3, IOData 	# store data from IOData into RAM
	st r3, r2		
	
	restore
	rts


ramLoad:	# result in r2
	
	save r3	# keep Subroutine clean
	
	ldi r3, HOReg	# load high order address bits into register
	st r3, r0
	
	ldi r3, LOReg	# load low order address bits into register
	st r3, r1
	
	ldi r3, IOData
	ld r3, r2		# read data from RAM into r2
	
	restore
	rts


getKey:
	
	loop:
		jsr readToTTY
		jsr writeFromKeyboard
		
		br loop
		
writeFromKeyboard:
	writeLoop:
		ldi r0, TTYKey	# load IO address
		ld r0, r1	# check for keyboard input
		if
			shl r1	# check msb for input flag
		is cc			# if no input then loop
			ldi r0, stringEnd
			ldi r1, 0
			st r0, r1	# reset stringEnd
			rts
		fi
		tst r1
		shr r1		# shift ascii back without msb
		
		move r1, r2		# place ascii data in r2 for ramstore

		ldi r0, stringEnd	# get string end address
		ld r0, r1
		clr r0
		
		jsr ramStore	# store character at string end
		
		inc r1
		ldi r0, stringEnd	# get string end address
		st r0, r1
		br writeLoop
	rts
	
readToTTY:
		ldi r0, TTYKey	# load IO address
		ld r0, r1	# check for keyboard input
		
		ldi r2, 0b11111111	# print from RAM mask
		
		and r2, r1	# compare key with mask
		if
			cmp r2, r1	# if key is 0b11111111
		is eq	
			readLoop:
				ldi r0, stringEnd	# get string end address
				ld r0, r1
				clr r0
				
				jsr ramLoad	# load character from ram
				
				if
					tst r2 # the data retrieved from ramLoad
				is nz		 # is not zero (end of phrase)
					ldi r0, TTYKey
					st r0, r2
					ldi r0, stringEnd	# get string end address
					ld r0, r1
					inc r1
					st r0, r1	# update stringEnd
					br readLoop
				fi
				ldi r0, stringEnd
				ldi r1, 0
				st r0, r1	# reset stringEnd
		fi
		rts
				
end





