# --------------------------------------------------------------------------------
# Region info codes (xxxxxxxx .....ABB)
# xxxxxxxx: Offset into pointer arrays
# A: Needs patch for memInit()
# BB: Last released version
# --------------------------------------------------------------------------------
    .set EU_INFO, 0b0000000000000010
    .set JP_INFO, 0b0000100000000110
    .set KR_INFO, 0b0001000000000001
    .set NA_INFO, 0b0001010000000111

# --------------------------------------------------------------------------------
# Preloader common aliases
# --------------------------------------------------------------------------------
    .set stack_ptr, %r1

    .set region, %r29
    .set array_offset, %r30
    .set base_addr, %r31
    .set base_high, 0x8123
    .set base_low, 0x5000

    .global preloader

# ------------------------------------------------------------------------------------------------
# Prologue
# ------------------------------------------------------------------------------------------------
preloader:
    .set frame_size, 0x20
    .set lr_offset, 0x4

    stwu stack_ptr, -frame_size (stack_ptr)     # Push new stack frame
    mflr %r0                                    # Load link register
    stw %r0, frame_size+lr_offset (stack_ptr)   # Save link register in stack frame
    stw %r29, 0x4 (stack_ptr)                   # Push r29 to the stack
    stw %r30, 0x8 (stack_ptr)                   # Push r30 to the stack
    stw %r31, 0xc (stack_ptr)                   # Push r31 to the stack

# ------------------------------------------------------------------------------------------------
# Setup
# ------------------------------------------------------------------------------------------------
    lis base_addr, base_high                    # Load the high 4 bytes of the base address
    ori base_addr, base_addr, base_low          # Load the low 4 bytes of the base address

    .set r_region, %r3
    .set r_revision, %r4
    .set r_offset, %r5
    bl identify                                 # Call identify subroutine

    cmpi 0, r_region, -1                        # If an error was thrown, just return to normal execution
    beq epilogue

    or array_offset, r_offset, r_offset        # Save the returned array offset in r30
    or region, r_region, r_region              # Save the returned region info r29

# ------------------------------------------------------------------------------------------------
# Patch memInit()
# ------------------------------------------------------------------------------------------------
    andi. %r3, region, 0b100                    # Check if this region needs the memInit patches
    cmpi 0, %r3, 0
    beq patch_rel_main                          # If it doesn't, move on

    .set param_target, %r3
    .set param_table, %r4
    .set param_end, %r5
    add param_target, array_offset, base_addr   # Setup target with a pointer to memInit()
    lwz param_target, mem_init_ptrs (param_target)
    addi param_table, base_addr, mem_init_patches   # Setup the patch table with appropriate start and end
    addi param_end, base_addr, mem_init_patches_end
    bl memory_patch                             # Run memory_patch subroutine

# ------------------------------------------------------------------------------------------------
# Patch relMain()
# ------------------------------------------------------------------------------------------------
    .set kr_string_diff, -0x20
patch_rel_main:
    cmpli 0, region, KR_INFO                    # Check if the game is the Korean release
    bne patch_rel_main_params

    # Korea has a slightly different string offset in relMain. It is -0x20 off of the other versions
    add %r3, array_offset, base_addr            # Load the pointer to the instruction to change
    lwz %r4, rel_main_kr+4 (%r3)                # Load the instruction
    addi %r4, %r4, kr_string_diff               # Add the difference
    stw %r4, rel_main_kr+4 (%r3)                # Store the new instruction in the table

patch_rel_main_params:
    add param_target, array_offset, base_addr   # Setup target with a pointer to relMain()
    lwz param_target, rel_main_ptrs (param_target)
    addi param_table, base_addr, rel_main_patches   # Setup the patch table with the right table start and end
    addi param_end, base_addr, rel_main_patches_end
    bl memory_patch                             # Run memory_patch subroutine

# ------------------------------------------------------------------------------------------------
# Patch size_table
# ------------------------------------------------------------------------------------------------
    .set original_ptr, %r3
    .set table_ptr, %r4
    .set table_end, %r5
    add original_ptr, array_offset, base_addr   # Load a pointer to the game's size_table
    lwz original_ptr, size_table_ptrs (original_ptr)
    addi table_ptr, base_addr, size_table       # Initialize pointers to the beginning and end of replacement table
    addi table_end, base_addr, size_table_split

    # Loop through all the data until the split marker, copying over the new table
size_table_loop:
    lwz %r6, 0 (table_ptr)                    # Load the replacement value from the new table
    stw %r6, 0 (original_ptr)                 # Store the replacement value in the game's table

    addi table_ptr, table_ptr, 4                # Increment the two pointers
    addi original_ptr, original_ptr, 4

    cmpl 0, table_ptr, table_end                # Check if the split point has been reached
    bne size_table_loop

    cmpli 0, region, KR_INFO                    # Check if the game is the Korean release
    beq patch_kr

    # For all other versions, just copy the remaining bytes all at once, since now there's enough registers
    lswi %r6, table_ptr, size_table_end - size_table_split
    stswi %r6, original_ptr, size_table_end - size_table_split

    b patch_rel_string                          # Branch to the next patch

patch_kr:
    # For the Korean version, copy all the remaining bytes from the longer Korean size_table
    addi table_ptr, table_ptr, size_table_kr - size_table_split
    lswi %r6, table_ptr, size_table_kr_end - size_table_kr
    stswi %r6, original_ptr, size_table_kr_end - size_table_kr

# ------------------------------------------------------------------------------------------------
# Patch decompressed rel file name
# ------------------------------------------------------------------------------------------------
    .set instruction_offset, 0x5c
patch_rel_string:
    add %r3, array_offset, base_addr            # Load a pointer to relMain()
    lwz %r3, rel_main_ptrs (%r3)
    lwz %r3, instruction_offset (%r3)           # Load the instruction where the relDecomp string is used
    oris %r3, %r3, 0xffff                       # Or the high 16 bits to get the correct offset negative number
    add %r3, %r3, %r13                          # Add the offset to %r13, like is used in relMain
    lwz %r3, 0x0 (%r3)                          # Dereference the pointer to the string
    
    addi %r4, base_addr, rel_string             # Get the absolute address of the new file name
    lswi %r5, %r4, rel_string_end - rel_string  # Load the whole name in registers r5 and r6
    stswi %r5, %r3, rel_string_end - rel_string # Store the file name in memory at the found pointer

# ------------------------------------------------------------------------------------------------
# Epilogue
# ------------------------------------------------------------------------------------------------
    lwz %r29, 0x4 (stack_ptr)                   # Restore r29
    lwz %r30, 0x8 (stack_ptr)                   # Restore r30
    lwz %r31, 0xc (stack_ptr)                   # Restore r31
    lwz %r0, frame_size + lr_offset (%r1)       # Retrieve last link register from stack
    mtlr %r0                                    # Restore last link register
    addi stack_ptr, stack_ptr, frame_size       # Pop current stack frame
    blr                                         # Return




# ------------------------------------------------------------------------------------------------
# Data
# ------------------------------------------------------------------------------------------------
    .section .data
rel_string:
    .string "mod.rel"
rel_string_end:

mem_init_ptrs:
    .long 0x801a5dcc, 0x801a5dcc                # eu0, eu1
    .long 0x801a5184, 0x801a51cc                # jp0, jp1
    .long 0x8019e6a4                            # kr0
    .long 0x801a5194, 0x801a51f0, 0x801a5508    # us0, us1, us2

size_table_ptrs:
    .long 0x8042a408, 0x8042a408                # eu0, eu1
    .long 0x803bfc68, 0x803c0de8                # jp0, jp1
    .long 0x8045b3c8                            # kr0
    .long 0x803eaa08, 0x803ebd68, 0x803ebf48    # us0, us1, us2

rel_main_ptrs:
    .long 0x8023e444, 0x8023e444                # eu0, eu1
    .long 0x8023bdf8, 0x8023c4a4                # jp0, jp1
    .long 0x80236b10                            # kr0
    .long 0x8023be50, 0x8023c53c, 0x8023c860    # us0, us1, us2

mem_init_patches:
    .long 0xa0, 0x2c1d0003      # cmpwi r29, 0x5        ->  cmpwi r29, 0x3      First while loop
    .long 0x178, 0x2c1b0003     # cmpwi r27, 0x5        ->  cmpwi r27, 0x3      Second while loop
    .long 0x1b0, 0x2c190003     # cmpwi r25, 0x5        ->  cmpwi r25, 0x3      Third while loop
    .long 0x1e0, 0x3b600003     # li r27, 0x5           ->  li r27, 0x3         Init fourth while loop
    .long 0x1e4, 0x3b240018     # addi r25, r4, 0x28    ->  addi r25, r4, 0x18  ...
    .long 0x1e8, 0x3b40000c     # li r26, 0x14          ->  li r26, 0xC         ...
    .long 0x274, 0x3b600003     # li r27, 0x5           ->  li r27, 0x3         Init fifth while loop
    .long 0x278, 0x3be30018     # addi r31, r3, 0x28    ->  addi r31, r3, 0x18  ...
    .long 0x27c, 0x3bc0000c     # li r30, 0x14          ->  li r30, 0xC         ...
    .long 0x344, 0x3b200003     # li r25, 0x5           ->  li r25, 0x3         Init sixth while loop
    .long 0x348, 0x3b00000c     # li r24, 0x14          ->  li r24, 0xC         ...
mem_init_patches_end:

rel_main_patches:
    .long 0x1c, 0x2c000002
    .long 0x20, 0x41820184
    .long 0xac, 0x48000018
    .long 0xb0, 0x39080001
    .long 0xb4, 0x99030008
rel_main_kr:
    .long 0xb8, 0x810d82a8
    .long 0xbc, 0x99080008
    .long 0x19c, 0x89030008
    .long 0x1a0, 0x4bffff10
rel_main_patches_end:

size_table:
    .long 0x1, 0x2400       # MAIN_HEAP (no change)
    .long 0x1, 0x1800       # MAP_HEAP (no change)
    .long 0x0, 100          # MEM1_HEAP_3 (increases in size for US and JP since following two heaps move)
    .long 0x1, 0x100        # EXT_HEAP (moved to MEM2 if not already)
    .long 0x1, 0x100        # EFFECT_HEAP (moved to MEM2 if not already)
    .long 0x1, 0x80         # WPAD_HEAP (no change)
    .long 0x1, 0x4000       # SOUND_HEAP (shrink by 1 MB)
    .long 0x0, 100          # SMART_HEAP (will shrink by about 15 MB)
size_table_split:
    .long 0x1, 0x4000       # MEM2_HEAP_6 (grows to 16 MB, for dedicated mod usage)
size_table_end:

size_table_kr:
    .long 0x1, 0x520        # Extra KR heap. Everything else is the same, but MEM2_HEAP_6 is smaller
    .long 0x1, 0x3ae0       # MEM2_HEAP_6 (Grows to about 14.7 MB, to account for the additional heap)
size_table_kr_end:

.include "common.s"
.include "identify.s"
.include "memory_patch.s"
