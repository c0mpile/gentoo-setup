#!/usr/bin/env bash

# unset variables
unset target_disk,target_part1,target_part2,subvol_options,current_stage3

# target installation drive
read -p 'Enter the installation target device name: ' target_disk

if [[ $(echo $target_disk | grep dev) =~ nvme ]]; then
        export target_part1="${target_disk}p1"
        export target_part2="${target_disk}p2"
elif [[ $(echo $target_disk | grep dev) =~ sd ]]; then
        export target_part1="${target_disk}1"
        export target_part2="${target_disk}2"
elif [[ $(echo $target_disk | grep dev) =~ hd ]]; then
        export target_part1="${target_disk}1"
        export target_part2="${target_disk}2"
elif [[ $(echo $target_disk | grep dev) =~ vd ]]; then
        export target_part1="${target_disk}1"
        export target_part2="${target_disk}2"
fi

echo $target_disk
echo $target_part1
echo $target_part2
