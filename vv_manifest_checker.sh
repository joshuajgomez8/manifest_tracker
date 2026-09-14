#!/bin/bash
#
# Script to check if a vendor/volvocars revision is available in a manifest revision
#
GREEN='\033[01;32m'
ORANGE='\033[1;91m'
BOLD='\033[1m'
NC='\033[0m' # No Color
ERROR="${ORANGE}E:${NC}"

help="\nUsage:
vv_manifest_checker.sh <gerrit username> --uxc[--dhu|--ihu42] <manifest revision> <vendor/volvocars revision>

eg: vv_manifest_checker.sh username --uxc 9d46924115000729d5e1ebbd576491f8e09f81c8 c24585e

This tool will help check if a vendor/volvocars revision is available in a manifest revision."

gerrit_username=$1
platform=$2
manifest_revision=$3
vv_revision_to_check=$4
app_name=vendor/volvocars
no_of_commits_to_display=5

[ -z "$gerrit_username" ] && { echo -e "$help" >&2; exit 1; }
[ -z "$manifest_revision" ] && { echo -e "$help" >&2; exit 1; }
[ -z "$vv_revision_to_check" ] && { echo -e "$help" >&2; exit 1; }

if [ "$platform" = "--uxc" ]; then
    manifest_sub_file="volvocars-android-common.xml"
    manifest_name="manifest_uxc10"
elif [ "$platform" = "--dhu" ]; then
    manifest_sub_file="volvocars-android.xml"
    manifest_name="manifest_ihu5"
elif [ "$platform" = "--ihu42" ]; then
    manifest_sub_file="manifest-volvocars-tiramisu.xml"
    manifest_name="manifest_ihu42"
else
    echo -e "$ERROR Invalid platform '$platform'. Use --uxc, --dhu or --ihu42"
    echo -e "$help" >&2; exit 1;
fi

cd /tmp || exit
working_folder=vv_manifest_checker
rm -rf $working_folder
mkdir $working_folder
cd $working_folder || exit

print_status() {
    	local pid=$!
    	local text=$1
    	local spinner="/-\\|"
    	local i=0
    	while kill -0 $pid 2>/dev/null; do
        	i=$(( (i+1) % 4 ))
        	printf "\r$text ${spinner:$i:1}"
        	sleep 0.1
    	done
    	printf "\r$text  \n"
}

checkout_manifest() {
	[ -z "$manifest_revision" ] && { echo Error in checkout_manifest: Missing manifest_revision >&2; exit 1; }

  	echo -e "Cloning$BOLD $manifest_name $NC"
  	GIT_TERMINAL_PROMPT=0 git clone -q --depth 1 "https://$gerrit_username@artinfo-gerrit.volvocars.biz/a/$manifest_name"
  	[ $? -ne 0 ]  && exit 1;

	cd $manifest_name || exit
	(git fetch -q --depth 1 origin "$manifest_revision") &
	print_status "Checking out$BOLD $manifest_name $NC$manifest_revision"

	git checkout -q "$manifest_revision"
	[ $? -ne 0 ]  && { echo -e "$ERROR" Cannot find revision "$manifest_revision" in "$manifest_name" >&2; exit 1; }

	vv_revision=$(grep -w \"$app_name\" $manifest_sub_file | sed -n 's/.*revision="\([^"]*\)".*/\1/p')
	[ -z "$vv_revision" ] && { echo -e "$ERROR Could not find$BOLD $app_name$NC revision in $manifest_name/$manifest_sub_file" >&2; exit 1; }
	echo -e "Last revision of$BOLD vendor/volvocars$NC in $BOLD$manifest_name/$manifest_sub_file$NC is $vv_revision"
}

checkout_vv() {
	(git clone -q --bare --filter=blob:none "https://$gerrit_username@artinfo-gerrit.volvocars.biz/a/$app_name") &
	print_status "Cloning$BOLD $app_name $NC"
	[ $? -ne 0 ]  && exit 1;
	cd volvocars.git || exit

	if (git merge-base --is-ancestor $vv_revision_to_check $vv_revision); then
    	echo -e "${GREEN}Yes$NC$BOLD vendor/volvocars$NC [$vv_revision_to_check] is available in$BOLD $manifest_name$NC [$manifest_revision]" 
	else
    	echo -e "${ORANGE}No$NC$BOLD vendor/volvocars$NC [$vv_revision_to_check] is not available in$BOLD $manifest_name$NC [$manifest_revision]"
	fi
}

checkout_manifest
checkout_vv

cd /tmp || exit
rm -rf $working_folder
