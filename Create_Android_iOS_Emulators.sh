#!/bin/bash

#########################################################
# 																											#
#	Use this Script in Jenkins														#
#                                                       #
#########################################################

WORKSPACE=${PWD}

# Carregando script para tratar o output das mensagens
source ${WORKSPACE}/util.sh

EMULATOR_LIST="${WORKSPACE}/.emulator_list"
AVD_PIDS="${WORKSPACE}/.avd_pids"
AVD_NAMES="${WORKSPACE}/.avd_names"
AVD_MANAGER="${ANDROID_HOME}/tools/bin/avdmanager"
SDK_MANAGER="${ANDROID_HOME}/tools/bin/sdkmanager"
ANDROID_EMULATOR="${ANDROID_HOME}/emulator/emulator"
echo "" > ${EMULATOR_LIST}
echo "" > ${AVD_PIDS}
echo "" > ${AVD_NAMES}

function emulator_list {
	cat ${EMULATOR_LIST}
}
function avd_pids {
	cat ${AVD_PIDS}
}

function avd_names {
	cat ${AVD_NAMES}
}

function verify_bash_profile() {
  if cat ~/.bash_profile >& /dev/null; then
    alerta b "O arquivo bash_profile ja está criado!!"
  else
    alerta r "Não foi encontrado um arquivo bash_profile, criando..."
    touch ~/.bash_profile
  fi
}

function verify_android_home() {
  if [ -n "$ANDROID_HOME" ]; then
    alerta b "A variável ANDROID_HOME ja está setada!!"
  else
    alerta r "A variável ANDROID_HOME não foi encontrada, criando..."
    echo "export ANDROID_HOME=/Users/\$USER/Library/Android/sdk" >> ~/.bash_profile
    echo "export PATH=\$ANDROID_HOME/platform-tools:\$PATH" >> ~/.bash_profile
    echo "export PATH=\$ANDROID_HOME/tools:\$PATH" >> ~/.bash_profile
    source ~/.bash_profile
  fi
}

function verify_job_name() {
  if [ -n "$JOB_NAME" ]; then
    alerta b "O Nome deste JOB é: $JOB_NAME"
  else
    alerta r "Não existe uma varivável JOB_NAME, criando..."
    JOB_NAME="AVDTesting"
    alerta b "A Variável criada foi: $JOB_NAME"
  fi
}

function verify_build_number() {
  if [ -n "$BUILD_NUMBER" ]; then
    alerta b "O Número deste Build é: $BUILD_NUMBER"
  else
    alerta r "Não existe uma varivável BUILD_NUMBER, criando..."
    BUILD_NUMBER="123456"
    alerta b "A Variável criada foi: $BUILD_NUMBER"
  fi
}

#### Android ####

# This function varify if an Android IMG is valid
# Example: get_api_img android-23
function get_api_img() {
	local verify='^android-[0-9][0-9]$'
	if [ -z $1 ] || [[ ! $1 =~ $verify ]]; then
		alerta r "This function requires a valid Android API version as parameter, example: android-23"
		return 1
	fi
	AVD_PATH=`${SDK_MANAGER} --list --verbose | grep "system-images;$1;google_apis;x86" | head -n 1`
	if [ -z ${AVD_PATH} ]; then
		alerta r "There isn't a valid IMG for this API version!"
		list_available_api_images
		alerta r "\nTo download a new API Image, execute: download_api_img android-23"
    return 1
	fi
}

# This function download an valid Android IMG
# Example: download_api_img android-23
function download_api_img() {
	alerta b "Downloading the Image $1"
	${SDK_MANAGER} "platforms;$1"
}

# This function removes a installed Android Image
# Example: uninstall_api_img android-23
function uninstall_api_img() {
	alerta b "Removing the Image $1"
	${SDK_MANAGER} --uninstall "platforms;$1"
}

# This function list all Available Android Images to download
function list_available_api_images() {
	alerta b "\nThe Available Images API's to download are: "
	${SDK_MANAGER} --list --verbose | grep "^system-images;.*;google_apis;x86$" | sort -u | sed -e 's/^.*system-images;//' | awk -F ';' '{print $1}'
}

# This function List all Installed Packages of Android
function list_all_installed_packages() {
	alerta b "The Installed SDK Packages are:"
	find $ANDROID_HOME -name package.xml -exec sh -c 'eval $(xmllint --xpath "//*[local-name()='\'localPackage\'']/@path" $0) && echo $path' {} \;
}

# This function List all Installed Android Images
function list_installed_images() {
	alerta b "The Installed Images are:"
	find $ANDROID_HOME -name package.xml | grep ".*system-images" | sed -e 's/^.*system-images\///' | awk -F '\/' '{print $1}'
}

function launch_avd {
	usage="$(basename "$0") [-h] [--sdcard]
	Onde:
	-h  Exibe este texto de ajuda
	--schema  Recebe tamanho em MB do sdcard
	"
	while getopts "$optspec" option; do
		case "$option" in
			h)  echo "$usage"
			return 1
			;;
			-)
			case "${OPTARG}" in
				sdcard) check_argumento
				sdcard="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
				;;
				\?)
				alerta r "variavel longa não encontrada"
				if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
					alerta r "Unknown option --${OPTARG}" >&2
				fi
			esac
		esac
	done

	if [ -z "${1}" ]
	then
		echo -e "\n\033[31;1mUsage: ${0} avds_file";
		echo $"\tavds_name:\tA avd_name must exist and cannot run for two or more process in same time";
		return 0
	fi

	if [[ -n "${sdcard}" ]]
	then
		mksdcard ${sdcard}M ${WORKSPACE}/${JOB_NAME}-${BUILD_NUMBER}.img \
		${ANDROID_EMULATOR} \
		-wipe-data -gpu on \
		-no-boot-anim -accel on -avd "${1}" -sdcard ${WORKSPACE}/${JOB_NAME}-${BUILD_NUMBER}.img -qemu -m 1024 &
	else
		${ANDROID_EMULATOR} \
		-wipe-data -gpu on \
		-no-boot-anim -accel on -avd "${1}" -qemu -m 1024 &
	fi

	echo ${!} >> ${AVD_PIDS}
}

# This function receives an archive as parameter with one or more Android API inside
# This function allow only one API per line in the archive
# Example: create_avd_from_file avd.txt
function create_avd_from_file {
	if [ -z "${1}" ] || [ ! -f "${1}" ]
	then
		echo -e "\n\033[31;1mUsage: ${0} avds_file";
		echo $"\tavds_file:\tA text file with one avd name per line";
		return 1
	fi
	IDX=0
	IFS=$'\n'
	for avd in `cat $1`
	do
		local AVD_NAME="${JOB_NAME}-${BUILD_NUMBER}-${IDX}"
		get_api_img "${avd}"
		echo "" | ${AVD_MANAGER} create avd -f -n ${AVD_NAME} -k "${AVD_PATH}" || true
		launch_avd ${AVD_NAME}
		echo ${AVD_NAME} >> ${AVD_NAMES}
		IDX=$((IDX+1))
	done
	unset IFS
}

# This function receives an Android API as parameter and start an AVD with the
# SDK selected
# Example: create_avd android-23
function create_avd() {
	verify_bash_profile
	verify_android_home
	verify_job_name
	verify_build_number
	if get_api_img "${1}"; then
	local AVD_NAME="${JOB_NAME}"
	echo "" | ${AVD_MANAGER} create avd -f -n ${AVD_NAME} -k "${AVD_PATH}" || true
	launch_avd ${AVD_NAME}
	echo ${AVD_NAME} >> ${AVD_NAMES}
	else
		return 1
	fi
}

# This function wait for the TOTAL Launch of the Emulator
function wait_for_avd_boot {
	IDX=0
	sleep 60
	for porta in `adb devices | grep emulator | cut -d'-' -f2 | awk '{ print $1 }'`
	do
		if echo `cat ${AVD_PIDS}` | grep -q `lsof -n -i4TCP:${porta} | awk '{ print $2 }' | tail -n +2`
		then
			echo "emulator-${porta}" >> ${EMULATOR_LIST}
			adb -s "emulator-${porta}" wait-for-device
			adb -s "emulator-${porta}" shell 'while [ ""`getprop dev.bootcomplete` != "1" ] ; do sleep 1; done'
		fi
	done
}

# This function kill`s all Started Android Emulator`s
function finish_avds {
	for emulator in `emulator_list`
	do
		if adb devices | grep -q ${emulator}
		then
			adb -s ${emulator} emu kill &
			sleep 60
		fi
	done
	for pid in `avd_pids`; do  kill -9 ${pid} || true; done
	for avd in `avd_names`; do ${AVD_MANAGER} delete avd -n ${avd}; done
	rm -rf .avd_names .avd_pids .emulator_list
}



#### iOS ####

# List the available simulators
function list_available_simulators() {
  alerta b "The Available simulators are: "
  AVAILABLE_SIMULATORS=$(xcrun simctl list devices | grep "iPhone") | awk '{print $1 $2 $3}'
  alerta b "${AVAILABLE_SIMULATORS}"
}

# Capture iPhone ID
# Ex: 5, 5s, 6, 6s
function iPhone_ID() {
  SIMULATOR_ID=`xcrun simctl list devices \
    | grep "iPhone "${1}"" \
    | head -n 1 \
    | awk {'print $3'} \
    | sed -e "s|(*|| ; s|(*)||"`
}

# Capture iPhone Plus ID
# Ex: 6 Plus, 6s Plus, 7 Plus
function iPhone_ID_Plus() {
  SIMULATOR_ID=`xcrun simctl list devices \
    | grep "iPhone $1 $2" \
    | tail -n 1 \
    | awk {'print $4'} \
    | sed -e "s|(*|| ; s|(*)||"`
}

# Check if there is compatiple simulators
function check_simulator() {
  if [ -z "$SIMULATOR_ID" ]; then
    alerta r "Não foram encontrados emuladores compatíveis!"
    return 1
  fi
}

# Launch the Simulator
function launch_simulator() {
  alerta b "Iniciando Emulador"
  open -n /Applications/Xcode.app/Contents/Developer/Applications/Simulator.app \
      --args \
      -CurrentDeviceUDID $SIMULATOR_ID
}

# Start the Correct Simulator
function start_simulator() {
  if [ -z "${1}" ]; then
    alerta r "É necessário uma entrada. Exemplo: 6s"
    return 1
  elif [ -z "${2}" ]; then
    iPhone_ID ${1}
    if check_simulator; then
    launch_simulator
    else
      return 1
    fi
  else
    iPhone_ID_Plus ${1} ${2}
    if check_simulator; then
    launch_simulator
    else
      return 1
    fi
  fi
}

# Reset all iOS Simulators
function reset_all_ios_simulators {
	xcrun simctl list devices |
	grep -v '^[-=]' |
	grep -v 'Shutdown' |
	cut -d "(" -f2 |
	cut -d ")" -f1 |
	xargs -I {} sh -c 'xcrun simctl shutdown "{}"; xcrun simctl erase "{}";'
}

# Unlock Keychain
function unlock_keychain {
	security -v unlock-keychain -p "" ""
}
