#!/usr/bin/env python3
#
# Copyright 2022 NIXIME@GITHUB
#
from os import listdir
from os.path import isfile, join
from datetime import date
import tempfile
import subprocess
import os
import shutil

def relocate_merged_files(recycle_folder_path, config_file):
    print('Starting Merged File Relocation')
    try:
        if not os.path.exists(recycle_folder_path):
            os.mkdir(recycle_folder_path)
    except OSError as error:
        print(error)

    with open(config_file, 'r') as f:
        lines = f.readlines()
        for l in lines:
            _, name = l.partition(" ")[::2]
            name = name.replace("'","").strip()
            # Handle the comments and what not. If not a filename skip it.
            if os.path.exists(name):
                nname = join(recycle_folder_path, os.path.basename(name))
                print(f'Moving {name} to {nname}')
                shutil.move(name, nname)
            else:
                print(f'Bad Line |{l}')

        f.close()
    return


def merge_mkv_files(wipfolder, day, config_file):
    print('Starting FFMPEG Merging')
    fnl_name = join(wipfolder,'..',day+'.mkv')

    if os.path.exists(fnl_name):
        print(f'Error, File already exists {fnl_name}')
    else:
        ffmpeg = "/usr/bin/ffmpeg"
        cmdargs = [
            ffmpeg,
            '-loglevel', 'verbose',
            '-f', 'concat',
            '-safe', '0',
            '-i', config_file,
            '-c', 'copy',
            fnl_name
        ]
        print(cmdargs)

        p = subprocess.run(cmdargs,capture_output=True) 
        if p.returncode == 0:
            print ("FFmpeg Script Ran Successfully")
            relocate_merged_files(join(wipfolder,'..','merged'), config_file)
        else:
            print("There was an error running your FFmpeg script")
            print(p.stderr)
            print(p.stdout)


def process_single_day(wipfolder, day):
    print(f'Starting Single Day Process {day}')
    mkvfiles = [f for f in listdir(wipfolder) if isfile(join(wipfolder, f)) and f.startswith(day)]
    fd, path = tempfile.mkstemp()
    try:
        with os.fdopen(fd, 'w') as tfp:
            tfp.write(f"# Date : {day}\n")
            for mkv in mkvfiles:
                #TBD: Make sure the MKV is not open by the process, such that it is from prior day but still being appended to
                #     hasn't rolled over yet.
                tfp.write(f"file '{join(wipfolder,mkv)}'\n")
            tfp.flush()
            tfp.close()

            merge_mkv_files(wipfolder, day, path)
    finally:
        os.remove(path)


def process_full_wip_folder(wipfolder):
    print('Processing Entire WIP folder')
    # Get today's date
    today = date.today()
    exclude_date = today.strftime("%Y%m%d")
    # Find all MKV files that are not from today's date
    mkvfiles = [f for f in listdir(wipfolder) if isfile(join(wipfolder, f)) and not f.startswith(exclude_date)]
    processed = []
    for mkv in mkvfiles:
        tokens=mkv.split('_')
        day_filter=tokens[0]
        # Only process the day once, even if multiple files
        # exist in the original list.
        if not day_filter in processed:
            processed.append(day_filter)
            process_single_day(wipfolder, day_filter)


#
# Read NIXDVR configuration file
#
cfg_file='/etc/nixdvr.cfg'
cfg_data={}
with open(cfg_file) as f:
    lines = f.readlines()
    for l in lines:
        name, var = l.partition("=")[::2]
        cfg_data[name.strip().lower()] = var.strip()
    f.close()

#
# Gather a list of all cameras to process. Camera names are the names of the config
# files.
#
camera_files = [f for f in listdir(cfg_data['configdir']) if isfile(join(cfg_data['configdir'], f))]

#
# Begin processing files
basedir=cfg_data['storagedir']
for camera in camera_files:
    #
    # Pull out the stream name of the camera
    camera_cfg={}
    with open(join(cfg_data['configdir'],camera)) as f:
        lines = f.readlines()
        for l in lines:
            name, var = l.partition("=")[::2]
            camera_cfg[name.strip().lower()] = var.strip()
        f.close()

    # Create string to temporary processing path
    tempfolder=join(basedir,camera_cfg["stream_name"].lower(),'_')
    process_full_wip_folder(tempfolder)
