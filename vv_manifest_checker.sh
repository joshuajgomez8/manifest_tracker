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

checkout_manifest() {
  	echo -e "Cloning$BOLD $manifest_name $NC"
  	GIT_TERMINAL_PROMPT=0 git clone -q --depth 1 "https://$gerrit_username@artinfo-gerrit.volvocars.biz/a/$manifest_name"
  	[ $? -ne 0 ]  && exit 1;

	cd $manifest_name || exit
	echo -e "Checking out$BOLD $manifest_name $NC$manifest_revision"
	git fetch -q --depth 1 origin "$manifest_revision" > /dev/null 2>&1 && git checkout -q "$manifest_revision"
	[ $? -ne 0 ]  && { echo -e "$ERROR" Cannot find revision "$manifest_revision" in "$manifest_name" >&2; exit 1; }

	vv_revision=$(grep -w \"$app_name\" $manifest_sub_file | sed -n 's/.*revision="\([^"]*\)".*/\1/p')
	[ -z "$vv_revision" ] && { echo -e "$ERROR Could not find$BOLD $app_name$NC revision in $manifest_name/$manifest_sub_file" >&2; exit 1; }
	echo -e "Last revision of$BOLD vendor/volvocars$NC in $BOLD$manifest_name/$manifest_sub_file$NC is $vv_revision"
}

checkout_vv() {
	echo -e "Cloning$BOLD $app_name $NC"
	git clone -q --bare --filter=blob:none "https://$gerrit_username@artinfo-gerrit.volvocars.biz/a/$app_name"
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
