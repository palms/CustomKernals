

.data
   type_test_prompt1:   .asciiz "Typing test. Enter the string:\n"
   type_test_prompt2:   .asciiz "The quick brown fox jumped over the lazy dog.\n"
   sent_arr:          .byte   'T', 'h', 'e', ' ', 'q', 'u', 'i', 'c', 'k', ' ', 'b', 'r', 'o', 'w', 'n', ' ', 'f', 'o', 'x', ' ', 'j', 'u', 'm', 'p', 'e', 'd', ' ', 'o', 'v', 'e', 'r', ' ', 't', 'h', 'e', ' ', 'l', 'a', 'z', 'y', ' ', 'd', 'o', 'g', '.'
   post_test_msg1:  .asciiz "Number of incorrect characters:  "
   post_test_msg2:  .asciiz "\nTake the test again? Enter 'y' to try again.  "
   print_newline:   .asciiz "\n"

# Register values:
# $8   input char
# $9   integer value 10 (base and ascii value of '\n' char)
# $10  counter (used for offset) and ascii value of 'y' char
# $11  offset and offset + address (of array)
# $12  char loaded from array
# $13  error counter
# $14  temporary holder of error counter under certain circumstance
# $25  output messages

.text
__start:
   sub  $sp, $sp, 8

begin:
   la   $25, type_test_prompt1
   puts $25
   la   $25, type_test_prompt2
   puts $25

   li   $9, 10
   li   $10, 0
   li   $13, 0
   li   $15, 45
   la   $14, sent_arr

get_chars:
   getc $8
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
   la    $25, post_test_msg1
   puts  $25

   sw    $13, 4($sp)
   sw    $9, 8($sp)
   jal   print_integer

   la    $25, post_test_msg2
   puts  $25
   getc  $8

   li    $10, 121
   bne   $8, $10, end_test

   la    $25, print_newline
   puts  $25
   b     begin

end_test:
   add $sp, $sp, 8
   done


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
   putc $10

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
   putc $13
   rem  $10, $10, $9
   div  $9,  $9,  $14
   b print_digits

less_than_ten:
   # if single-digit value with base 10 print value
   blt  $14, $10, find_base
   add  $8,  $8,  48
   putc $8

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


