macro define/2
	asect $2
	$1:
mend

define stack, 0xf0 	# Gives the address 0xf0 the symbolic name stack
	
define HOReg, 0xf8 	# higher order address bits
define LOReg, 0xf9  	# lower order address bits

define IOData, 0xfa	# data to be written/read

define TTYKey, 0xfb	# TTY output or keyboard input

# file structure
# pos 1 = filename
# pos 2 = RAM address
# pos 3 = file length

	asect 0x00

start:
	ldi r0,stack
	stsp r0 # Sets the initial value of SP to 0xf0
	
	jsr getKey

halt

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
	
	keyLoop:
		ldi r0, TTYKey	# r0 = IO address
		ld r0, r1	# r1 = keyboard input
		
		ldi r3, 0b11111111	# print from RAM mask
		move r1, r2			# r2 = keyboard input
		if
			cmp r3, r2	# if key is 0b11111111
		is eq
			jsr readToTTY	# read from RAM	
		else
			if
				shl r1	# check msb for input flag
			is cs			# if msb set, key has been pressed
				shr r1
				jsr setFileData
			else
				br keyLoop
			fi
		fi
		
		br keyLoop
		
		
clearBuffer:
		ldi r0, TTYKey	# load IO address
		ldi r1, 0xff
		st r0, r1
		rts


		
setFileData:	# r1 = ascii character for filename
				
		jsr setFileLocation	# retrieve next available file location (D-mem)
						# r0 = file location
		
		ldi r3, 0xff
		if 
			cmp r3, r0	# if file locations not full
		is nz
			jsr getRAMAddress	# r2 = retrieve next available file location (RAM)
			jsr writeFromKeyboard
		else
			jsr clearBuffer
		fi
		rts
		
	
	
		
writeFromKeyboard:	# r0 = file location	
				# r1 = filename
				# r2 = ram address
	
	push r1	# save filename	
	push r0	# save file location
	push r2	# save ram address
	
	clr r3	# string length counter
	writeLoop:
		
		
		ldi r0, TTYKey	# load IO address
		ld r0, r2	# check for keyboard input
		if
			shl r2	# check msb for input flag
		is cs			# if no input then loop
			
			shr r2		# shift ascii back without msb
		
			
			pop r1	# r1 = ram address
			push r1
			add r3, r1	# r1 = ram address + offset
			clr r0
			
			jsr ramStore	# store character at ram address
			inc r3
			br writeLoop

		else
			
					
			pop r1	# r1 = ram address
			pop r0	# r0 = file location
			pop r2	# r2 = file name
					# r3 = string length
			
			st r0, r2	# store filename in D-MEM
			inc r0
			st r0, r1	# store ram address in D-MEM
			inc r0
			st r0, r3	# store string length in D-MEM
			
			rts
		fi
		
		
	rts
				
setFileLocation:	# returns d-mem filedata location to store in r0
	
	push r1
	push r2
	
	ldi r0, 0		# load first D-Mem address of file data
	
	while
		ldi r2, 0b11100000	# r2 = max d-mem address (0xE0)
		and r0, r2
	stays eq
		ld r0, r3	# load ram address of current file name
		if
			tst r3 # if no file name (empty file)
		is eq
			pop r2
			pop r1
			clr r3
			rts
		else
			inc r0	# move to next file position in d-mem
			inc r0
			inc r0		
		fi
	wend
	pop r2
	pop r1
	ldi r0, 0xff	# return all file locations full
	rts

getRAMAddress:	# returns next free ram address in r2
	push r0	# save d-mem file location
	ldi r0, 0	# r0 = first d-mem file location
	
	while
		ldi r2, 0b11100000	# r2 = max d-mem address (0xE0)
		and r0, r2
	stays eq
		ld r0, r2		# load file name
		if
			tst r2	# if file filled (not empty)
		is eq
				if
					tst r0
				is gt
					dec r0	# move back to last
					dec r0	# filled file ram address
				else
					inc r0	# move to first file ram address
				fi
				
				push r1	# r1 = new file name
				ld r0, r1	# load ram address
				inc r0	# get last file string length
				ld r0, r2	# load string length
				
				add r1, r2	# next free ram address = last address + offset
				pop r1	# r1 = file name
				pop r0	# r0 = d-mem file location
				rts
		else
			
			if 
				tst r0	# no files saved
			is eq, and			
				tst r2	# no file name
			is eq
				pop r0	# r0 = d-mem file location
				clr r2	# 0 = return all file locations empty
				rts
			else
				inc r0	# move to next file location
				inc r0
				inc r0	
			fi
		fi
	wend


	rts

readToTTY:
		readLoop:
			ldi r0, TTYKey	# r0 = IO address
			ld r0, r1	# r1 = keyboard input
				
			if
				shl r1	# check msb for input flag
			is cc			# if msb set, key has been pressed
				br readLoop
			else
				shr r1
				move r1, r0	# r0 = filename	
				
				jsr getFileLocation	# get address and length
								# r1 = address
								# r2 = length
								
				ldi r3, 0xff
				if 
					cmp r3, r1	# if file locations not full
				is nz				
					ldi r0, TTYKey
					clr r3	# string count
					while
						cmp r2, r3	# while not end of string
					stays gt
						push r2
						clr r0
							jsr ramLoad	# get string char from ram
							ldi r0, TTYKey
							st r0, r2	# print to TTY
						pop r2
						inc r1
						inc r3
					wend
				else
				jsr clearBuffer
				fi
			fi	

		rts


getFileLocation:	# input r0 = filename
			# output r1 = ram address
			# output r2 = string length
	
	ldi r1, 0		# r1 = current file
	while
		ldi r2, 0b11100000	# r2 = max d-mem address (0xE0)
		and r1, r2
	stays eq
		ld r1, r3	# r3 = filename
	
		if
			cmp r0, r3	# if file found
		is eq
			inc r1
			move r1, r2
			inc r2	# r2 = address of string length
			ld r1, r1	# r1 = ram address
			ld r2, r2	# r2 = string length
			clr r3	# keep subroutine clean
			rts	# return ram address and string length
		else
			inc r1	# move to next
			inc r1	# d-mem filename
			inc r1
		fi
	wend
	
	ldi r1, 0xff	# return file not found
	rts
				
end





