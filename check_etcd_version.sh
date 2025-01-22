#!/bin/bash
##################################################################
# Script       # check_etcd_version.sh
# Description  # Retreive the ETCD version for the RHOCP releases
# @VERSION     # 0.1.0
##################################################################
# Changelog.md # List the modifications in the script.
# README.md    # Describes the repository usage
##################################################################

#### Functions
fct_help(){
  Script=$(which $0 2>${STD_ERR})
  if [[ "${Script}" != "bash" ]] && [[ ! -z ${Script} ]]
  then
    ScriptName=$(basename $0)
  fi
  echo -e "usage: ${cyantext}${ScriptName} [-a <Arch>] [-r <release>] [-m <minor_version>] [-p <pull-secret>] [-kc] ${purpletext}[-h]${resetcolor}"
  OPTION_TAB=8
  DESCR_TAB=63
  DEFAULTS_TAB=31
  printf "|%${OPTION_TAB}s---%-${DESCR_TAB}s---%-${DEFAULTS_TAB}s|\n" |tr \  '-'
  printf "|%${OPTION_TAB}s | %-${DESCR_TAB}s | %-${DEFAULTS_TAB}s|\n" "Options" "Description" "[Defaults]"
  printf "|%${OPTION_TAB}s | %-${DESCR_TAB}s | %-${DEFAULTS_TAB}s|\n" |tr \  '-'
  printf "|${cyantext}%${OPTION_TAB}s${resetcolor} | %-${DESCR_TAB}s | ${greentext}%-${DEFAULTS_TAB}s${resetcolor}|\n" "-a" "Architecture used to check the image" "x86_64"
  printf "|${cyantext}%${OPTION_TAB}s${resetcolor} | %-${DESCR_TAB}s | ${greentext}%-${DEFAULTS_TAB}s${resetcolor}|\n" "-r" "List of release version(s) to check" ""
  printf "|${cyantext}%${OPTION_TAB}s${resetcolor} | %-${DESCR_TAB}s | ${greentext}%-${DEFAULTS_TAB}s${resetcolor}|\n" "-m" "List of minor version(s) to check" ""
  printf "|${cyantext}%${OPTION_TAB}s${resetcolor} | %-${DESCR_TAB}s | ${greentext}%-${DEFAULTS_TAB}s${resetcolor}|\n" "-p" "Path of the pull-secret file" "local 'pull-secret' from \$HOME"
  printf "|${cyantext}%${OPTION_TAB}s${resetcolor} | %-${DESCR_TAB}s | ${greentext}%-${DEFAULTS_TAB}s${resetcolor}|\n" "-k" "Display the output as KCS format" "false"
  printf "|${cyantext}%${OPTION_TAB}s${resetcolor} | %-${DESCR_TAB}s | ${greentext}%-${DEFAULTS_TAB}s${resetcolor}|\n" "-c" "Clear the images" "false"
  printf "|%${OPTION_TAB}s-|-%-${DESCR_TAB}s-|-%-${DEFAULTS_TAB}s|\n" |tr \  '-'
  printf "|%${OPTION_TAB}s | %-${DESCR_TAB}s | %-${DEFAULTS_TAB}s|\n" "" "Additional Options:" ""
  printf "|%${OPTION_TAB}s-|-%-${DESCR_TAB}s-|-%-${DEFAULTS_TAB}s|\n" |tr \  '-'
  printf "|${purpletext}%${OPTION_TAB}s${resetcolor} | %-${DESCR_TAB}s | ${greentext}%-${DEFAULTS_TAB}s${resetcolor}|\n" "-h" "display this help and check for updated version" ""
  printf "|%${OPTION_TAB}s---%-${DESCR_TAB}s---%-${DEFAULTS_TAB}s|\n" |tr \  '-'

  Script=$(which $0 2>${STD_ERR})
  if [[ "${Script}" != "bash" ]] && [[ ! -z ${Script} ]]
  then
    VERSION=$(grep "@VERSION" ${Script} 2>${STD_ERR} | grep -Ev "VERSION=" | cut -d'#' -f3)
    VERSION=${VERSION:-" N/A"}
  fi
  echo -e "\nCurrent Version:\t${VERSION}"
}

fct_retrieve_etcd_version() {
  VERSION=$1
  osImageURL=$(oc adm release info quay.io/openshift-release-dev/ocp-release:${VERSION}-${ARCH} -o json | jq -r '.references.spec.tags[] | select(.name == "etcd")| .from.name')
  if [[ ${KCS_FORMAT} != "true" ]]
  then
    printf "ETCD version for release: ${VERSION} (using the image ${osImageURL}): "
  fi
  podman pull --authfile=${PULL_SECRET_PATH} ${osImageURL} >/dev/null 2>&1
  if [[ $? != 0 ]]
  then
    echo -e "${redtext}ERR: failed to pull the image ${osImageURL} for the release ${VERSION}${resetcolor}"
    printf "Do you want to continue? [y/n] "
    read REP
    if [[ ${REP} != "y" ]] && [[ ${REP} != "Y" ]]
    then
      exit 10
    fi
  else
    IMAGES_LIST+=(${osImageURL})
    ETCD_VERSION=$(podman run --rm --entrypoint '["/usr/bin/etcd","--version"]' ${osImageURL} 2>/dev/null | awk '{if ($1 == "etcd"){print $NF}}')
    if [[ ${KCS_FORMAT} != "true" ]]
    then
      echo "${ETCD_VERSION}"
    else
      RELEASE_MINOR_VERSION=$(echo ${VERSION} | cut -d'.' -f1,2)
      if [[ -z ${CURRENT_MINOR_VERSION} ]] || [[ "${RELEASE_MINOR_VERSION}" != "${CURRENT_MINOR_VERSION}" ]]
      then
        CURRENT_MINOR_VERSION=${RELEASE_MINOR_VERSION}
        CURRENT_ETCD_VERSION=""
        printf "\n    * RHOCP ${CURRENT_MINOR_VERSION} \n    | Minor Version| ETCD Version | Associate Releases |\n    |---|---|---|"
      fi
      if [[ -z ${CURRENT_ETCD_VERSION} ]] || [[ "${ETCD_VERSION}" != "${CURRENT_ETCD_VERSION}" ]]
      then
        CURRENT_ETCD_VERSION=${ETCD_VERSION}
        printf "\n    | ${CURRENT_MINOR_VERSION} | ${ETCD_VERSION} | ${VERSION}"
      else
        printf ", ${VERSION}"
      fi
    fi
  fi
}

#### Main
# Global Variables
MINOR=()
RELEASE=()
IMAGES_LIST=()
CHANNEL_URL=${CHANNEL_URL:-"https://raw.githubusercontent.com/openshift/cincinnati-graph-data/refs/heads/master/internal-channels/fast.yaml"}

# Retrieve the options
if [[ $# != 0 ]]
then
  INSIGHTS_OPTIONS=""
  if [[ $1 == "-" ]] || [[ $1 =~ ^[a-zA-Z0-9] ]]
  then
    echo -e "Invalid option: ${1}\n"
    fct_help && exit 1
  fi
  while getopts :a:m:r:p:ckh arg; do
    case $arg in
      a)
        ARCH=${OPTARG}
        ;;
      m)
        MINOR_LIST+=($(echo ${OPTARG} | sed -e "s/,/ /g"))
        if [[ -z ${AVAILABLE_RELEASE_LIST} ]]
        then
          AVAILABLE_RELEASE_LIST=$(curl -kLs ${CHANNEL_URL} 2>/dev/null | yq -r '.versions' 2>/dev/null)
          if [[ -z ${AVAILABLE_RELEASE_LIST} ]]
          then
            echo -e "${yellowtext}WARN: Unable to download the Minor Version list.${resetcolor}"
            echo "Please verify that you can access the URL: ${CHANNEL_URL}"
            exit 2
          fi
        fi
        ;;
      r)
        RELEASE_LIST+=($(echo ${OPTARG} | sed -e "s/,/ /g"))
        ;;
      p)
        PULL_SECRET_PATH=${OPTARG}
        ;;
      k)
        KCS_FORMAT="true"
        ETCD_VERSION_ARRAY=()
        ;;
      c)
        CLEAN_IMAGES="true"
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
if [[ -z ${RELEASE_LIST} ]] && [[ -z ${MINOR_LIST} ]]
then
  echo "ERR: Either one Release or one Minor version must be set"
  echo "They can either been set as variable ("MINOR"/"RELEASE") or using the script options"
  fct_help && exit 1
fi
ARCH=${ARCH:-"x86_64"}
if [[ -z ${PULL_SECRET_PATH} ]]
then
  PULL_SECRET_PATH=$(find ~ -name "pull-secret")
  if [[ -z ${PULL_SECRET_PATH} ]]
  then
    echo "ERR: No Pull secret specified"
    echo "Please ensure to provide a pull-secret either as variable ("") or using the script options"
    fct_help && exit 1
  else
    echo "INFO: No pull-secret specified, but found '${PULL_SECRET_PATH}'. Trying to use it"
  fi
fi

# Check if podman is available
if [[ ! -f $(which podman 2>${STD_ERR}) ]]
then
  echo -e "podman: command not found!\nPlease check your PATH"
  exit 2
fi

# Retrieve the Releases from the desired Minor Versions.
for MINOR_VERSION in ${MINOR_LIST[*]}
do
  RELEASE_LIST+=($(echo ${AVAILABLE_RELEASE_LIST} | jq -r --arg minor $MINOR_VERSION '. | to_entries[] | select(.value | startswith($minor)) | .value'))
done

# Reoarder the version for easy management.
for RELEASE in $(IFS=$'\n' && sort -t'.' -h -k2 -k3 <<<"${RELEASE_LIST[*]}" && unset IFS)
do
  fct_retrieve_etcd_version ${RELEASE}
done

# Clean the images if required.
if [[ "${CLEAN_IMAGES}" == "true" ]] && [[ ! -z ${IMAGES_LIST} ]]
then
  echo -e "\n\n===== Cleaning the images ====="
  podman rmi ${IMAGES_LIST[*]}
fi