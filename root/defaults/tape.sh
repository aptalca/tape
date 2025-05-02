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
# 1. Exec into the running container and run the init script: `docker exec -it tape /config/tape.sh init`
# 2. Enter the necessary information requested
#    Now you should have a tape initialized with `file 0` containing the tarball of your source directories
#    and `file 1` containing the tar snapshot and the directories.txt file. When the following script is
#    run, it will first retrieve these index files, use them to generate a new incremental tar and write
#    the pair to tape. 

# How to do a backup:
# 1. Run this script manually or via cron with no arguments

# How to do a restore:
# 1. Exec into the running container and run the restore script: `docker exec -it tape /config/tape.sh restore`
# 2. Enter the necessary information requested

# ***** Start of Script
fn_init () {
    echo 'Please input a tape name/number. Only letters and numbers, no special characters (ie. A1):'
    read TAPE_NUMBER
    echo 'Please list the directories to be backed up in a single line, separated by spaces. You can include custom tar arguments such as -C folder (ie. `-C /mnt/backups photos media`):'
    read DIRECTORIES
    echo "Tape name/number selected is ${TAPE_NUMBER}"
    echo "Directories listed are ${DIRECTORIES}"
    echo 'This action will destroy all data on tape. Please confirm the above info and type Yes to proceed:'
    read CONFIRMATION
    if [ "${CONFIRMATION}" = "Yes" ]; then
        echo "**** Rewinding tape"
        cd /config
        mt -f /dev/nst0 rewind
        echo "**** Writing data to tape"
        tar -cvf /dev/nst0 --listed-incremental="tape${TAPE_NUMBER}.snar" ${DIRECTORIES}
        printf "%s" "${DIRECTORIES}" > "directories${TAPE_NUMBER}.txt"
        echo "**** Writing index files to tape"
        tar -cvf /dev/nst0 "tape${TAPE_NUMBER}.snar" "directories${TAPE_NUMBER}.txt"
        rm "tape${TAPE_NUMBER}.snar" "directories${TAPE_NUMBER}.txt"
        echo "**** Tape initialization completed!"
    else
        echo "No action taken, aborting!"
    fi
}

fn_backup () {
    cd /config
    if find . -name "directories*.txt" | grep -q . || find . -name "tape*.snar" | grep -q .; then
        echo "Existing index files present, quitting"
        exit 0
    fi
    # check for active tape by seeking to end of data and checking the files at the last file
    mt -f /dev/nst0 eod || ( echo "Can't seek to eod, quitting" && exit 0 )
    mt -f /dev/nst0 bsfm 2 || ( echo "Can't read the last written file from tape, quitting" && exit 0 )
    if tar tvf /dev/nst0 | grep -q "directories.*.txt"; then
        echo "Found the directories list, will read snapshot file and directories from tape"
    else
        echo "Can't find the directories list, quitting"
        exit 0
    fi
    # extract the index files from last backup
    mt -f /dev/nst0 bsfm 1
    tar xvf /dev/nst0
    if find . -name "directories*.txt" | grep -q . && find . -name "tape*.snar" | grep -q .; then
        TAPE_NUMBER=$(find . -name "tape*.snar" | sed 's|\./tape||' | sed 's|.snar||')
        echo "Retrieved tape number: ${TAPE_NUMBER}"
        DIRECTORIES=$(cat "directories${TAPE_NUMBER}.txt")
        echo "Retrieved directories content: ${DIRECTORIES}"
        chown abc:abc "directories${TAPE_NUMBER}.txt" "tape${TAPE_NUMBER}.snar"
    else
        echo "Can't find the index files, quitting"
        exit 0
    fi
    # seek to beginning of next file
    mt -f /dev/nst0 fsf 1
    echo "Writing incremental tar to tape:"
    tar -cvf /dev/nst0 --listed-incremental="tape${TAPE_NUMBER}.snar" ${DIRECTORIES}
    echo "Writing index files to tape:"
    tar -cvf /dev/nst0 "tape${TAPE_NUMBER}.snar" "directories${TAPE_NUMBER}.txt"
    # delete local index files
    rm "tape${TAPE_NUMBER}.snar" "directories${TAPE_NUMBER}.txt"
}

fn_restore () {
    cd /config
    echo "Enter the folder path you'd like to extract the archives to (leave blank for default /config):"
    read BASE_FOLDER
    BASE_FOLDER="${BASE_FOLDER:-/config}"
    for i in {0..100000}; do
        mt -f /dev/nst0 asf "${i}"
        echo "**** extracting file ${i}"
        if ! tar xvf /dev/nst0 --listed-incremental=/dev/null -C ${BASE_FOLDER}; then
            echo "last file detected, quitting"
            break
        fi
    done
}

case "$1" in
    "init")
        fn_init
        ;;
    "restore")
        fn_restore
        ;;
    "backup"|"")
        fn_backup
        ;;
    "*")
        echo "**** Unrecognized option, aborting"
        ;;
esac

# ***** End of Script
