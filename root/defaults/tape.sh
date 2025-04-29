echo "***********************************"
echo "*                                 *"
echo "*                                 *"
echo "***********************************"
echo $(date)
# Enter your tape copy/sync lines here



# Below is a sample script I use to back up incremental tarballs of custom directories to multiple tapes.
# For each tape, it automatically detects the source directories as well as the last incremental snapshot
# as they are saved on the tape.
# As long as the tapes are properly initialized, you can put any tape in the drive, and the script will
# write a new incremental tarball of the relevant folders to tape. You can have different tapes with
# different source backup folders, or different increments. No manual entry or selection is necessary.

# How it works:
# Tapes will contain pairs of tarballs for each incremental backup. The first file of the pair (even
# numbered ones starting from 0) is the incremental tarball of the source directories. The second of the
# pair contains the last tar snapshot as well as a list of source directories. The second tarball contains
# the state info necessary to generate the next incremental backup.

# How to initialize a tape:
# 1. Exec into the container via `docker exec -it tape bash`
# 2. Change directory to /config `cd /config`
# 3. Rewind the tape via `mt -f /dev/nst0 rewind`
# 4. Create a directories.txt file containing the source folders and any custom tar options, in a single
#    line and no trailing newline:
#    `printf -- '-C /mnt/backups backup1 backup2' > directories.txt`
# 5. Write the initial backup to tape (this will destroy all info on the tape):
#    `tar -cvf /dev/nst0 --listed-incremental=tapeA1.snar $(cat directories.txt)`
#    Make sure the snapshot filename is in the format of `tapeXX.snar` where X can be any letter or number.
# 6. Fix the new file perms (just in case):
#    `chown abc:abc directories.txt tapeA1.snar`
# 7. Write the index files to tape:
#    `tar -cvf /dev/nst0 tapeA1.snar directories.txt`
# 8. Delete the local index files via `rm tapeA1.snar directories.txt`
#    Now you should have a tape initialized with `file 0` containing the tarball of your source directories
#    and `file 1` containing the tar snapshot and the directories.txt file. When the following script is
#    run, it will first retrieve these index files, use them to generate a new incremental tar and write
#    the pair to tape. 

# ***** Start of Script
# check for active tape by seeking to end of data and checking the files at the last file
cd /config
if [ -f "directories.txt" ] || find . -name "tape*.snar" | grep -q .; then
    echo "Existing index files present, quitting"
    exit 0
fi
mt -f /dev/nst0 eod || ( echo "Can't seek to eod, quitting" && exit 0 )
mt -f /dev/nst0 bsfm 2 || ( echo "Can't read the last written file from tape, quitting" && exit 0 )
if tar tvf /dev/nst0 | grep -q 'directories.txt'; then
    echo "Found the directories list, will read snapshot file and directories from tape"
else
    echo "Can't find the directories list, quitting"
    exit 0
fi
# extract the index files from last backup
mt -f /dev/nst0 bsfm 1
tar xvf /dev/nst0
if [ -f "directories.txt" ] && find . -name "tape*.snar" | grep -q .; then
    DIRECTORIES=$(cat directories.txt)
    echo "Retrieved directories content: ${DIRECTORIES}"
    TAPE_NUMBER=$(find . -name "tape*.snar" | sed 's|\./tape||' | sed 's|.snar||')
    echo "Retrieved tape number: ${TAPE_NUMBER}"
    chown abc:abc directories.txt "tape${TAPE_NUMBER}.snar"
else
    echo "Can't find the index files, quitting"
    exit 0
fi
# seek to beginning of next file
mt -f /dev/nst0 fsf 1
echo "Writing incremental tar to tape:"
tar -cvf /dev/nst0 --listed-incremental="tape${TAPE_NUMBER}.snar" ${DIRECTORIES}
echo "Writing index files to tape:"
tar -cvf /dev/nst0 "tape${TAPE_NUMBER}.snar" directories.txt
# delete local index files
rm "tape${TAPE_NUMBER}.snar" directories.txt
# ***** End of Script


# In order to restore, one can use the following commands to extract all the tarballs in sequence:
# docker exec -it tape bash
# cd /config
# for i in {0..100000}; do mt -f /dev/nst0 asf "${i}"; echo "**** extracting file ${i}"; if ! tar xvf /dev/nst0 --listed-incremental=/dev/null; then echo "last file detected, quitting"; break; fi; done
