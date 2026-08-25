#!/bin/bash
##################################################################
# Script       # check_etcd_version.sh
# Description  # Retreive the ETCD version for the RHOCP releases
# @VERSION     # 0.1.2
##################################################################
# Changelog.md # List the modifications in the script.
# README.md    # Describes the repository usage
##################################################################

#### Functions
fct_help(){
  Script=$(which "$0" 2>"${STD_ERR}")
  if [[ "${Script}" != "bash" ]] && [[ ! -z ${Script} ]]
  then
    ScriptName=$(basename "$0")
  fi
  echo -e "usage: ${cyantext}${ScriptName} -r <release> | -m <minor_version> [-p <pull-secret>] [-a <Arch>] [-kcy] ${purpletext}[-h]${resetcolor}"
  OPTION_TAB=8
  DESCR_TAB=63
  DEFAULTS_TAB=31
  printf "|%${OPTION_TAB}s---%-${DESCR_TAB}s---%-${DEFAULTS_TAB}s|\n" |tr \  '-'
  printf "|%${OPTION_TAB}s | %-${DESCR_TAB}s | %-${DEFAULTS_TAB}s|\n" "Options" "Description" "[Defaults]"
  printf "|%${OPTION_TAB}s | %-${DESCR_TAB}s | %-${DEFAULTS_TAB}s|\n" |tr \  '-'
  printf "|${cyantext}%${OPTION_TAB}s${resetcolor} | %-${DESCR_TAB}s | ${greentext}%-${DEFAULTS_TAB}s${resetcolor}|\n" "-r" "List of release version(s) to check" ""
  printf "|${cyantext}%${OPTION_TAB}s${resetcolor} | %-${DESCR_TAB}s | ${greentext}%-${DEFAULTS_TAB}s${resetcolor}|\n" "-m" "List of minor version(s) to check" ""
  printf "|${cyantext}%${OPTION_TAB}s${resetcolor} | %-${DESCR_TAB}s | ${greentext}%-${DEFAULTS_TAB}s${resetcolor}|\n" "-p" "Path of the pull-secret file" "local 'pull-secret' from \$HOME"
  printf "|${cyantext}%${OPTION_TAB}s${resetcolor} | %-${DESCR_TAB}s | ${greentext}%-${DEFAULTS_TAB}s${resetcolor}|\n" "-a" "Architecture used to check the image" "x86_64"
  printf "|${cyantext}%${OPTION_TAB}s${resetcolor} | %-${DESCR_TAB}s | ${greentext}%-${DEFAULTS_TAB}s${resetcolor}|\n" "-k" "Display the output as KCS format" "false"
  printf "|${cyantext}%${OPTION_TAB}s${resetcolor} | %-${DESCR_TAB}s | ${greentext}%-${DEFAULTS_TAB}s${resetcolor}|\n" "-c" "Clear the images" "false"
  printf "|${cyantext}%${OPTION_TAB}s${resetcolor} | %-${DESCR_TAB}s | ${greentext}%-${DEFAULTS_TAB}s${resetcolor}|\n" "-y" "Automatically retry/continue if 'podman pull' failed" "false"
  printf "|%${OPTION_TAB}s-|-%-${DESCR_TAB}s-|-%-${DEFAULTS_TAB}s|\n" |tr \  '-'
  printf "|%${OPTION_TAB}s | %-${DESCR_TAB}s | %-${DEFAULTS_TAB}s|\n" "" "Additional Options:" ""
  printf "|%${OPTION_TAB}s-|-%-${DESCR_TAB}s-|-%-${DEFAULTS_TAB}s|\n" |tr \  '-'
  printf "|${purpletext}%${OPTION_TAB}s${resetcolor} | %-${DESCR_TAB}s | ${greentext}%-${DEFAULTS_TAB}s${resetcolor}|\n" "-h" "display this help and check for updated version" ""
  printf "|%${OPTION_TAB}s---%-${DESCR_TAB}s---%-${DEFAULTS_TAB}s|\n" |tr \  '-'

  Script=$(which "$0" 2>"${STD_ERR}")
  if [[ "${Script}" != "bash" ]] && [[ ! -z ${Script} ]]
  then
    VERSION=$(grep "@VERSION" "${Script}" 2>"${STD_ERR}" | grep -Ev "VERSION=" | cut -d'#' -f3)
    VERSION=${VERSION:-" N/A"}
  fi
  echo -e "\nCurrent Version:\t${VERSION}"
}

fct_spinning() {
PID=$1
spin='-\|/'

i=0
while kill -0 "$PID" 2>/dev/null
do
  i=$(( (i+1) %4 ))
  printf "\b%s" "${spin:$i:1}"
  sleep .1
done
printf "\b"
}

fct_retrieve_etcd_version() {
  VERSION=$1
  RETRY=0
  osImageURL=$(oc adm release info quay.io/openshift-release-dev/ocp-release:"${VERSION}"-"${ARCH}" -o json 2>/dev/null | jq -r '.references.spec.tags[] | select(.name == "etcd")| .from.name')
  if [[ -z ${osImageURL} && ${ARCH} != "x86_64" ]]
  then
    if [[ ${KCS_FORMAT} != "true" ]]
    then
      echo -e "${yellowtext}WARN: No ${ARCH} image for ${VERSION}, falling back to x86_64 (may fail under emulation).${resetcolor}"
    fi
    osImageURL=$(oc adm release info quay.io/openshift-release-dev/ocp-release:"${VERSION}"-x86_64 -o json 2>/dev/null | jq -r '.references.spec.tags[] | select(.name == "etcd")| .from.name')
    if [[ -z ${osImageURL} ]]
    then
      echo -e "\n${redtext}ERR: Unable to retrieve the image for the release ${VERSION}-x86_64${resetcolor}"
      return 1
    fi
  fi
  WAIT_RC=1
  while [[ ${WAIT_RC} != 0 ]] && [[ ${RETRY} -le ${MAX_RETRY} ]]
  do
    if [[ ${KCS_FORMAT} != "true" ]]
    then
      printf "ETCD version for release: %-7s (using the image %s):  " "${VERSION}" "${osImageURL}"
    fi
    RETRY=$((RETRY + 1))
    podman pull --authfile="${PULL_SECRET_PATH}" "${osImageURL}" >/dev/null 2>&1 &
    PID=$!
    if [[ ${KCS_FORMAT} != "true" ]]
    then
      fct_spinning ${PID}
    fi
    wait "${PID}"
    WAIT_RC=$?
    sleep .5
    if [[ ${WAIT_RC} != 0 ]]
    then
      if [[ ${RETRY} -le ${MAX_RETRY} ]]
      then
        if [[ "$CONTINUE" != "true" ]]
        then
          echo -e "\n${yellowtext}WARN: failed to pull the image ${osImageURL} for the release ${VERSION}${resetcolor}"
          printf "Do you want to continue? [y/n] "
          read -r REP
        else
          if [[ ${KCS_FORMAT} != "true" ]]
          then
            echo -e "\n${yellowtext}WARN: failed to pull the image ${osImageURL} for the release ${VERSION}${resetcolor}"
          fi
        fi
        if [[ "$CONTINUE" == "true" ]] || [[ ${REP} == "y" ]] || [[ ${REP} == "Y" ]]
        then
          if [[ ${KCS_FORMAT} != "true" ]]
          then
            echo -e "INFO: Retrying ... ${RETRY}/${MAX_RETRY}"
          fi
        else
          break
        fi
      fi
    fi
  done
  if [[ ${WAIT_RC} != 0 ]]
  then
    if [[ ${KCS_FORMAT} != "true" ]]
    then
      echo -e "\n${redtext}ERR: Unable to retrieve the ETCD version for the release ${VERSION}${resetcolor}"
    else
      FAILED_RELEASE_LIST+=("${VERSION}")
    fi
    RC=$((RC + 1))
    return 1
  fi
  IMAGES_LIST+=("${osImageURL}")
  ETCD_VERSION=$(podman run --rm --entrypoint '["/usr/bin/etcd","--version"]' "${osImageURL}" 2>/dev/null | awk '{if ($1 == "etcd"){print $NF}}')
  if [[ ${KCS_FORMAT} != "true" ]]
  then
    echo "${ETCD_VERSION}"
  else
    RELEASE_MINOR_VERSION=$(echo "${VERSION}" | cut -d'.' -f1,2)
    if [[ -z ${CURRENT_MINOR_VERSION} ]] || [[ "${RELEASE_MINOR_VERSION}" != "${CURRENT_MINOR_VERSION}" ]]
    then
      CURRENT_MINOR_VERSION=${RELEASE_MINOR_VERSION}
      CURRENT_ETCD_VERSION=""
      printf "\n    * RHOCP %s \n    | Minor Version| ETCD Version | Associate Releases |\n    |---|---|---|" "${CURRENT_MINOR_VERSION}"
    fi
    if [[ -z ${CURRENT_ETCD_VERSION} ]] || [[ "${ETCD_VERSION}" != "${CURRENT_ETCD_VERSION}" ]]
    then
      CURRENT_ETCD_VERSION=${ETCD_VERSION}
      printf "\n    | %s | %s | %s" "${CURRENT_MINOR_VERSION}" "${ETCD_VERSION}" "${VERSION}"
    else
      printf ", %s" "${VERSION}"
    fi
  fi
}

#### Main
# Global Variables
DEFAULT_graytext="\x1B[30m"
DEFAULT_redtext="\x1B[31m"
DEFAULT_greentext="\x1B[32m"
DEFAULT_yellowtext="\x1B[33m"
DEFAULT_bluetext="\x1B[34m"
DEFAULT_purpletext="\x1B[35m"
DEFAULT_cyantext="\x1B[36m"
DEFAULT_whitetext="\x1B[37m"
DEFAULT_resetcolor="\x1B[0m"
# Custom variables
IMAGES_LIST=()
CHANNEL_NAME=${CHANNEL_NAME:-"fast"}
CHANNEL_URL=${CHANNEL_URL:-"https://raw.githubusercontent.com/openshift/cincinnati-graph-data/refs/heads/master/internal-channels/${CHANNEL_NAME}.yaml"}
RC=0
MAX_RETRY=${MAX_RETRY:-2}
STD_ERR=${STD_ERR:-/dev/null}
# Color list
graytext=${graytext:-${DEFAULT_graytext}}
redtext=${redtext:-${DEFAULT_redtext}}
greentext=${greentext:-${DEFAULT_greentext}}
yellowtext=${yellowtext:-${DEFAULT_yellowtext}}
bluetext=${bluetext:-${DEFAULT_bluetext}}
purpletext=${purpletext:-${DEFAULT_purpletext}}
cyantext=${cyantext:-${DEFAULT_cyantext}}
whitetext=${whitetext:-${DEFAULT_whitetext}}
resetcolor=${resetcolor:-${DEFAULT_resetcolor}}

# Check command dependencies
for check_path in podman oc jq yq
do
  if [[ ! -f $(which "${check_path}" 2>"${STD_ERR}" | awk '{print $NF}') ]]
  then
    echo -e "${check_path}: command not found!\nPlease refer to the README for depedencies and/or check your \$PATH"
    exit 2
  fi
done

# Retrieve the options
if [[ $# != 0 ]]
then
  if [[ $1 == "-" ]] || [[ $1 =~ ^[a-zA-Z0-9] ]]
  then
    echo -e "Invalid option: ${1}\n"
    fct_help && exit 1
  fi
  while getopts :a:m:r:p:ckyh arg; do
    case $arg in
      a)
        ARCH=${OPTARG}
        ;;
      m)
        MINORS=$(echo "${OPTARG}" | sed -e "s/,/ /g")
        MINOR_LIST+=("${MINORS}")
        if [[ -z ${AVAILABLE_RELEASE_LIST} ]]
        then
          AVAILABLE_RELEASE_LIST=$(curl -kLs "${CHANNEL_URL}" 2>/dev/null | yq -r '.versions' -o json 2>/dev/null)
          if [[ -z ${AVAILABLE_RELEASE_LIST} ]]
          then
            echo -e "${yellowtext}WARN: Unable to download the Minor Version list.${resetcolor}"
            echo "Please verify that you can access the URL: ${CHANNEL_URL}"
            exit 2
          fi
        fi
        ;;
      r)
        RELEASES=$(echo "${OPTARG}" | sed -e "s/,/ /g")
        RELEASE_LIST+=("${RELEASES}")
        ;;
      p)
        PULL_SECRET_PATH=${OPTARG}
        ;;
      k)
        KCS_FORMAT="true"
        # Automatically continue if the podman pull failed for the KCS format.
        CONTINUE="true"
        ;;
      c)
        CLEAN_IMAGES="true"
        ;;
      y)
        CONTINUE="true"
        ;;
      h)
        fct_help && exit 0
        ;;
      ?)
        echo -e "Invalid option\n"
        fct_help && exit 1
        ;;
    esac
  done
fi

# Set & check variables
if [[ ${#RELEASE_LIST[@]} -eq 0 ]] && [[  ${#MINOR_LIST[@]} -eq 0 ]]
then
  echo "ERR: Either one Release or one Minor version must be set"
  echo "They can either been set as variable ('MINOR'/'RELEASE') or using the script options"
  fct_help && exit 1
fi
ARCH=${ARCH:-"x86_64"}
if [[ -z ${PULL_SECRET_PATH} ]]
then
  PULL_SECRET_PATH=$(find ~ -maxdepth 2 \( -type f -or -type l \) -name "pull-secret" 2>/dev/null | head -1)
  if [[ -z ${PULL_SECRET_PATH} ]]
  then
    echo "ERR: No Pull secret specified"
    echo "Please ensure to provide a pull-secret either as variable ('PULL_SECRET_PATH') or using the script options"
    fct_help && exit 1
  else
    echo "INFO: No pull-secret specified, but found '${PULL_SECRET_PATH}'. Trying to use it"
  fi
fi

# Retrieve the Releases from the desired Minor Versions.
for MINOR_VERSION in ${MINOR_LIST[*]}
do
  RELEASE=$(echo "${AVAILABLE_RELEASE_LIST}" | jq -r --arg minor "$(echo "${MINOR_VERSION}" | cut -d'.' -f1,2)" '. | to_entries[] | select(.value | startswith($minor)) | .value')
  RELEASE_LIST+=("${RELEASE}")
done

# Reoarder the version for easy management.
for RELEASE in $(IFS=$'\n' && sort -t'.' -h -k2 -k3 <<<"${RELEASE_LIST[*]}" && unset IFS)
do
  fct_retrieve_etcd_version "${RELEASE}"
done
if [[ "${FAILED_RELEASE_LIST[*]}" != "" ]]
then
  echo -e "\n\n${redtext}ERR: Unable to retrieve the ETCD version for the following release(s): ${FAILED_RELEASE_LIST[*]}${resetcolor}"
fi

# Clean the images if required.
if [[ "${CLEAN_IMAGES}" == "true" ]] && [[ ${#IMAGES_LIST[@]} -gt 0 ]]
then
  echo -e "\n\n===== Cleaning the images ====="
  podman rmi  "${IMAGES_LIST[@]}"
fi

exit $RC
