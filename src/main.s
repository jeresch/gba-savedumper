.cpu arm7tdmi
@.syntax unified

.section .text.rom

.arm

.set MGBA_LOG_ENABLE, 1
.set MGBA_LOG_REG_ENABLE, 0x04FFF780
.set MGBA_LOG_REG_FLAGS, 0x04FFF700
.set MGBA_LOG_STRING, 0x04FFF600
.set MGBA_LOG_ERROR, 1


.macro m3_log s:vararg
.pushsection .rodata.ram
.Lstring_\@:
    .asciz \s
.popsection
    push {r0-r3}
    ldr r0, =$.Lstring_\@
    bl m3_log
    pop {r0-r3}
.endm


.global _start
_start:
    b init


header:
    @ Nintendo logo; 156 bytes
    .byte 0x24,0xFF,0xAE,0x51,0x69,0x9A,0xA2,0x21,0x3D,0x84,0x82,0x0A,0x84,0xE4,0x09,0xAD
    .byte 0x11,0x24,0x8B,0x98,0xC0,0x81,0x7F,0x21,0xA3,0x52,0xBE,0x19,0x93,0x09,0xCE,0x20
    .byte 0x10,0x46,0x4A,0x4A,0xF8,0x27,0x31,0xEC,0x58,0xC7,0xE8,0x33,0x82,0xE3,0xCE,0xBF
    .byte 0x85,0xF4,0xDF,0x94,0xCE,0x4B,0x09,0xC1,0x94,0x56,0x8A,0xC0,0x13,0x72,0xA7,0xFC
    .byte 0x9F,0x84,0x4D,0x73,0xA3,0xCA,0x9A,0x61,0x58,0x97,0xA3,0x27,0xFC,0x03,0x98,0x76
    .byte 0x23,0x1D,0xC7,0x61,0x03,0x04,0xAE,0x56,0xBF,0x38,0x84,0x00,0x40,0xA7,0x0E,0xFD
    .byte 0xFF,0x52,0xFE,0x03,0x6F,0x95,0x30,0xF1,0x97,0xFB,0xC0,0x85,0x60,0xD6,0x80,0x25
    .byte 0xA9,0x63,0xBE,0x03,0x01,0x4E,0x38,0xE2,0xF9,0xA2,0x34,0xFF,0xBB,0x3E,0x03,0x44
    .byte 0x78,0x00,0x90,0xCB,0x88,0x11,0x3A,0x94,0x65,0xC0,0x7C,0x63,0x87,0xF0,0x3C,0xAF
    .byte 0xD6,0x25,0xE4,0x8B,0x38,0x0A,0xAC,0x72,0x21,0xD4,0xF8,0x07

    @ Game title; 12 bytes
    .zero 12

    @ AGB-UTTD game code; 4 bytes
    .ascii "AMTE"
    @ .byte 'B'               @ Game type: Normal "newer" game
    @ .byte 0x00,0x00         @ Short title
    @ .byte 'E'               @ Language: English

    .byte 0x30,0x31         @ Maker code; 0x30,0x31 for Nintendo
    .byte 0x96              @ Fixed
    .byte 0x00              @ Unit code
    .byte 0x00              @ Device type; 0 for normal catridges
    .zero 7                 @ Reserved
    .byte 0x00              @ Game version
    .byte 0xC9              @ Header checksum
    .zero 2                 @ Reserved
end_header:

@ Fool mgba MB detection
.word 0xEA000000 @ b 0

.align 2
.asciz "SRAM_Vnnn"

.align 2
.set IRQ_MODE, 0x12
.set SYS_MODE, 0x1F
.set IRQ_STACK, 0x03007FA0
.set SYS_STACK, 0x03007300
.func init
init:
    mov r0, $IRQ_MODE
    msr cpsr_fc, r0
    ldr sp, =IRQ_STACK

    mov r0, $SYS_MODE
    msr cpsr_fc, r0
    ldr sp, =SYS_STACK

    bl copy_code_to_wram

    @ Branch to main(), switching to THUMB state
    ldr r0, =main
    add r0, $1
    mov lr, pc
    bx r0
    b init
.endfunc


.extern _ramtext_vma_begin _ramtext_lma_begin _ramtext_lma_end
.extern _ramrodata_vma_begin _ramrodata_lma_begin _ramrodata_lma_end
.extern _ramdata_vma_begin _ramdata_lma_begin _ramdata_lma_end
.func copy_code_to_wram
copy_code_to_wram:
    push {lr}

    @ Copy ramtext
    ldr r0, =_ramtext_lma_begin
    ldr r1, =_ramtext_vma_begin
    ldr r2, =_ramtext_lma_end
    sub r2, r0
    bl rom_memcpy16

    @ Copy rodata
    ldr r0, =_ramrodata_lma_begin
    ldr r1, =_ramrodata_vma_begin
    ldr r2, =_ramrodata_lma_end
    sub r2, r0
    bl rom_memcpy16

    @ Copy data
    ldr r0, =_ramdata_lma_begin
    ldr r1, =_ramdata_vma_begin
    ldr r2, =_ramdata_lma_end
    sub r2, r0
    bl rom_memcpy16
    
    pop {lr}
    bx lr
.endfunc


.func rom_memcpy16
rom_memcpy16:
    @ r0 = src
    @ r1 = dst
    @ r2 = bytelen
    @ r3 = i
    @ r4 = scratch
    push {r4}
    mov r3, $0
.Lloop_begin:
    cmp r3, r2
    beq .Lloop_end

    ldrh r4, [r0, r3]
    strh r4, [r1, r3]

    add r3, $2

    b .Lloop_begin
.Lloop_end:
    pop {r4}
    bx lr
.endfunc


.section .text.ram.0
.thumb

.extern bios_halt
.func main
main:
    @ Detect mgba
    ldr r0, =0xC0DE
    ldr r1, =$MGBA_LOG_REG_ENABLE
    strh r0, [r1]
    ldrh r1, [r1]
    ldr r0, =0x1DEA
    cmp r0, r1
    bne .Lmain_real_hw
    ldr r0, =$g_is_in_mgba
    mov r1, $1
    str r1, [r0]

.Lmain_real_hw:
    mov r0, $CARTSWAP_STAGE_FLASHCART_LOADED
    ldr r1, =$g_cart_swap_stage
    str r0, [r1]

    @ Setup screen, interrupts
    bl setup_screen
    bl m3_clr

    bl init_interrupts
    bl enable_irq

    .extern magic_present
    bl magic_present
    cmp r0, $1
    beq .Lmain_magic_present
    b .Lmain_magic_absent

.Lmain_magic_absent:
    @ Write magic
    str r1, [r0]

    @ Cart swap
    ldr r0, =$g_cart_swap_stage
    ldr r0, [r0]
    cmp r0, $CARTSWAP_STAGE_FLASHCART_LOADED
    bne .Lmain_goto_panic
    m3_log "Please remove cartridge"
    bl bios_halt

.Lmain_magic_present:
    ldr r0, =$g_cart_swap_stage
    mov r1, $CARTSWAP_STAGE_FLASHCART_REINSERTED
    str r1, [r0]
    bl on_flash_cart_reinserted
    bl bios_halt

.Lmain_goto_panic:
    bl panic
.endfunc


.set REG_KEYCNT, 0x04000132
.func on_flash_cart_removed
on_flash_cart_removed:
    push {lr}
    ldr r0, =$g_cart_swap_stage
    ldr r1, [r0]
    cmp r1, $CARTSWAP_STAGE_FLASHCART_LOADED
    bne .Lon_flash_cart_removed_goto_panic

    @ No work to do here...

    mov r1, $CARTSWAP_STAGE_FLASHCART_REMOVED
    str r1, [r0]

    m3_log "Insert OEM cart"

    ldr r0, =$g_is_in_mgba
    ldr r0, [r0]
    cmp r0, $1
    bne .Lon_flash_cart_removed_done
    @ Enable button control because mgba doesn't raise gamepak interrupt
    @ when swapping roms
    m3_log "in mgba press A to continue"
    ldr r0, =$0b0100000000000001 @ enables A button interrupt
    ldr r1, =$REG_KEYCNT
    strh r0, [r1]

.Lon_flash_cart_removed_done:
    @ Already in interrupt, just return
    pop {pc}

.Lon_flash_cart_removed_goto_panic:
    bl panic
.endfunc

.func on_oem_cart_inserted
on_oem_cart_inserted:
    push {lr}

    ldr r0, =$g_cart_swap_stage
    ldr r1, [r0]
    cmp r1, $CARTSWAP_STAGE_OEM_SAVE_NOT_YET_LOADED
    bne .Lon_oem_cart_inserted_goto_panic

    push {r0}
    bl detect_save_type
    bl copy_save_data_to_ewram
    pop {r0}

    mov r1, $CARTSWAP_STAGE_OEM_SAVE_LOADED
    str r1, [r0]

    m3_log "Remove OEM cart"

    @ Already in interrupt, just return
    pop {pc}

.Lon_oem_cart_inserted_goto_panic:
    bl panic
.endfunc

.func on_oem_cart_removed
on_oem_cart_removed:
    push {lr}

    ldr r0, =$g_cart_swap_stage
    ldr r1, [r0]
    cmp r1, $CARTSWAP_STAGE_OEM_SAVE_LOADED
    bne .Lon_oem_cart_removed_goto_panic

    @ No work to do here

    mov r1, $CARTSWAP_STAGE_OEM_CART_REMOVED
    str r1, [r0]

    m3_log "Re-insert flash cart"

    ldr r0, =$g_is_in_mgba
    ldr r0, [r0]
    cmp r0, $1
    bne .Lon_oem_cart_removed_done
    @ Enable button control because mgba doesn't raise gamepak interrupt
    @ when swapping roms
    m3_log "in mgba press A to continue"
    ldr r0, =$0b0100000000000001 @ enables A button interrupt
    ldr r1, =$REG_KEYCNT
    strh r0, [r1]

.Lon_oem_cart_removed_done:
    @ Already in interrupt, just return
    pop {pc}

.Lon_oem_cart_removed_goto_panic:
    bl panic
.endfunc
 

.set REG_KEYINPUT, 0x04000130
.func on_flash_cart_reinserted
on_flash_cart_reinserted:
    push {lr}

    ldr r0, =$g_cart_swap_stage
    ldr r1, [r0]
    cmp r1, $CARTSWAP_STAGE_FLASHCART_REINSERTED
    bne .Lon_flash_cart_reinserted_goto_panic

    @ If real hardware, need to jump to flash card and hope we end up back here
    ldr r2, =$g_is_in_mgba
    ldr r2, [r2]
    cmp r2, $0
    bne .Lon_flash_cart_reinserted_in_mgba
    bl magic_present
    cmp r0, $1
    beq .Lon_flash_cart_reinserted_with_magic

    @ cross fingers and jump to ARM ROM
    m3_log "Need to jump to flash cart"
    m3_log "Reopen this custom rom"
    m3_log "Press A when ready"
    ldr r0, =$REG_KEYINPUT
.Lon_flash_cart_reinserted_await_A_press:
    ldr r1, [r0]
    mov r2, $1
    and r1, r2
    cmp r1, $0
    bne .Lon_flash_cart_reinserted_await_A_press

    ldr r0, =$0x08000000
    bx r0

.Lon_flash_cart_reinserted_in_mgba:
.Lon_flash_cart_reinserted_with_magic:
    @ Copy save data from EWRAM to new cart sram
    push {r0}
    bl copy_ewram_to_save_data
    pop {r0}

    mov r1, $CARTSWAP_STAGE_OEM_SAVE_DUMPED
    str r1, [r0]

    @ End
    m3_log "All done!"

    @ Return out of the interrupt handler to halted cpu
    pop {pc}

.Lon_flash_cart_reinserted_goto_panic:
    bl panic
.endfunc


.set SRAM_REGION_BEGIN, 0x0E000000
.set SRAM_REGION_END, 0x0E010000
.set SRAM_REGION_SIZE, SRAM_REGION_END - SRAM_REGION_BEGIN
.extern _ramsave_area_begin
.func copy_save_data_to_ewram
copy_save_data_to_ewram:
    push {lr}

    @ Dispatch on save type
    ldr r0, =$g_cart_save_type
    ldr r0, [r0]

    cmp r0, $CART_SAVE_TYPE_UNKNOWN
    beq .Lcopy_save_data_to_ewram_type_UNKNOWN
    cmp r0, $CART_SAVE_TYPE_EEPROM
    beq .Lcopy_save_data_to_ewram_type_EEPROM
    cmp r0, $CART_SAVE_TYPE_SRAM
    beq .Lcopy_save_data_to_ewram_type_SRAM
    cmp r0, $CART_SAVE_TYPE_FLASH
    beq .Lcopy_save_data_to_ewram_type_FLASH
    cmp r0, $CART_SAVE_TYPE_FLASH512
    beq .Lcopy_save_data_to_ewram_type_FLASH512
    cmp r0, $CART_SAVE_TYPE_FLASH1M
    beq .Lcopy_save_data_to_ewram_type_FLASH1M
    b .Lcopy_save_data_to_ewram_type_UNKNOWN

.Lcopy_save_data_to_ewram_type_UNKNOWN:
    m3_log "No save type found :("
    bl panic
    b .Lcopy_save_data_to_ewram_done

.Lcopy_save_data_to_ewram_type_SRAM:
    bl print_copying_save_to_wram
    ldr r0, =$SRAM_REGION_BEGIN
    ldr r1, =$_ramsave_area_begin
    ldr r2, =$SRAM_REGION_SIZE
    bl ram_memcpy8
    b .Lcopy_save_data_to_ewram_done

.Lcopy_save_data_to_ewram_type_EEPROM:
.Lcopy_save_data_to_ewram_type_FLASH:
.Lcopy_save_data_to_ewram_type_FLASH512:
.Lcopy_save_data_to_ewram_type_FLASH1M:
    m3_log "Unimplemented"
    ldr r1, =$g_cart_save_type
    ldr r1, [r1]
    mov r0, $4
    mul r1, r0
    ldr r0, =$cart_save_type_pattern_table
    add r0, r1
    ldr r0, [r0]
    bl m3_log
    bl panic
    b .Lcopy_save_data_to_ewram_done

.Lcopy_save_data_to_ewram_done:
    pop {pc}
.endfunc


.func print_copying_save_to_wram
print_copying_save_to_wram:
    push {lr}

    m3_log "Copying save to WRAM"

    ldr r1, =$g_cart_save_type
    ldr r1, [r1]
    mov r0, $4
    mul r1, r0
    ldr r0, =$cart_save_type_pattern_table
    add r0, r1
    ldr r0, [r0]
    bl m3_log

    pop {pc}
.endfunc

.extern scan_memory32
.set ROM_REGION_BEGIN_ADDR, 0x08000000
.set ROM_REGION_END_ADDR, 0x09FFFFFF
.func detect_save_type
detect_save_type:
    push {r4-r7, lr}
    
    ralignment .req r4
    ri .req r5

    mov ralignment, $4
    mov ri, $1
.Ldetect_save_type_loop_begin:
    cmp ri, $NUM_CART_SAVE_TYPES
    beq .Ldetect_save_type_not_found

    m3_log "Scanning for save type"

    ldr r0, =$cart_save_type_pattern_table
    mov r6, ralignment
    mul r6, ri
    add r0, r6
    ldr r0, [r0]
    push {r0-r3}
    bl m3_log
    pop {r0-r3}

    ldr r1, =$ROM_REGION_BEGIN_ADDR
    ldr r2, =$ROM_REGION_END_ADDR
    mov r3, ralignment
    mov r7, r0

    bl scan_memory32

    cmp r0, $0
    bne .Ldetect_save_type_found

    add ri, $1
    b .Ldetect_save_type_loop_begin

.Ldetect_save_type_found:
    ldr r0, =$g_cart_save_type
    str ri, [r0]
    m3_log "Detected save type"
    mov r0, r7
    bl m3_log

    b .Ldetect_save_type_done

.Ldetect_save_type_not_found:
    m3_log "No save type found, please restart"
    bl panic

    b .Ldetect_save_type_done

.Ldetect_save_type_done:
    .unreq ralignment
    .unreq ri

    pop {r4-r7, pc}
.endfunc


@ Returns 0 in r0 if strings match
.func strcmp
strcmp:
    rstr0ptr .req r0 @ must be null-terminated
    rstr1ptr .req r1

    rstr0char .req r2
    rstr1char .req r3

.Lstrcmp_loop_begin:
    ldrb rstr0char, [rstr0ptr]
    cmp rstr0char, $0
    beq .Lstrcmp_match

    ldrb rstr1char, [rstr1ptr]
    cmp rstr0char, rstr1char
    bne .Lstrcmp_mismatch

    add rstr0ptr, $1
    add rstr1ptr, $1

    b .Lstrcmp_loop_begin

    .unreq rstr0char
    .unreq rstr1char

.Lstrcmp_mismatch:
    mov r0, $1
    b .Lstrcmp_return

.Lstrcmp_match:
    mov r0, $0
    b .Lstrcmp_return

.Lstrcmp_return:
    bx lr
.endfunc


.func copy_ewram_to_save_data
copy_ewram_to_save_data:
    push {lr}

    @ Dispatch on save type
    ldr r0, =$g_cart_save_type
    ldr r0, [r0]

    cmp r0, $CART_SAVE_TYPE_UNKNOWN
    beq .Lcopy_ewram_to_save_data_type_UNKNOWN
    cmp r0, $CART_SAVE_TYPE_EEPROM
    beq .Lcopy_ewram_to_save_data_type_EEPROM
    cmp r0, $CART_SAVE_TYPE_SRAM
    beq .Lcopy_ewram_to_save_data_type_SRAM
    cmp r0, $CART_SAVE_TYPE_FLASH
    beq .Lcopy_ewram_to_save_data_type_FLASH
    cmp r0, $CART_SAVE_TYPE_FLASH512
    beq .Lcopy_ewram_to_save_data_type_FLASH512
    cmp r0, $CART_SAVE_TYPE_FLASH1M
    beq .Lcopy_ewram_to_save_data_type_FLASH1M
    b .Lcopy_ewram_to_save_data_type_UNKNOWN

.Lcopy_ewram_to_save_data_type_UNKNOWN:
    m3_log "No save type detected, please restart"
    bl panic
    b .Lcopy_ewram_to_save_data_done

.Lcopy_ewram_to_save_data_type_SRAM:
    m3_log "Dumping save now"
    ldr r0, =$_ramsave_area_begin
    ldr r1, =$SRAM_REGION_BEGIN
    ldr r2, =$SRAM_REGION_SIZE
    bl ram_memcpy8
    b .Lcopy_ewram_to_save_data_done

.Lcopy_ewram_to_save_data_type_EEPROM:
.Lcopy_ewram_to_save_data_type_FLASH:
.Lcopy_ewram_to_save_data_type_FLASH512:
.Lcopy_ewram_to_save_data_type_FLASH1M:
    m3_log "Unimplemented"
    ldr r1, =$g_cart_save_type
    ldr r1, [r1]
    mov r0, $4
    mul r1, r0
    ldr r0, =$cart_save_type_pattern_table
    add r0, r1
    ldr r0, [r0]
    bl m3_log
    bl panic
    b .Lcopy_ewram_to_save_data_done

.Lcopy_ewram_to_save_data_done:
    pop {pc}
.endfunc


.section .text.ram.1


.set REG_DISPCNT, 0x04000000
.set DISPCNT_MODE_MASK, 0x00000007
.set DISPCNT_PAGE_MASK, 0x00000010
.set REG_DISPSTAT, 0x04000004
.set REG_VCOUNT, 0x04000006
.set M3_VIDEO_PAGE, 0x06000000
.set TARGET_VIDEO_MODE, 0x403
.func setup_screen
setup_screen:
    ldr r0, =$TARGET_VIDEO_MODE
    ldr r1, =$REG_DISPCNT
    strh r0, [r1]
    bx lr
.endfunc


.set REG_BASE, 0x04000000
.set REG_IE, REG_BASE + 0x0200
.set REG_IF, REG_BASE + 0x0202
.set REG_IME, REG_BASE + 0x0208
.set ISR_ADDR, 0x03007FFC
.set GAMEPAK_BIT, 0xB
.set GAMEPAK_MASK, 0b0010000000000000

.func enable_irq
enable_irq:
    ldr r0, =$REG_IE
    ldr r1, =$GAMEPAK_MASK

    ldr r2, =$g_is_in_mgba
    ldr r2, [r2]
    cmp r2, $1
    bne .Lenable_irq_real_hardware
    ldr r2, =$KEYPAD_MASK
    orr r1, r2

.Lenable_irq_real_hardware:
    str r1, [r0]

    ldr r0, =$REG_IME
    mov r1, $1
    str r1, [r0]

    bx lr
.endfunc


.func handle_gamepak_interrupt
handle_gamepak_interrupt:
    push {lr}

    ldr r0, =$g_cart_swap_stage
    ldr r0, [r0]
    cmp r0, $CARTSWAP_STAGE_FLASHCART_NOT_YET_LOADED
    beq .Lhandle_gamepak_interrupt_FLASHCART_NOT_YET_LOADED
    cmp r0, $CARTSWAP_STAGE_FLASHCART_LOADED
    beq .Lhandle_gamepak_interrupt_FLASHCART_LOADED
    cmp r0, $CARTSWAP_STAGE_FLASHCART_REMOVED
    beq .Lhandle_gamepak_interrupt_FLASHCART_REMOVED
    cmp r0, $CARTSWAP_STAGE_OEM_SAVE_NOT_YET_LOADED
    beq .Lhandle_gamepak_interrupt_OEM_SAVE_NOT_YET_LOADED
    cmp r0, $CARTSWAP_STAGE_OEM_SAVE_LOADED
    beq .Lhandle_gamepak_interrupt_OEM_SAVE_LOADED
    cmp r0, $CARTSWAP_STAGE_OEM_CART_REMOVED
    beq .Lhandle_gamepak_interrupt_OEM_CART_REMOVED
    cmp r0, $CARTSWAP_STAGE_FLASHCART_REINSERTED
    beq .Lhandle_gamepak_interrupt_FLASHCART_REINSERTED
    cmp r0, $CARTSWAP_STAGE_OEM_SAVE_DUMPED
    beq .Lhandle_gamepak_interrupt_OEM_SAVE_DUMPED

    @ Unknown state
    bl panic

.Lhandle_gamepak_interrupt_FLASHCART_NOT_YET_LOADED:
    @ Shouldn't get into this state from an interrupt
    @ Did we yank too early somehow?
    bl panic

.Lhandle_gamepak_interrupt_FLASHCART_LOADED:
    bl on_flash_cart_removed
    b .Lhandle_gamepak_interrupt_done

.Lhandle_gamepak_interrupt_FLASHCART_REMOVED:
    ldr r0, =$g_cart_swap_stage
    mov r1, $CARTSWAP_STAGE_OEM_SAVE_NOT_YET_LOADED
    str r1, [r0]
    bl on_oem_cart_inserted
    b .Lhandle_gamepak_interrupt_done

.Lhandle_gamepak_interrupt_OEM_SAVE_NOT_YET_LOADED:
    @ Shouldn't get here on interrupt
    bl on_oem_cart_removed
    b .Lhandle_gamepak_interrupt_done

.Lhandle_gamepak_interrupt_OEM_SAVE_LOADED:
    bl on_oem_cart_removed
    b .Lhandle_gamepak_interrupt_done

.Lhandle_gamepak_interrupt_OEM_CART_REMOVED:
    ldr r0, =$g_cart_swap_stage
    mov r1, $CARTSWAP_STAGE_FLASHCART_REINSERTED
    str r1, [r0]
    bl on_flash_cart_reinserted
    b .Lhandle_gamepak_interrupt_done

.Lhandle_gamepak_interrupt_FLASHCART_REINSERTED:
    @ Shouldn't get interrupt here
    bl panic

.Lhandle_gamepak_interrupt_OEM_SAVE_DUMPED:
    @ Shouldn't get interrupt here
    bl panic

.Lhandle_gamepak_interrupt_done:
    pop {pc}
.endfunc


.func ram_memcpy8
ram_memcpy8:
    @ r0 = src
    @ r1 = dst
    @ r2 = bytelen
    @ r3 = i
    @ r4 = scratch
    push {r4}
    mov r3, $0
.Lram_memcpy8_loop_begin:
    cmp r3, r2
    beq .Lram_memcpy8_loop_end

    ldrb r4, [r0, r3]
    strb r4, [r1, r3]

    add r3, $1

    b .Lram_memcpy8_loop_begin
.Lram_memcpy8_loop_end:
    pop {r4}
    bx lr
.endfunc


.extern panic


.section .data.ram

.set CARTSWAP_STAGE_FLASHCART_NOT_YET_LOADED, 0
.set CARTSWAP_STAGE_FLASHCART_LOADED, 1
.set CARTSWAP_STAGE_FLASHCART_REMOVED, 2
.set CARTSWAP_STAGE_OEM_SAVE_NOT_YET_LOADED, 3
.set CARTSWAP_STAGE_OEM_SAVE_LOADED, 4
.set CARTSWAP_STAGE_OEM_CART_REMOVED, 5
.set CARTSWAP_STAGE_FLASHCART_REINSERTED, 6
.set CARTSWAP_STAGE_OEM_SAVE_DUMPED, 7
.align 2
g_cart_swap_stage:
    .word 0x00000000


.set CART_SAVE_TYPE_UNKNOWN, 0
.set CART_SAVE_TYPE_EEPROM, 1
.set CART_SAVE_TYPE_SRAM, 2
.set CART_SAVE_TYPE_FLASH, 3
.set CART_SAVE_TYPE_FLASH512, 4
.set CART_SAVE_TYPE_FLASH1M, 5
.set NUM_CART_SAVE_TYPES, 6
.align 2
g_cart_save_type:
    .word 0x00000000

.align 2
g_is_in_mgba:
    .word 0x00000000
