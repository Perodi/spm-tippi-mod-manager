    .include "common.s"

    .global memory_patch

# ------------------------------------------------------------------------------------------------
# Subroutine parameters
# ------------------------------------------------------------------------------------------------
    .set target, %r3                            # The address of the object/function being patched
    .set table, %r4                             # The address of the table of patches
    .set table_end, %r5                         # The address of the end of the table

    .section .text
# ------------------------------------------------------------------------------------------------
# Prologue
# ------------------------------------------------------------------------------------------------
memory_patch:
    .set frame_size, 0x10
    .set lr_offset, 0x4

    stwu %r1, -frame_size (%r1)                 # Push new stack frame
    mflr %r0                                    # Load link register
    stw %r0, frame_size + lr_offset (%r1)       # Save link register in stack frame

# ------------------------------------------------------------------------------------------------
# Loop through each patch (offset, instruction) and write it to the target
# ------------------------------------------------------------------------------------------------
    .set address, %r6                           # The address to write the new instruction to
    .set instruction, %r7                       # The replacement instruction
memory_patch_loop:
    lwz address, 0x0 (table)                    # Load the next offset
    add address, address, target                # Add the offset to the target parameter
    lwz instruction, 0x4 (table)                # Load the replacement instruction
    stw instruction, 0x0 (address)              # Store the instruction to the calculated address
    addi table, table, 0x8                      # Increment to the next item in the table
    cmpl 0x0, table, table_end                  # Continue the loop until the end of the table
    bne memory_patch_loop     

# ------------------------------------------------------------------------------------------------
# Epilogue
# ------------------------------------------------------------------------------------------------
    lwz %r0, frame_size + lr_offset (%r1)       # Retrieve last link register from stack
    mtlr %r0                                    # Restore link register
    addi %r1, %r1, frame_size                   # Pop current stack frame
    blr                                         # Return
