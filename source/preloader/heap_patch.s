    .set EU, 0
    .set US, 1
    .set JP, 2
    .set KR, 3

    .set r0, 0
    .set r1, 1
    .set r2, 2
    .set r14, 14
    .set r15, 15
    .set r16, 16
    .set r17, 17
    .set r18, 18
    .set r19, 19
    .set r20, 20
    .set r21, 21
    .set r22, 22
    .set r23, 23

# MARK:
    .data
memInit:
    .long 0x801A5DCC, 0x801A5DCC, 0             # eu0, eu1
    .long 0x801A5194, 0x801A51F0, 0x801A5508    # us0, us1, us2
    .long 0x801A5184, 0x801A51CC, 0             # jp0, jp1
    .long 0x8019E6A4, 0, 0                      # kr0

sizeTable:
    .long 0x8042A408, 0x8042A408, 0             # eu0, eu1
    .long 0x803EAA08, 0x803EBD68, 0x803EBF48    # us0, us1, us2
    .long 0x803BFC68, 0x803C0DE8, 0             # jp0, jp1
    .long 0x8045B3C8, 0, 0                      # kr0

memInitPatches:
    .long 0xA0, 0x2C1D0003      # cmpwi r29, 0x5        ->  cmpwi r29, 0x3      First while loop
    .long 0x178, 0x2C1B0003     # cmpwi r27, 0x5        ->  cmpwi r27, 0x3      Second while loop
    .long 0x1B0, 0x2C190003     # cmpwi r25, 0x5        ->  cmpwi r25, 0x3      Third while loop
    .long 0x1E0, 0x3B600003     # li r27, 0x5           ->  li r27, 0x3         Init fourth while loop
    .long 0x1E4, 0x3B240018     # addi r25, r4, 0x28    ->  addi r25, r4, 0x18  ...
    .long 0x1E8, 0x3B40000C     # li r26, 0x14          ->  li r26, 0xC         ...
    .long 0x274, 0x3B600003     # li r27, 0x5           ->  li r27, 0x3         Init fifth while loop
    .long 0x278, 0x3BE30018     # addi r31, r3, 0x28    ->  addi r31, r3, 0x18  ...
    .long 0x27C, 0x3BC0000C     # li r30, 0x14          ->  li r30, 0xC         ...
    .long 0x344, 0x3B200003     # li r25, 0x5           ->  li r25, 0x3         Init sixth while loop
    .long 0x348, 0x3B00000C     # li r24, 0x14          ->  li r24, 0xC         ...
memInitPatches_end:

newSizeTable:
    .long 0x1, 0x2400       # MAIN_HEAP (no change)
    .long 0x1, 0x1800       # MAP_HEAP (no change)
    .long 0x0, 100          # MEM1_HEAP_3 (increases in size for US and JP since following two heaps move)
    .long 0x1, 0x100        # EXT_HEAP (moved to MEM2 if not already)
    .long 0x1, 0x100        # EFFECT_HEAP (moved to MEM2 if not already)
    .long 0x1, 0x80         # WPAD_HEAP (no change)
    .long 0x1, 0x4000       # SOUND_HEAP (shrink by 1 MB)
    .long 0x0, 100          # SMART_HEAP (will shrink by about 15 MB)
    .long 0x1, 0x4000       # MEM2_HEAP_6 (grows to 16 MB, for dedicated mod usage)
newSizeTable_end:

newSizeTableKorea:
    .long 0x1, 0x2400
    .long 0x1, 0x1800
    .long 0x0, 100
    .long 0x1, 0x100
    .long 0x1, 0x100
    .long 0x1, 0x80
    .long 0x1, 0x4000
    .long 0x0, 100
    .long 0x1, 0x520        # Extra KR heap. Everything else is the same, but MEM2_HEAP_6 is smaller
    .long 0x1, 0x3AE0       # MEM2_HEAP_6 (Grows to about 14.7 MB, to account for the additional heap)
newSizeTableKorea_end:

# MARK:
    .text

    # Setup stack frame (prologue)
    stwu r1, -0x10 (r1)
    mflr r0
    stw r0, 0x14 (r1)

    lis r14, 0x8123             # Load the base address of this patch into r14
    ori r14, r14, 0x5000        # ...

    lis r15, 0x8000             # Load 0x8000000 into r15. This is the address of the game id in memory
    lwz r16, 4 (r15)            # Load the version number ASCII into r16 (ex: 0x3031 for "01")
    lwz r15, 0 (r15)            # Load the first four characters of the game id into r15 (ex: "R8PP")

    srawi r17, r15, 8           # Shift the game id right 8 bits to remove the region. Now it should be "R8P"
    lis r18, 0x0052             # Load the ASCII for "R8P" into r18
    ori r18, r18, 0x3850        # ...
    cmp 0, r17, r18             # Compare the game id with "R8P"
    bne return                  # If the game id didn't match. The game is likely not SPM

    srawi r16, r16, 16          # Shift the version number ASCII, removing the leading '0'
    andi. r16, r16, 0xF         # And with a mask to get the actual number from the ascii text ('1' -> 1)
    addi r16, r16, -1           # Subtract one to get the revision number (0 for eu0 from "R8PP01")

    # Making the assumption that the only regions that exist are 'P', 'E', 'J', and 'K', all those characters
    # lower 2 bits are different and are numbered 0-4 in that order.
    andi. r15, r15, 0b11        # And the game id with a mask to get just the low 2 bits

    mulli r17, r15, 0xC         # Multiply the game region by 0xC for the offset into the sizeTable list
    mulli r18, r16, 0x4         # Multiply the revision number by 0x4
    add r17, r17, r18           # Add the two offsets together to get the offset final offset into the list
    addi r17, r17, sizeTable    # Add the offset of the table in the patch
    add r17, r17, r14           # Add the patch's base address to get the address of the entry
    lwz r17, 0x0 (r17)          # Get the address of the actual sizeTable from the list

    cmpi 0, 1, r15, KR          # Check if the game is the Korean release
    beq initKorea               # Branch to initialize loop with seperate sizeTable for Korean

    li r18, newSizeTable        # Get the relative offset of the newSizeTable
    add r18, r18, r14           # Add the patch's base address to the relative offset of the newSizeTable

    li r19, newSizeTable_end    # Do the same thing with the end of the table for the loop condition
    add r19, r19, r14           # ...

    b sizeTableLoop             # Branch to the start of the loop to copy over the new table

initKorea:
    li r18, newSizeTableKorea   # Do the same as above, but with the Korean table instead
    add r18, r18, r14

    li r19, newSizeTableKorea_end
    add r19, r19, r14

sizeTableLoop:
    lwz r20, 0x0 (r18)          # Load the next word to copy from the newSizeTable
    stw r20, 0x0 (r17)          # Copy the word into the game's sizeTable

    addi r18, r18, 4            # Increment the newSizeTable address
    addi r17, r17, 4            # Increment the game's sizeTable address
    cmp 0, r18, r19             # Compare the next address with the end of newSizeTable
    bne sizeTableLoop           # If they aren't equal, continue the loop

# At this point, the size_table has been changed for each version. PAL and KR are done
# with the memory layout changes at this point. US and JP need some patches to memInit()
    cmpi 0, 1, r15, EU          # If the game's region is European, branch to the end
    beq return
    cmpi 0, 1, r15, KR          # If it's Korean, branch to the end. Leaving US and JP
    beq return

    mulli r17, r15, 0xC         # Do the same as with the size table to calculate the correct offset
    mulli r18, r16, 0x4
    add r17, r17, r18
    addi r17, r17, memInit
    add r17, r17, r14
    lwz r17, 0x0 (r17)          # Load the address of memInit into r17

    li r18, memInitPatches      # Load the relative offset of the memInitPatches table
    add r18, r18, r14           # Get it's absolute address

    li r19, memInitPatches_end  # Do the same thing with the end
    add r19, r19, r14

memInitLoop:
    lwz r20, 0x0 (r18)          # Load next patch offset into r20
    add r20, r20, r17           # Add the offset to the function's address to get the instruction's address
    lwz r21, 0x4 (r18)          # Load the new instruction from the table
    stw r21, 0x0 (r20)          # Store the new instruction at the found address

    addi r18, r18, 8            # Increment to the next patch in the table
    cmp 0, r18, r19             # Compare with the end of the table
    bne memInitLoop             # If the end has not been reached, continue the loop

return:
    # Clear used registers to zero "just in case"
    li r14, 0
    li r15, 0
    li r16, 0
    li r17, 0
    li r18, 0
    li r19, 0
    li r20, 0
    li r21, 0
    # Unpack stack frame
    lwz r0, 0x14 (r1)
    mtlr r0
    addi r1, r1, 0x10
    blr                         # Hopefully return to normal game execution
