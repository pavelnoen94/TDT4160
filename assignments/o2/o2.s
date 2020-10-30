.thumb
.syntax unified

.include "gpio_constants.s"     // Register-adresser og konstanter for GPIO
.include "sys-tick_constants.s" // Register-adresser og konstanter for SysTick
.include "time_consts.s"
.include "interrupt_handlers.s"
.text

// system tick interrupt handler
.global SysTick_Handler
.thumb_func
SysTick_Handler:
    PUSH {LR}
    BL update_timer
    POP {PC}

// GPIO odd button interrupt handler
.global GPIO_ODD_IRQHandler
.thumb_func
GPIO_ODD_IRQHandler:
    PUSH {R0, R1, LR}
    // TODO: check if the correct button was pressed
    // EDIT: fuck that, who cares? Only one odd button anyway.

    // toggle timer start / stop
    LDR R0, =SYSTICK_BASE
    LDR R1, [R0]

    AND R1, #1

    CMP R1, #0b1
    BEQ GPIO_ODD_IRQHandler_stop
    // start timer
    LDR R1, [R0]
    ORR R1, R1, #0b1
    STR R1, [R0]
    // return
    B GPIO_ODD_IRQHandler_return

.thumb_func
GPIO_ODD_IRQHandler_stop:

    LDR R0, =SYSTICK_BASE
    LDR R1, [R0]
    LSR R1, #1 // clear the lsb
    LSL R1, #1
    STR R1, [R0]

.thumb_func
GPIO_ODD_IRQHandler_return:
    BL clear_interrupt_flag
    POP {R0, R1, PC}



// Display init function
.global init_display
.thumb_func
init_display:
    PUSH {R0, R1, LR}

    // display 00-00-0 on reset
    MOV R0, #0
    LDR R1, =tenths
    STR R0, [R1]

    POP {R0, R1, PC}



// Timer init function
.thumb_func
init_timer:
    PUSH {R0, R1, LR}

    LDR R0, =SYSTICK_BASE
    LDR R1, [R0]
    ORR R1, #0b110 // use_internal_clock = true, generate_interrupts = true, enable = false
    STR R1, [R0]

    // Set sys tick load
    LDR R0, =SYSTICK_BASE
    LDR R1, =SYSTICK_LOAD
    ADD R0, R0, R1
    LDR R1, =CLOCK_PER_INTERRUPT

    STR R1, [R0]

    // Set sys tick current value
    LDR R0, =SYSTICK_BASE
    LDR R1, =SYSTICK_VAL
    LDR R1, [R0, R1]

    LDR R0, =CLOCK_PER_INTERRUPT
    STR R0, [R1]

    POP {R0, R1, PC}


// Button init function
.global init_button
.thumb_func
init_button:
    PUSH {R0, R1, R2, LR}

    // P. 41 EXTIPSELH.
    LDR R0, =GPIO_BASE
    LDR R1, =GPIO_EXTIPSELH
    ADD R0, R0, R1

    MOV R1, #0b1111
    LSL R1, R1, #4
    MVN R2, R1 // disable pin 4-7 mask
    LDR R1, [R0] // R1: EXTIPSELH content
    AND R1, R2, R1
    MOV R2, #PORT_B
    LSL R2, R2, #4 // enable pin 4 mask
    ORR R1, R1, R2
    STR R1, [R0] // R1: EXTIPSELH new content

    // 9th bit on EXTIFALL page 42. falling edge
    LDR R0, =GPIO_BASE
    LDR R1, =GPIO_EXTIFALL
    ADD R0, R0, R1
    LDR R2, [R0]

    MOV R1, #1
    LSL R1, R1, #9
    ORR R1, R1, R2
    STR R1, [R0]

    BL clear_interrupt_flag

    // Interrupt enable page 43
    LDR R0, =GPIO_BASE
    LDR R1, =GPIO_IEN
    ADD R0, R0, R1
    LDR R1, [R0]

    MOV R2, #1
    LSL R2, R2, #9
    ORR R1, R1, R2
    STR R1, [R0]

    POP {R0, R1, R2, PC}

// Clear interrupt flag function
.global clear_interrupt_flag
.thumb_func
clear_interrupt_flag:
    PUSH {R0, R1, R2, LR}

    // Clear Interrupt flag
    LDR R0, =GPIO_BASE
    LDR R1, =GPIO_IFC
    ADD R0, R0, R1

    LDR R2, [R0]

    MOV R1, #1
    LSL R1, #BUTTON_PIN
    ORR R1, R1, R2

    STR R1, [R0]
    POP {R0, R1, R2, PC}

// Tick function
.global update_timer
.thumb_func
update_timer:
.thumb_func
update_timer_increment_tenth:
    PUSH {R0, R1, LR}
    // chech tenth
    LDR R0, =tenths
    LDR R1, [R0]
    CMP R1, #MAX_TENTHS
    BEQ update_timer_increment_second
    // increment tenth
    ADD R1, R1, #1
    STR R1, [R0]
    B update_timer_return

.thumb_func
update_timer_increment_second:
    // set tenth to 0
    LDR R0, =tenths
    MOV R1, #0
    STR R1, [R0]

    // check seconds
    LDR R0, =seconds
    LDR R1, [R0]
    CMP R1, #MAX_SECONDS
    BEQ update_timer_increment_minute

    // increment second
    ADD R1, R1, #1
    STR R1, [R0]
    B update_timer_return

.thumb_func
update_timer_increment_minute:
    // set seconds to 0
    LDR R0, =seconds
    MOV R1, #0
    STR R1, [R0]

    // check minute
    LDR R0, =minutes
    LDR R1, [R0]
    CMP R1, #MAX_MINUTES
    BEQ update_timer_reset_minutes

    // increment minute
    ADD R1, R1, #1
    STR R1, [R0]
    B update_timer_return

.thumb_func
update_timer_reset_minutes:
    // set minute to 0
    LDR R0, =minutes
    MOV R1, #0
    STR R1, [R0]
    B update_timer_return

.thumb_func
update_timer_return:
    POP {R0, R1, PC}

// Entry
.global Start
Start:

    BL init_display
    BL init_button
    BL init_timer

.thumb_func
loop:

    WFI
    B loop

NOP // Behold denne på bunnen av fila
