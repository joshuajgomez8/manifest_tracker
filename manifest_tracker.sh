#!/bin/bash
#
# Script to find last 5 commits of a vendor/volvocars/vehiclefunctions/apps repo available in a manifest revision
#
GREEN='\033[01;32m'
ORANGE='\033[1;91m'
BOLD='\033[1m'
NC='\033[0m' # No Color
ERROR="${ORANGE}E:${NC}"

help="\nUsage:
manifest_tracker.sh <gerrit username> --uxc[--dhu|--ihu42] <app name> <manifest revision>

eg: manifest_tracker.sh username --uxc QuickControls fed4fee564ef311501e849a5790ce2966c336165

This tool will help find last 5 commits of an app repo available in a manifest revision.
Works with projects having source code in$BOLD https://artinfo-gerrit.volvocars.biz/plugins/gitiles/vendor/volvocars/vehiclefunctions/apps/$NC
and prebuilts in$BOLD https://artinfo-gerrit.volvocars.biz/plugins/gitiles/vendor/volvocars/prebuilts/$NC"

gerrit_username=$1
platform=$2
app_name=$3
manifest_revision=$4
no_of_commits_to_display=5

[ -z "$gerrit_username" ] && { echo -e "$help" >&2; exit 1; }
[ -z "$app_name" ] && { echo -e "$help" >&2; exit 1; }
[ -z "$manifest_revision" ] && { echo -e "$help" >&2; exit 1; }

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
working_folder=manifest_tracker
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

	prebuilt_apk_revision=$(grep -w ''$app_name'' $manifest_sub_file | sed -n 's/.*revision="\([^"]*\)".*/\1/p')
	[ -z "$prebuilt_apk_revision" ] && { echo -e "$ERROR Could not find$BOLD prebuilts/$app_name$NC revision in $manifest_name/$manifest_sub_file" >&2; exit 1; }
}

checkout_prebuilt() {
	echo -e "Cloning$BOLD prebuilts/$app_name $NC"
	git clone -q --bare --filter=blob:none --depth 1 "https://$gerrit_username@artinfo-gerrit.volvocars.biz/a/vendor/volvocars/prebuilts/$app_name"

	cd "$app_name".git || exit
	echo -e "Checking out$BOLD prebuilts/$app_name $NC$prebuilt_apk_revision"
	git fetch -q --depth 1 origin "$prebuilt_apk_revision"
	[ $? -ne 0 ]  && exit 1;

	commit_message=$(git show -s --format=%B "$prebuilt_apk_revision")
	[ -z "$commit_message" ] && { echo -e "\nE: Could not find $prebuilt_apk_revision in prebuilts/$app_name git log" >&2; exit 1; }
	app_version=$(echo "$commit_message" | grep -oP 'Commit: \K[0-9a-f]+')
	if [ -z "$app_version" ]; then
		echo -e "$ORANGE"W:"$NC" Could not find commit-id of "$BOLD"apps/"$app_name""$NC" from commit message of "$BOLD"prebuilts/"$app_name""$NC"
		echo -e "$ORANGE"W:"$NC" Expected commit-id in format "'Commit: xxxxxx'"
		echo -e "$GREEN"Last commit from prebuilts/"$app_name""$NC"
		echo -e ---------------------------------------------------
		echo -e "$commit_message"
		echo -e ---------------------------------------------------
		exit 1;
	fi
}

checkout_apps() {
	echo -e "Cloning$BOLD apps/$app_name $NC"
	git clone -q --bare --filter=blob:none "https://$gerrit_username@artinfo-gerrit.volvocars.biz/a/vendor/volvocars/vehiclefunctions/apps/$app_name"

	cd "$app_name".git || exit
	echo -e "$GREEN""Last $no_of_commits_to_display commits in apps/$app_name:$NC"
	git log --oneline -$no_of_commits_to_display "$app_version"
}

checkout_manifest
checkout_prebuilt
checkout_apps

cd /tmp || exit
rm -rf $working_folder
