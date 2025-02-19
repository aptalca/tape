# Docker container for managing tape (lto) drives

Includes `mt-st` package which provides the `mt` command for interfacing with tape drives, as well as gnu `tar`.

Also includes cron for scheduling tape backups and restores. Crontab is included in the `/config` folder and changes require a container restart.

## Requirements:

- Needs the tape devices mounted (ie. `--device /dev/st0 --device /dev/nst0`)
- Needs a bind mount for the `/config` folder
- Add optional bind mounts for the paths you'd like to copy from and to

## Usage:

Basic facts about tapes and how they are operated with `mt` and `tar`:

- Tape drives are for sequential reading and writing. Each tar file is written and appended with an `EOF` marker that defines the end of the file.
- Tape drives can easily and relatively quickly identify the EOF files to determine the beginning and end of each file.
- Writing and reading operations always begin on where the drive head currently is. Pay close attention to that prior to each operation.
- `/dev/st0` is a rewinding device. After each operation, the tape is rewound to the beginning. `/dev/nst0` is non-rewinding and the head remains at its location at the end of each operation.
- `mt -f /dev/nst0 status` will show the status of the drive head. If it's at a file (vs a block), it will list the `File number`. If it's at the beginning of a file, it will list `EOF` at the bottom (except for the first file, which is really called `File number=0`, which will show `BOT` indicating the `beginning of tape`).
- You can seek to the beginning via `mt -f /dev/nst0 rewind` or `mt -f /dev/nst0 asf 0`
- You can seek to the beginning of any file via `mt -f /dev/nst0 asf X`with `X` being the file number (starting from `0`)

### Writing to tape:

- For the first write, make sure to rewind via `mt -f /dev/nst0 rewind` and confirm with `status`.
- With tar, you can write directly to the tape via `tar -cvf /dev/nst0 sourcedirectory1 sourcedirectory2`.
- If you used the non-rewinding `nst0` device, the drive head should be at the beginning of the second file, indicated by `File number=1` and `EOF` in `status` output.
- To write the second file, make sure the `status` shows `File number=1` and `EOF`.
- Same command, `tar -cvf /dev/nst0 sourcedirectory1 sourcedirectory2`, will now write the second tar file and the head should move to `File number=2`.
- If you overwrite the first file, all subsequent files will be lost. Pay attention to where the head is before each write operation. You can use `mt` to forward to the end of the tape to be sure.
- For long operations run manually via cli, you can use `screen` so you don't have to keep a shell open.

### Reading from tape:

- You can seek to the beginning of files with the command `mt -f /dev/nst0 asf X` with X being the file number (starting with 0).
- To copy the first file from tape to the current folder on the local machine, rewind via `mt -f /dev/nst0 rewind` (or via `mt -f /dev/nst0 asf 0`).
- Use the tar command to extract from tape: `tar -xvf /dev/nst0`. It will read the first file all the way to the EOF, and extract it to the local disk.
- To copy the second file from tape, seek to it via `mt -f /dev/nst0 asf 1` and extract via `tar -xvf /dev/nst0`.
- For long operations run manually via cli, you can use `screen` so you don't have to keep a shell open.

There are plenty more `mt` commands and arguments listed on its manpage: https://linux.die.net/man/1/mt

## Important Notice:

Never do `mt -f /dev/nst0 erase` unless you know it's really what you want. The manpage is not clear about it, but it actually does a `secure erase`, it takes a really long time (8+ hrs) and you can't cancel it once started. Killing or force killing the process doesn't work, `docker stop` and `docker kill` fail. The only way is to cut the power to the drive, which could damage the drive head.
