###############################################################################
# Name:		Programming problem 6
#
# Description:	The purpose of this program is to provide an understanding of
#		exception handling.  
#
# Class:	CS354
#
# Written by:	YOUR NAME???
# Section :	???
#
# Date:		WHAT'S THE DATE???
###############################################################################

###############################################################################
# KERNEL KERNEL KERNEL KERNEL KERNEL KERNEL KERNEL KERNEL KERNEL KERNEL KERNEL
#
# NOTE:  all labels in the kernel are prefixed with _k_ to avoid conflicting
# with labels in the user code.  Therefore, user code should NEVER use the
# _k_ prefix.
#
###############################################################################

#
# Assign addresses to labels
#
		.eq	KeyboardData	0xbfff0000
		.eq	KeyboardStatus	0xbfff0004
		.eq	DisplayData	0xbfff0008
		.eq	DisplayStatus	0xbfff000c
		.eq	KeyboardData2	0xbfff0010
		.eq	KeyboardStatus2	0xbfff0014
		.eq	DisplayData2	0xbfff0018
		.eq	DisplayStatus2	0xbfff001c
		.eq	ClockStatus	0xbfff0020

#
# Interrupt masks
#
# Interrupt     Bit name        Bit Number      Mask
# ------------- --------------- --------------- ----------
# clock         IP(0)           10              0x00000400
# keyboard 0    IP(1)           11              0x00000800
# display 0     IP(2)           12              0x00001000
# keyboard 1    IP(3)           13              0x00002000
# display 1     IP(4)           14              0x00004000

###############################################################################
#                                Kernel data                                  #
###############################################################################
		.kdata

#   Flag is set to one when executing in the kernel so that if the kernel is
#   re-entered and the exception return address is lost an error is printed.
#   This flag will help to notice problems.  It will not prevent them.

_k_flag:		.word	 0 

#   Storage to preserve registers used by the kernel.  Since the kernel may
#   interrupt the user code at any time without the user code being aware or
#   it, it is necessary to preserve all registers used in the kernel, excluding
#   of course $k0 and $k1 which should not be used by user code.

_k_save_r1:	.word	0	# $1
_k_save_v0:	.word	0	# $v0
_k_save_a0:	.word	0	# $a0
_k_save_a1:	.word	0	# $a1
_k_save_a2:	.word	0	# $a2
_k_save_a3:	.word	0	# $a3
_k_save_ra:	.word	0	# $ra
_k_save_t0:	.word	0	# $t0
_k_save_t1:	.word	0	# $t1
_k_save_t2:	.word	0	# $t2
_k_save_t3:	.word	0	# $t3
_k_save_t4:	.word	0	# $t4

#
# Kernel messages
#

_k_msg_reentry:	.asciiz	"Bad re-entry into kernel\nHalting\n"
_k_msg_nl:	.asciiz	"\n"


#
# Jump Table: each entry is the address of the handler to run when the 
# corresponding exception occurs (as dictated by the value in ExcCode)
#
	.align	2
_k_JumpTable:
		.word	_k_HandleInt	# External Interrupt
		.word	_k_HandleMOD	# TLB modification exception
		.word	_k_HandleTLBL	# TLB miss exception (load or fetch)
		.word	_k_HandleTLBS	# TLB miss exception (store)
		.word	_k_HandleAdEL	# Address error exception
					#   (load or fetch)
		.word	_k_HandleAdES	# Address error exception (store)
		.word	_k_HandleIBE	# Bus error exception (for a fetch)
		.word	_k_HandleDBE	# Bus error exception
					#   (for a load or store)
		.word	_k_HandleSys	# Syscall exception
		.word	_k_HandleBp	# Breakpoint exception
		.word	_k_HandleRI	# Reserved Instruction exception
		.word	_k_HandleCpU	# Coprocessor Unusable exception
		.word	_k_HandleOvf	# Arithmetic overflow exception
		.word	_k_HandleFPInexact	# Inexact floating point result
		.word	_k_HandleDivideBy0	# Divide by 0
		.word	_k_HandleFPOvf
		.word	_k_HandleFPUnder
		.word	_k_HandleReserved, _k_HandleReserved
		.word	_k_HandleReserved, _k_HandleReserved
		.word	_k_HandleReserved, _k_HandleReserved
		.word	_k_HandleReserved, _k_HandleReserved
		.word	_k_HandleReserved, _k_HandleReserved
		.word	_k_HandleReserved, _k_HandleReserved
		.word	_k_HandleReserved, _k_HandleReserved
		.word	_k_HandleReserved, _k_HandleReserved


###############################################################################
#                                Kernel code                                  #
#                                                                             #
# Note: this kernel is not reentrant.  It attempts to determine if reentry    #
# has occurred and panics if it detects such a case.  In theory, this should  #
# only happen if a bug has been introduced into the kernel.                   #
###############################################################################

		.ktext

#
# Skip space so kernel starts at 0x80000080
#
		.space	0x80

#
# Save register one so that, when the assembler uses it, we don't have to
# worry about it affecting the user code.  Note, we save it by moving it to
# $k1 because doing a sw $1, _k_save_r1 would result in the assembler using $1
# for the immediate address of _k_save_r1, destroying the very value we are
# attempting to save.
#
		.set	noat
		move	$k1, $1
		.set	at

#
# Check for kernel reentry; panic if it occurred, other set the flag
# to indicate that we are in the kernel.  Could also just check status bit
# KUp, but it was already written this way *shrug*
#
		lw	$k0, _k_flag
		beqz	$k0, _k_OK
		la	$a0, _k_msg_reentry
		j	_k_Panic
_k_OK:
		li	$k0, 1
		sw	$k0, _k_flag

#
# Save all of the registers that are used by the kernel.  When making
# modifications to the kernel, if you use registers other than the ones listed
# here, you must insert code here to save them and code below (see Return) to
# restore them.
#
		sw	$k1, _k_save_r1
		sw	$v0, _k_save_v0
		sw	$a0, _k_save_a0
		sw	$a1, _k_save_a1
		sw	$a2, _k_save_a2
		sw	$a3, _k_save_a3
		sw	$ra, _k_save_ra
		sw	$t0, _k_save_t0
		sw	$t1, _k_save_t1
		sw	$t2, _k_save_t2
		sw	$t3, _k_save_t3
		sw	$t4, _k_save_t4

#
# Determine what caused the exception and jump to the appropriate handler.
# The appropriate handler is determined by get the handler address from
# the jump table (_k_Jump_Table) array.
#

#   get the cause register and obtain just the ExcCode bits, the ExcCode
#   indicate caused the exception (see table 12.1 on page 316 of your book

		mfc0	$k0, $13
		and	$k0, $k0, 0x3c

#   get the address of the handler address associated with this exception, and
#   jump to it

		lw	$k0, _k_JumpTable($k0)
		j	$k0

#
# Get the exception program counter, increment it to skip the instruction
# caused the exception, store it back, and then return
#
_k_IncReturn:
		mfc0	$k1, $14
		add	$k1, $k1, 4
		mtc0	$k1, $14

#
# Return to the user code.  All handlers that return (i.e., do not panic or
# halt the system) do so by jumping here.
#

_k_Return:	

#   Restore all of the registers used by the kernel (except for $1)

		lw	$2, _k_save_v0
		lw	$4, _k_save_a0
		lw	$5, _k_save_a1
		lw	$6, _k_save_a2
		lw	$7, _k_save_a3
		lw	$31, _k_save_ra
		lw	$8, _k_save_t0
		lw	$9, _k_save_t1
		lw	$10, _k_save_t2
		lw	$11, _k_save_t3
		lw	$12, _k_save_t4

#   Clear the reentrancy flag

		li	$k1, 0
		sw	$k1, _k_flag

#   Now restore $1 as well

		lw	$k1, _k_save_r1
		.set	noat
		move	$1, $k1
		.set	at

#   Get the exception program counter (EPC), restore the previous CPU states,
#   and return to the the user code

		mfc0	$k0, $14
		rfe
		j	$k0


###############################################################################
# Procedure:	_k_HandleMOD, _k_HandleTLBL, _k_HandleTLBS, _k_HandleBp,
#		_k_HandleReserved
#
# Description:	These handlers are not currently supported, so we panic
#
# Parameters:	none
#
# Returns:	none (panics, never returns)
#
###############################################################################

		.kdata
_k_msg_badexp:	.asciiz	"Unexpected exception (possible simulator bug)\n"

		.ktext
_k_HandleMOD:
_k_HandleTLBL:
_k_HandleTLBS:
_k_HandleBp:
_k_HandleReserved:
		la	$a0, _k_msg_badexp
		j	_k_Panic


###############################################################################
# Procedure:	_k_HandleAdEL, _k_HandleAdES
#
# Description:	These handlers report address exception errors
#
# Parameters:	none
#
# Returns:	none (panics, never returns)
#
###############################################################################

		.kdata
_k_msg_AdE:	.asciiz "illegal address\n"

		.ktext
_k_HandleAdEL:
_k_HandleAdES:
		la	$a0, _k_msg_AdE
		j	_k_Error


###############################################################################
# Procedure:	_k_HandleDBE, _k_HandleIBE
#
# Description:	These handlers report bus errors
#
# Parameters:	none
#
# Returns:	none (panics, never returns)
#
###############################################################################

		.kdata
_k_msg_BE:	.asciiz "bus error\n"

		.ktext
_k_HandleDBE:
_k_HandleIBE:
		la	$a0, _k_msg_BE
		j	_k_Error


###############################################################################
# Procedure:	_k_HandleRI
#
# Description:	This handler reports reserved instruction exceptions
#
# Parameters:	none
#
# Returns:	none (panics, never returns)
#
###############################################################################

		.kdata
_k_HRI_msg:	.asciiz "Reserved instruction exception\n"

		.ktext
_k_HandleRI:
		la	$a0, _k_HRI_msg
		jal	_k_Warn
		j	_k_IncReturn


###############################################################################
# Procedure:	_k_HandleCpU
#
# Description:	This handler reports coprocessor unusable exceptions
#
# Parameters:	none
#
# Returns:	none (panics, never returns)
#
###############################################################################

		.kdata
_k_HCpU_msg:	.asciiz "Coprocessor Unusable exception\n"

		.ktext
_k_HandleCpU:
		la	$a0, _k_HCpU_msg
		jal	_k_Warn
		j	_k_IncReturn


###############################################################################
# Procedure:	_k_HandleOvf
#
# Description:	This handler reports integer overflow exceptions
#
# Parameters:	none
#
# Returns:	none (panics, never returns)
#
###############################################################################

		.kdata
_k_HOvf_msg:	.asciiz "Integer Overflow exception\n"

		.ktext
_k_HandleOvf:
		la	$a0, _k_HOvf_msg
		jal	_k_Warn
		j	_k_IncReturn


###############################################################################
# Procedure:	_k_HandleFPInexact
#
# Description:	This handler reports inexact FP result exceptions
#
# Parameters:	none
#
# Returns:	none (panics, never returns)
#
###############################################################################

		.kdata
_k_HFPI_msg:	.asciiz "Inexact floating point result exception\n"

		.ktext
_k_HandleFPInexact:
		la	$a0, _k_HFPI_msg
		jal	_k_Warn
		j	_k_IncReturn


###############################################################################
# Procedure:	_k_HandleDivideBy0
#
# Description:	This handler reports divide by zero exceptions
#
# Parameters:	none
#
# Returns:	none (panics, never returns)
#
###############################################################################

		.kdata
_k_HDB0_msg:	.asciiz "Divide by zero exception\n"

		.ktext
_k_HandleDivideBy0:
		la	$a0, _k_HDB0_msg
		jal	_k_Warn
		j	_k_IncReturn


###############################################################################
# Procedure:	_k_HandleFPOvf
#
# Description:	This handler reports FP overflow exceptions
#
# Parameters:	none
#
# Returns:	none (panics, never returns)
#
###############################################################################

		.kdata
_k_HFPOvf_msg:	.asciiz "Floating point overflow exception\n"

		.ktext
_k_HandleFPOvf:
		la	$a0, _k_HFPOvf_msg
		jal	_k_Warn
		j	_k_IncReturn


###############################################################################
# Procedure:	_k_HandleFPUnder
#
# Description:	This handler reports FP underflow exceptions
#
# Parameters:	none
#
# Returns:	none (panics, never returns)
#
###############################################################################

		.kdata
_k_HFPUnd_msg:	.asciiz "Floating point underflow exception\n"

		.ktext
_k_HandleFPUnder:
		la	$a0, _k_HFPUnd_msg
		jal	_k_Warn
		j	_k_IncReturn


###############################################################################
# Procedure:	_k_HandleInt
#
# Description:	All interrupts are processed through this routine.  Instead of
#		decoding the cause register, it calls handlers for all of the
#		individual interrupts.  Thus, each handler must be callable
#		even if its device is not actually ready.
#
# Parameters:	none
#
# Returns:	none (exits kernel by jumping to _k_Return)
#
###############################################################################

		.ktext
_k_HandleInt:

#
# Call the display handler to see if the display needs servicing
#
		jal	_k_DP_handler

#
# Call the keyboard handler to see if the keyboard needs servicing
#
		jal	_k_KB_handler

#
# This code clears the clock interrupt.  Remove this code and insert a call
# to your clock interrupt handler
#

#################################
# MY KERNEL CODE STARTS HERE 

		jal     _k_Cl_handler

# MY KERNEL CODE ENDS HERE
################################# 

#
# Return to user code
#
		j	_k_Return


#################################
# MY KERNEL CODE STARTS HERE 

                .kdata
_k_Cl_time:     
                .word 0

                .ktext

_k_Cl_handler:

                lw      $t0, ClockStatus
                bgez    $t0, _k_Cl_ret
                lw      $t1, _k_Cl_time
                add     $t1, $t1, 1
                sw      $t1, _k_Cl_time

_k_Cl_ret:
                jr      $ra

# MY KERNEL CODE ENDS HERE
################################# 


###############################################################################
# Procedure:	_k_HandleSys
#
# Description:	All system calls are handled through this routine.  It
#		branches to routines for the individual system calls.
#
# Parameters:	none
#
# Returns:	none (exits kernel by jumping to _k_Return)
#
###############################################################################

		.kdata
_k_msg_Sys:	.asciiz "Illegal syscall number\n"

		.ktext
_k_HandleSys:
#
# Get the exception program counter, increment it to skip the syscall
# instruction, and store it back
#
		mfc0	$k1, $14
		add	$k1, $k1, 4
		mtc0	$k1, $14

#
# Get the syscall number and branch to the appropriate subhandler
#
		lw	$v0, _k_save_v0	# Get the syscall number

#   Is it putc?
		beq	$v0, 11, _k_Putc

#   Is it puts?
		beq	$v0, 4, _k_Puts

#   Is it getc?
		beq	$v0, 12, _k_Getc

#   Is it done?
		beq	$v0, 10, _k_Done

#################################
# MY KERNEL CODE STARTS HERE 

#   Is it clock?
                beq     $v0, 15, _k_Clock

# MY KERNEL CODE ENDS HERE
################################# 

#
# We have a a bad syscall on our hands; print an error message and return
#
	la	$a0, _k_msg_Sys
	jal	_k_Warn
	j	_k_Return

#
# Done syscall subhandler -- First, empty the output buffer.  Then, halt the
# system.
#
		.kdata
_k_Done_msg:	.asciiz	"\nExecution Complete.  Have a nice day! :-)\n"

		.ktext
_k_Done:
		jal	_k_DP_handler
		bnez	$v0, _k_Done

		la	$a0, _k_Done_msg
		jal	_k_PrintString

		j	_k_Halt

#
# Putc syscall subhandler -- enqueue the character and return
#
_k_Putc:
		lw	$a0, _k_save_a0
		jal	_k_DPenQ
		j	_k_Return

#
# Puts syscall subhandler -- enqueue the characters associated with the string
# and then return
#
		.kdata
_k_Puts_addr:	.word

		.ktext
_k_Puts:
#   Get the address of string
		lw	$t0, _k_save_a0

#   Get the next character to enqueue; if it's a null, then return
_k_Puts_l1:
		lbu	$a0, ($t0)
		beqz	$a0, _k_Return

#   Enqueue the character
		sw	$t0, _k_Puts_addr
		jal	_k_DPenQ
		lw	$t0, _k_Puts_addr

#   Advance the pointer to the next character and loop
		add	$t0, $t0, 1
		j	_k_Puts_l1

#
# Getc syscall subhandler -- dequeue a character and return it
#
_k_Getc:
		jal	_k_KBdeQ
		sw	$v0, _k_save_v0
		j	_k_Return

#
# Clock syscall subhandler -- returns the number of clock interrupts
#

#################################
# MY KERNEL CODE STARTS HERE 

_k_Clock:
                lw      $t0, _k_Cl_time
                sw      $t0, _k_save_v0
                j       _k_Return

# MY KERNEL CODE ENDS HERE
################################# 


###############################################################################
#                        Display queue data structures                        #
###############################################################################
		.kdata
_k_DP_q:	.space	256
		.align	2
_k_DP_hqp:	.word	0		# head pointer to put queue
_k_DP_tqp:	.word	0		# tail pointer to put queue


###############################################################################
# Procedure:	_k_DPenQ
#
# Description:	enqueue a character on the queue of characters to be displayed
#
# Parameters:	$a0	the character to enqueue
#
# Returns:	none
#
###############################################################################

		.kdata
_k_DPenQ_a0:	.word	0		#space to save $a0
_k_DPenQ_ra:	.word	0		#space to save $ra

		.ktext
_k_DPenQ:
#
# Get the head and tail pointers for the queue
#
		lw	$t0, _k_DP_hqp
		lw	$t1, _k_DP_tqp

#
# Attempt to allocate space in the queue
#
		add	$t1, $t1, 1
		and	$t1, $t1, 0xff
		bne	$t1, $t0, _k_DPenQ_space

#   If the queue is full, keep trying to print until we make room, then
#   try to allocate space again
		sw	$a0, _k_DPenQ_a0
		sw	$ra, _k_DPenQ_ra
		jal	_k_DP_handler
		lw	$a0, _k_DPenQ_a0
		lw	$ra, _k_DPenQ_ra
		j	_k_DPenQ
_k_DPenQ_space:

#
# Add the character to the queue, saving the new tail pointer
#
		sb	$a0, _k_DP_q($t1)
		sw	$t1, _k_DP_tqp

#
# Turn on the display and interrupt
#
		mfc0	$t1, $12
		or	$t1, 0x00004000
		mtc0	$t1, $12

#
# As long as we're in the kernel, attempt to display the next character on
# the queue before we return
#
		sw	$ra, _k_DPenQ_ra
		jal	_k_DP_handler
		lw	$ra, _k_DPenQ_ra

		jr	$ra


###############################################################################
# Procedure:	_k_DP_handler
#
# Description:	This is the display interrupt handler.  It writes a single
#		character to the display if 1) the display is ready and
#		2) there is data to write.
#
# Parameters:	none
#
# Returns:	queue status (0=empty, otherwise there are characters enqueued)
###############################################################################

_k_DP_handler:

#
# See if the display is ready; if not, return
#
		lw	$t0, DisplayStatus
		bgez	$t0, _k_DP_ret

#
# Get the head and tail pointers for the put queue, return if the queue
# is empty
#
		lw	$t0, _k_DP_hqp
		lw	$t1, _k_DP_tqp
		beq	$t0, $t1, _k_DP_ret

#
# Update the head pointer while removing the next character from queue;
# print the character
#
		add	$t0, $t0, 1
		and	$t0, $t0, 0xff
		sw	$t0, _k_DP_hqp
		lb	$t2, _k_DP_q($t0)
		sw	$t2, DisplayData

#
# Return the status of the queue (0 = empty, non-zero = contains data)
#
_k_DP_ret:
		lw	$t0, _k_DP_hqp
		lw	$t1, _k_DP_tqp
		sub	$v0, $t0, $t1
		jr	$ra


###############################################################################
#                        Display queue data structures                        #
###############################################################################

		.kdata
_k_KB_q:	.space	256
_k_KB_hqp:	.word 0		# head pointer for keyboard queue
_k_KB_tqp:	.word 0		# tail pointer for keyboard queue


###############################################################################
# Procedure:	_k_KBdeQ
#
# Description:	dequeue a character from the queue of characters entered on the
#		keyboard
#
# Parameters:	none
#
# Returns:	$v0	the next character typed
###############################################################################

		.kdata
_k_KBdeQ_ra:	.word

		.ktext

_k_KBdeQ:

#
# Turn the keyboard interrupt back on
#
_k_KBdeQ_l1:
		mfc0	$5, $12
		or	$5, 0x000000800
		mtc0	$5, $12

#
# Get the head and tail pointer for the queue
#
		lw	$t0, _k_KB_tqp
		lw	$t1, _k_KB_hqp

#
# If no characters are enqueued, wait for one to arrive; in the mean time,
# make sure the display is updated
#
		bne	$t0, $t1, _k_KBdeQ_l2
		sw	$ra, _k_KBdeQ_ra
		jal	_k_DP_handler
		jal	_k_KB_handler

#################################
# MY KERNEL CODE STARTS HERE 

                jal     _k_Cl_handler

# MY KERNEL CODE ENDS HERE
#################################

		lw	$ra, _k_KBdeQ_ra
		j	_k_KBdeQ_l1
_k_KBdeQ_l2:

#
# Get the next character from the queue, advance the head pointer, and return
# the character
#
		add	$t1, $t1, 1
		and	$t1, $t1, 0xff
		lb	$v0, _k_KB_q($t1)
		sw	$t1, _k_KB_hqp
		jr	$ra


###############################################################################
# Procedure:	_k_KB_handler
#
# Description:	This is the keyboard interrupt handler.  If a key has been
#		pressed and there is room, it places the typed character in
#		the buffer.  If the buffer is full, this routine disables
#		keyboard interrupts and the character is lost.
#
# Parameters:	none
#
# Returns:	none
###############################################################################
		.kdata
_k_KB_ra:	.word

		.ktext
_k_KB_handler:

#
# Get the status of the keyboard; if no characters are found, then return
#
		lw	$t2, KeyboardStatus
		bgez	$t2, _k_KB_ret

#
# Get the head and tail pointers for the queue; allocate space for the new
# character; if no space is available, then shutoff interrupt and return
#

	lw	$t0, _k_KB_tqp
	lw	$t1, _k_KB_hqp

#   allocate space
	add	$t0, $t0, 1
	and	$t0, $t0, 0xff

#   if no space, turn off the keyboard interrupt
	bne	$t0, $t1, _k_KB_l1
	mfc0	$t0, $12
	and	$t0, $5, 0xfffff7ff
	mtc0	$t0, $12
	jr	$ra
_k_KB_l1:


#
# Put the character in the queue and update the tail pointer
#
	sw	$t0, _k_KB_tqp
	lw	$t1, KeyboardData
	sb	$t1, _k_KB_q($t0)

#
# Display the character that was input
#
	sw	$ra, _k_KB_ra	
	move	$a0, $t1
	jal	_k_DPenQ
	lw	$ra, _k_KB_ra	

_k_KB_ret:
	jr	$ra


###############################################################################
# Procedure:	_k_Halt
#
# Description:	Clear re-entry flag and halt the system (using a special
#		syscall recognized internally by the simulator)
#
# Parameters:	none
#
# Returns:	none (never returns)
###############################################################################

		.ktext
_k_Halt:
		li	$v0, 13
		syscall


###############################################################################
# Procedure:	_k_Warn
#
# Description:	print a warning and return
#
# Parameters:	$a0	pointer to the string to output
#
# Returns:	none
###############################################################################

		.kdata
_k_warn_p:	.word			# space to save parameter
_k_warn_ra:	.word			# space to save $ra

_k_warn_msg:	.asciiz	"\n\nWarning:  "

		.ktext
_k_Warn:
		sw	$ra, _k_warn_ra
		sw	$a0, _k_warn_p

		la	$a0, _k_warn_msg
		jal	_k_PrintString

		lw	$a0, _k_warn_p
		jal	_k_PrintString

		jal	_k_DumpState

		la	$a0, _k_msg_nl
		jal	_k_PrintString

		lw	$ra, _k_warn_ra
		jr	$ra


###############################################################################
# Procedure:	_k_Error
#
# Description:	print an error and halt the system
#
# Parameters:	$a0	pointer to the string to output
#
# Returns:	none (never returns)
###############################################################################

		.kdata
_k_error_p:	.word			# space to save parameter

_k_error_msg:	.asciiz	"\n\nError:  "
_k_error_term:	.asciiz "\nExecution Terminated.\n"

		.ktext
_k_Error:
		sw	$a0, _k_error_p

		la	$a0, _k_error_msg
		jal	_k_PrintString

		lw	$a0, _k_error_p
		jal	_k_PrintString

		jal	_k_DumpState

		la	$a0, _k_error_term
		jal	_k_PrintString

		j	_k_Halt


###############################################################################
# Procedure:	_k_Panic
#
# Description:	something really bad has happened, print a panic message and
#		halt the system
#
# Parameters:	$a0	pointer to the string to output
#
# Returns:	none (never returns)
###############################################################################

		.kdata
_k_panic_p:	.word			# space to save parameter

_k_panic_msg:	.asciiz	"\n\nPanic:  "
_k_panic_term:	.asciiz "\nExecution Terminated.\n"

		.ktext
_k_Panic:
		sw	$a0, _k_panic_p

		la	$a0, _k_panic_msg
		jal	_k_PrintString

		lw	$a0, _k_panic_p
		jal	_k_PrintString

		jal	_k_DumpState

		la	$a0, _k_panic_term
		jal	_k_PrintString

		j	_k_Halt


###############################################################################
# Procedure:	_k_DumpState
#
# Description:	print the system state
#
# Parameters:	none
#
# Returns:	none
###############################################################################

		.kdata
_k_DS_ra:	.word

_k_DS_addr:	.asciiz	"\n    Address:   "
_k_DS_cond:	.asciiz "\n    Condition: "
_k_DS_stat:	.asciiz "\n    Status:    "

		.ktext
_k_DumpState:
		sw	$ra, _k_DS_ra

		la	$a0, _k_DS_addr
		jal	_k_PrintString
		mfc0	$a0, $14
		jal	_k_PrintHex

		la	$a0, _k_DS_cond
		jal	_k_PrintString
		mfc0	$a0, $13
		jal	_k_PrintHex

		la	$a0, _k_DS_stat
		jal	_k_PrintString
		mfc0	$a0, $12
		jal	_k_PrintHex

		la	$a0, _k_msg_nl
		jal	_k_PrintString

		lw	$ra, _k_DS_ra
		jr	$ra


###############################################################################
# Procedure:	_k_PrintString
#
# Description:	This is a blocking busy wait print routine.  It is used only
#		to print errors.
#
# Parameters:	$a0	pointer to the string to output
#
# Returns:	none
#
# Regs Used:	$t0	character to print
#		$t1	display status
###############################################################################

		.ktext
_k_PrintString:

		lb	$t0, ($a0)
		beqz	$t0, _k_PSCont
_k_PSLoop:
		lw	$t1, DisplayStatus
		bgez	$t1, _k_PSLoop
		sw	$t0, DisplayData
		add	$a0, $a0, 1
		j	_k_PrintString

_k_PSCont:
		jr	$ra


###############################################################################
# Procedure:	_k_PrintHex
#
# Description:	display a word as a hexadecimal number; used for error
#		reporting only
#
# Input:	$a0	the word
#
# Output:	none
#
# Reg used:	$t0	shift count
#		$t1	nibble mask
#		$t2	the hex digit to display
#		$t3	comparison tmp / display status
###############################################################################
		.ktext

		.eq	_k_PrintHex_mask	0xf0000000

_k_PrintHex:
		li	$t0, 32
		li	$t1, _k_PrintHex_mask

_k_PrintHexl1:
		and	$t2, $a0, $t1
		sub	$t0, $t0, 4
		srl	$t2, $t2, $t0
		add	$t2, $t2, 48
		li	$t3, '9'
		ble	$t2, $t3, _k_PrintHexl2
		add	$t2, $t2, 7	
_k_PrintHexl2:	
		lw	$t3, DisplayStatus
		bgez	$t3, _k_PrintHexl2
		sw	$t2, DisplayData
		srl	$t1, $t1, 4
		bgtz	$t0, _k_PrintHexl1
		jr	$ra


		.text
		.globl __start

### End of the kernel.
######################################################################
# Add user-level code here.



.data
   type_test_prompt1:   .asciiz "Typing test. Enter the string:\n"
   type_test_prompt2:   .asciiz "The quick brown fox jumped over the lazy dog.\n"
   sent_arr:          .byte   'T', 'h', 'e', ' ', 'q', 'u', 'i', 'c', 'k', ' ', 'b', 'r', 'o', 'w', 'n', ' ', 'f', 'o', 'x', ' ', 'j', 'u', 'm', 'p', 'e', 'd', ' ', 'o', 'v', 'e', 'r', ' ', 't', 'h', 'e', ' ', 'l', 'a', 'z', 'y', ' ', 'd', 'o', 'g', '.'
   post_test_msg1:  .asciiz "Number of incorrect characters:  "
   post_test_msg2:  .asciiz "\nTake the test again? Enter 'y' to try again.  "
   print_newline:   .asciiz "\n"
   clock_msg:       .asciiz "\nNumber of seconds to take test:  "

# Register values:
# $8   input char
# $9   integer value 10 (base and ascii value of '\n' char)
# $10  counter (used for offset)
# $11  offset and offset + address (of array)
# $12  char loaded from array
# $13  error counter
# $14  array base address
# $15  clock information 1
# $16  clock information 2
# $25  output messages

.text
__start:
   sub  $sp, $sp, 8

begin:
   la   $25, type_test_prompt1
   li   $2, 4
   move $4, $25
   syscall
   la   $25, type_test_prompt2
   li   $2, 4
   move $4, $25
   syscall

   li   $9, 10
   li   $10, 0
   li   $13, 0
   li   $15, 45
   la   $14, sent_arr

   li   $2, 15
   syscall
   move $15, $2

get_chars:
   li   $2, 12
   syscall
   move $8, $2
   
   beq  $8, $9, stop_reading

   mul  $11, $10, 1
   add  $11, $14, $11
   lbu  $12, ($11)

   beq  $12, $8, correct_char
   add  $13, $13, 1

correct_char:
   add  $10, $10, 1
   b    get_chars

stop_reading:
   bge   $10, $15, enough_chars
   sub   $10, $15, $10
   add   $13, $13, $10

enough_chars:
   li    $2, 15
   syscall
   move  $16, $2

   sub   $15, $16, $15

   la    $25, post_test_msg1
   li    $2, 4
   move  $4, $25
   syscall

   sw    $13, 4($sp)
   sw    $9,  8($sp)
   jal   print_integer

   la    $25, clock_msg
   li    $2, 4
   move  $4, $25
   syscall

   sw    $15, 4($sp)
   sw    $9, 8($sp)
   jal print_integer

   la    $25, post_test_msg2
   li    $2, 4
   move  $4, $25
   syscall

   li   $2, 12
   syscall
   move $8, $2

   li    $10, 121
   beq   $8, $10, test_again
   
   add   $sp, $sp, 8
   done

test_again:
   la    $25, print_newline
   li    $2, 4
   move  $4, $25
   syscall
   b     begin


print_integer:

# Register values:
# $8   1st param: integer value to be printed
# $9   2nd param: base of value to be printed
# $10  char value '-', int value 10 and copy of 1st param
# $11  copy of 1st param
# $12  base counter
# $13  copy of 1st param to be divided
# $14  copy of 2nd param (not to be decremented)

   sub  $sp, $sp, 32         # allocate AR
   sw   $ra, 32($sp)         # save registers in AR
   sw   $8,  4($sp)
   sw   $9,  8($sp)
   sw   $10, 12($sp)
   sw   $11, 16($sp)
   sw   $12, 20($sp)
   sw   $13, 24($sp)
   sw   $14, 28($sp)

   lw   $8,  36($sp)         #load parameters
   lw   $9,  40($sp)

   add  $14, $9,  0
   and  $10, $10, 0
   bgez $8, single_digit_check

   sub  $8, $10, $8          # make integer positive if not
   li   $10, '-'             # print '-'
   li   $2, 11
   move $4, $10
   syscall

single_digit_check:          # if value < 10
   li  $10, 10
   blt $8,  $10, less_than_ten
   li  $10, 0

find_base:
   add $10, $8,  0           # make 2 copies of int value
   add $11, $8,  0
   and $12, $12, 0           # set counter

find_base2:

   #divide number by base and increment counter
   div  $11, $11, $9
   add  $12, $12, 1
   bgtz $11, find_base2

   sub  $12, $12, 2

find_base3:
   
   #advance degree of base, decrement counter
   beqz $12, print_digits
   mul  $9,  $9,  $14
   sub  $12, $12, 1

   b find_base3

print_digits:
   #translates integer value to individual ascii characters for printing
   #by dividing value by base, printing character, then modding the value
   #by the base and decrementing the base

   beqz $9, print_epilogue
   div  $13, $10, $9
   add  $13, $13, 48
   li   $2, 11
   move $4, $13
   syscall
   rem  $10, $10, $9
   div  $9,  $9,  $14
   b print_digits

less_than_ten:
   # if single-digit value with base 10 print value
   blt  $14, $10, find_base
   add  $8,  $8,  48
   li   $2, 11
   move $4, $8
   syscall

print_epilogue:
   li   $v0, 0
   lw   $8,  4($sp)          # restore register values
   lw   $9,  8($sp)
   lw   $10, 12($sp)
   lw   $11, 16($sp)
   lw   $12, 20($sp)
   lw   $13, 24($sp)
   lw   $14, 28($sp)
   lw   $ra, 32($sp)
   add  $sp, $sp, 32         # deallocate AR space
   jr   $ra                  # return


