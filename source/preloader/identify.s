    .include "common.s"

    .global identify

    .section .text

    .set ID_HIGH, 0x5238                        # "R8"
    .set ID_EU, 0x5050                          # "PP"
    .set ID_JP, 0x504A                          # "PJ"
    .set ID_KR, 0x504B                          # "PK"
    .set ID_NA, 0x5045                          # "PE"

identify:
    # Returns
    .set region, %r3
    .set revision, %r4
    .set array_offset, %r5

    # Prologue
    .set frame_size, 0x10
    .set lr_offset, 0x4

    stwu stack_ptr, -frame_size (stack_ptr)     # Push new stack frame
    mflr %r0                                    # Load link register
    stw %r0, frame_size+lr_offset (stack_ptr)   # Save link register in stack frame

    # Load game id, region, and revision from 0x80000000
    .set id, %r3
    lis id, 0x8000                              # Load pointer to the game id (0x80000000)
    lhz revision, 0x4 (id)                      # Load the half-word containging the revision number
    lwz id, 0x0 (id)                            # Load the game id and region

    # Check for valid game id
    .set result, %r6
    # Xor the high 4 bytes with the correct id, all the xor-ed digits will be zero if they match
    xoris result, id, ID_HIGH

    li region, EU_INFO                          # Set region and last_revision for EU

    cmpli 0, result, ID_EU                      # Check EU
    beq check_revision

    li region, JP_INFO                          # Set region and last_revision for JP
    cmpli 0, result, ID_JP                      # Check JP
    beq check_revision

    li region, KR_INFO                          # Set region and last_revision for KR
    cmpli 0, result, ID_KR                      # Check KR
    beq check_revision

    li region, NA_INFO                          # Set region and last_revision for NA
    cmpli 0, result, ID_NA                      # Check NA
    beq check_revision
    
    b error                                     # Otherwise return error

check_revision:
    .set last_revision, %r6

    cmpli 0, revision, 0x3033                   # Check the revision is not somehow more than "03"
    bgt error
    cmpli 0, revision, 0x3031                   # Check the revision is not somehow less than "01"
    blt error

    andi. revision, revision, 0xf               # Mask the revision to convert it to a number
    andi. last_revision, region, 0b11           # Get the last released revision for the given version
    cmpl 0, revision, last_revision             # Check if the revision number is in the correct range
    bgt error                                   # If not, return error

    # Get array offset
    andi. array_offset, region, 0xFF00          # Get the region offset from the region info
    srawi array_offset, array_offset, 8         # Shift the region offset to get the correct number
    addi %r6, revision, -1                      # Subtract 1 from the revision to make zero indexed
    mulli %r6, %r6, 4                           # Multiply by the length of a long
    add array_offset, array_offset, %r6         # Add together

epilogue:
    lwz %r0, frame_size+lr_offset (stack_ptr)   # Retrieve last link register from stack
    mtlr %r0                                    # Restore last link register
    addi stack_ptr, stack_ptr, frame_size       # Pop current stack frame
    blr                                         # Return

error:
    # Set return values to correspond to error before exitting subroutine
    li region, -0x1                             # Set region to -1
    li revision, 0x0                            # Set revision to 0
    b epilogue
