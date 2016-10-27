

/* r8 always for JP1
 r4 is the reture value of reading sensor to determine the cases
 r6 is x-cords for VGA
 r7 is y-cords for VGA
 r13,r23 never used
 */


.section .data
.equ JP1, 0xFF200060
.equ SENSOR0_ON, 0xFFFFFBFF
.equ SENSOR0_MASK, 0x0800
.equ SENSOR1_ON, 0xFFFFEFFF
.equ SENSOR1_MASK, 0x2000
.equ ADDR_JP1_IRQ, 0x0800


#VGA
.equ ADDR_VGA, 0x08000000
.equ ADDR_CHAR, 0x09000000
.equ x_start_for_header,163




#audio codec
.equ AUDIO, 0xFF203040
.equ VOLUME, 0x120000


#pitches
.equ C, 92
.equ D, 82
.equ E, 73
.equ F, 69
.equ G, 61
.equ A, 54
.equ B, 48


#print air-guitar
header:
.byte 0x41
.byte 0x49
.byte 0x52
.byte 0x20
.byte 0x47
.byte 0x55
.byte 0x49
.byte 0x54
.byte 0x41
.byte 0x52


.section .text
.global main
# the following are functions that will be called by the interrupt handler
# these include reading values off all sensors and determine which sound to play
main:
movia r2,ADDR_VGA
movia r3, ADDR_CHAR
movia r4,header
movia r6,0x0900000A #r6+132=place that header ends


loop:
ldb   r5,(r4)
stbio r5,x_start_for_header(r3) #header start at the middle of first line


addi   r3,r3,1
addi   r4,r4,1
bne	r3,r6,loop

movia r3,ADDR_CHAR
movi  r6,2        #global variable for y
movi  r7,0        #global for x

movia r8,JP1
movia  r11, 0xffffffff        	/* set all motors off and disable all sensors */
stwio  r11, 0(r8)
movia  r11, 0x07F557FF
stwio  r11, 4(r8)


call set_to_state_mode



end:
br end




set_to_state_mode:
#set up sensor 5 for interrupt in state mode
movia r11, 0xffbbffff        	/* load threshold value 0xF for sensor 5 on lego controller*/
stwio r11, 0(r8)
/* turn on state mode */
movia  r11, 0xffdfffff
stwio  r11, 0(r8)
#turn on interrupts
movia	r11,0x80000000
stwio	r11,8(r8)               	/* Enable sensor 5 to interrupt */
movia  r11,ADDR_JP1_IRQ        	/* enable bit 11 interrupts(GPIO JP1) on NIOS
                                 processor*/
wrctl	ctl3,r11
movia 	r11,1
wrctl 	ctl0,r11                	/* enable global interrupts*/
ret


Read_Sensors:
#init

#pre-call for function: Read_sensors
subi sp, sp, 4
stw ra, 0(sp) #ra says go to exit_handler
movia r8, JP1
movia r9, 0xFFFFFFFF
stwio r9, 0(r8) #keep all motors and sensors off
movia r9, 0x07F557FF
stwio r9, 4(r8) #Initialize direction register


Read_Sensor_0:
movia r4, SENSOR0_ON
movia r5, SENSOR0_MASK
call Read_a_sensor # return to 2A4




#check value in r14
movi r11, 0xC #r11 is a register holding temporary values #addr 2A4
bge r14, r11, Read_Sensor_1 # distance value B translates to no string being held down
mov r15, r14 # save the distance value - which string is held down
movi r16, 0 # record fret 0 has been pressed down




fret0_string0:
movi r11, 0x8
bgt r15, r11, fret0_string1 # if not this string, try other strings
movi r4, 0 # C note
br audio_part
fret0_string1:
movi r11, 0xB
bgt r15, r11, fret0_string2
movi r4, 4 # G note
br audio_part
fret0_string2:
movi r4, 2 # E note
br audio_part


Read_Sensor_1:
movia r4, SENSOR1_ON
movia r5, SENSOR1_MASK
call Read_a_sensor


#check value in r14
movi r11, 0xA #r11 is a register holding temporary values
bgt r14, r11, Read_Sensor_1 # distance value A translates to no string is held down
mov r15, r14 # save the distance value
movi r16, 1 # record fret 1 has been pressed down

fret1_string0:
movi r11, 0xA
bge r15, r11, fret1_string1 # if not this string, try other strings
movi r4, 1 # D note
br audio_part
fret1_string1:
movi r11, 0xB
bgt r15, r11, fret1_string2
movi r4, 5 # A note
br audio_part
fret1_string2:
movi r11, 0xC
bge r15, r11, fret1_reactions
movi r4, 3 # F note
br audio_part
fret1_reactions:
movi r4, 6
br audio_part


#post-call clean up for function: read_sensors
ldw ra, 0(sp)
addi sp, sp, 4
ret


Read_a_sensor: #subroutine
#r4 stores which setup turns the specified sensor on and
#r5 stores the mask which helps the checking of valid bit for sensors
#pre-call for function: Read_a_sensor
subi sp, sp, 4
stw ra, 0(sp)
Sensor_init:
#enable a sensor while disabling other sensors
#enter value mode
mov r11, r4
stwio r11, 0(r8)
Poll_Sensor:
ldwio r14, 0(r8)
and r14, r14, r5 # Check the ready bit to see if data is valid or not
bne r14, r0, Poll_Sensor # if not keep polling
ldwio r14, 0(r8)
srli r14, r14, 27 # mask out
andi r4, r14, 0xF # r14 stores the value of sensor
Clean_up:
call set_to_state_mode

#post-call clean up for function: read_a_sensor
ldw ra, 0(sp)
addi sp, sp, 4
ret




audio_part:
movia r8, AUDIO
movia r9, VOLUME
movi r17,1    	/*total seven cases*/
movi r18,2
movi r19,3
movi r20,4
movi r21,5
movi r22,6
beq  r4,r0,Play_C
beq  r4,r17,Play_D
beq  r4,r18,Play_E
beq  r4,r19,Play_F
beq  r4,r20,Play_G
beq  r4,r21,Play_A
beq  r4,r22,Play_B


Play_C:
movi r10, C
mov r5, r10

movi  r11,0x4b
bne   r11,r7,same_line1
addi  r6,r6,1
same_line1:
slli  r11,r6,7
add   r11,r11,r7
add   r11,r11,r3
movi  r12,0x43   #C
stbio r12,0(r11)
addi  r7,r7,5

br Wait_For_Write


Play_D:
movi r10, D
mov r5, r10

movi  r11,0x4b
bne   r11,r7,same_line2
addi  r6,r6,1
same_line2:
slli  r11,r6,7
add   r11,r11,r7
add   r11,r11,r3
movi  r12,0x44   #D
stbio r12,0(r11)
addi  r7,r7,5

br Wait_For_Write


Play_E:
movi r10, E
mov r5, r10

movi  r11,0x4b
bne   r11,r7,same_line3
addi  r6,r6,1
same_line3:
slli  r11,r6,7
add   r11,r11,r7
add   r11,r11,r3
movi  r12,0x45   #E
stbio r12,0(r11)
addi  r7,r7,5

br Wait_For_Write


Play_F:
movi r10, F
mov r5, r10

movi  r11,0x4b
bne   r11,r7,same_line4
addi  r6,r6,1
same_line4:
slli  r11,r6,7
add   r11,r11,r7
add   r11,r11,r3
movi  r12,0x46   #F
stbio r12,0(r11)
addi  r7,r7,5

br Wait_For_Write


Play_G:
movi r10, G
mov r5, r10

movi  r11,0x4b
bne   r11,r7,same_line5
addi  r6,r6,1
same_line5:
slli  r11,r6,7
add   r11,r11,r7
add   r11,r11,r3
movi  r12,0x47   #G
stbio r12,0(r11)
addi  r7,r7,5

br Wait_For_Write


Play_A:
movi r10, A
mov r5, r10

movi  r11,0x4b
bne   r11,r7,same_line6
addi  r6,r6,1
same_line6:
slli  r11,r6,7
add   r11,r11,r7
add   r11,r11,r3
movi  r12,0x41   #A
stbio r12,0(r11)
addi  r7,r7,5

br Wait_For_Write


Play_B:
movi r10, B
mov r5, r10

movi  r11,0x4b
bne   r11,r7,same_line7
addi  r6,r6,1
same_line7:
slli  r11,r6,7
add   r11,r11,r7
add   r11,r11,r3
movi  r12,0x42   #B
stbio r12,0(r11)
addi  r7,r7,5

br Wait_For_Write


Wait_For_Write:
ldwio r2, 4(r8)
andhi r3, r2, 0xFF00
beq r3, r0, Wait_For_Write
andhi r3, r2, 0xFF
beq r3, r0, Wait_For_Write


Write_Volume:
stwio r9, 8(r8)
stwio r9, 12(r8)
addi r5, r5, -1
bne r5, r0, Wait_For_Write


Inverted_Volume:
mov r5, r10
sub r9, r0, r9
br Wait_For_Write


.section .exceptions, "ax"
.global handler


handler:
#some preparation stuff
#call set_to_state_mode


#check if sensor 5, the strumming sensor, shows hand is close
rdctl et,ctl4
beq   et,r0,exit_handler

movia r11,ADDR_JP1_IRQ
and   r11,et, r11
beq   r11,r0,exit_handler

#movia r11,12(r8)
#stwio r0,0(r11)

movia r8,JP1
ldwio r11,0(r8)
srli  r11,r11,27
andi  r11,r11,0x1f

cmpeqi r12,r11,0x1f
bne   r12,r0,exit_handler #does not interrupt

cmpeqi r12,r11,0x0f
bne   r12,r0,strum

strum:
call Read_Sensors



exit_handler: #address 68
subi ea, ea, 4
eret




