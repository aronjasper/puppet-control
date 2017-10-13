#!/usr/bin/env bash
# Builds a tar ball of the /etc/puppet/environments folder (including secrets) for deployment to puppet masters

# Options
CONTROL=$1
SECRETS=$2
ARTIFACTS_DIR=$3

# Paths
BASE_DIR=${BASE_DIR:-'/var/lib/jenkins/artifact_r10k'}
CACHE_DIR="${BASE_DIR}/cache"
ENVIRONMENTS_DIR="${BASE_DIR}/environments"
SECRETS_DIR="${BASE_DIR}/secrets"
R10KCONF_PATH="${BASE_DIR}/r10k.yaml"
HIERA_PATH='hiera/secrets'
R10K_BIN='/usr/local/bin/g10k'

TIMESTAMP=$(date +%Y%m%d-%H%M)
OUTPUT_LABEL='deploy-secrets'

# Purely cosmetic function to prettify output
# Set OUTPUT_LABEL to change the label
# Supports ERROR, SUCCESS, and WARN as arguments
function output() {
  local label=${OUTPUT_LABEL:-$0}
  local timestamp=$(date +%d/%m/%Y\ %H:%M)
  local colour='\033[34m' # Blue
  local reset='\033[0m'
  case $1 in
    ERROR)   local colour='\033[31m' ;; # Red
    SUCCESS) local colour='\033[32m' ;; # Green
    WARN)    local colour='\033[33m' ;; # Yellow
  esac
  while read line; do
    echo -e "${colour}${label} [${timestamp}]${reset} ${line}"
  done
}

function checkreqs() {
  local USAGE=`basename $0`" [CONTROL REPO URI] [SECRETS REPO URI]"
  # Check that a git repository for Puppet's control configuration is specified
  [[ -z ${CONTROL} ]] && echo -e "ERROR - You must specify a source repository! \n Usage: ${USAGE}" | output ERROR && exit 1
  # Check that a secrets repository has been specified
  [[ -z ${SECRETS} ]] && echo -e "ERROR - You must specify a secrets repository! \n Usage: ${USAGE}" | output ERROR && exit 1
  # Check necessary binaries are able to be found in path
  for BIN in git tar puppet; do
  # for BIN in git tar puppet r10k; do
    [[ ! $(which ${BIN} 2>/dev/null) ]] && echo -e "ERROR - ${BIN} not found in path. \n Path: ${PATH}" | output ERROR && exit 1
  done
}

function setupconf() {
  for DIRECTORY in ${BASE_DIR} ${CACHE_DIR} ${ARTIFACTS_DIR} ${ENVIRONMENTS_DIR} ${SECRETS_DIR}; do
    [[ ! -d ${DIRECTORY} ]] && mkdir -p ${DIRECTORY} && echo -e "WARN - Created ${DIRECTORY}" | output WARN
  done
  cat <<R10KYAML > ${R10KCONF_PATH}
---

  cachedir: ${CACHE_DIR}
  sources:
    control:
      basedir: ${ENVIRONMENTS_DIR}
      prefix: false
      remote: ${CONTROL}
    secrets:
      basedir: ${SECRETS_DIR}
      prefix: false
      remote: ${SECRETS}
  deploy:
    purge_levels:
    - deployment
    - environment
    - puppetfile

R10KYAML
  if [[ $? == '0' ]]; then
    echo "Wrote R10K configuration file to ${R10KCONF_PATH}" | output
  else
    echo "ERROR - Problem creating R10K configuration file at ${R10KCONF_PATH}" | output ERROR && exit 1
  fi
}

function runr10k() {
  echo 'Running R10K now...' | output
  ${R10K_BIN} -config ${R10KCONF_PATH} -info
  if [[ $? == '0' ]]; then
    echo "Repositories and modules synced successfully." | output SUCESS
  else
    echo "ERROR - Running g10k - This could be because of incorrectly formatted Puppetfile!" | output ERROR && exit 1
  fi
}

function mergesecrets() {
  for ENVIRONMENT in ${ENVIRONMENTS_DIR}/*; do
    ENVNAME=$(basename ${ENVIRONMENT})
    if [[ -d "${ENVIRONMENT}/${HIERA_PATH}" ]]; then
      echo "Purging previous secrets from ${ENVNAME}..." | output
      rm -rf "${ENVIRONMENT}/${HIERA_PATH}"
    fi
    if [[ ! -d "${SECRETS_DIR}/${ENVNAME}" ]]; then
      echo "WARN - The environment '${ENVNAME}' does not have a corresponding secrets branch." | output WARN
    else
      cp -R ${SECRETS_DIR}/${ENVNAME} ${ENVIRONMENT}/${HIERA_PATH}
    fi
  done
  echo 'Secrets merged with control data successfully.' | output SUCESS
}

function package(){
  echo 'Performing pre-packaging tasks...' | output
  # Ensure the file permissions are set to 0644 for all regular files
  find ${ENVIRONMENTS_DIR} -type f -print0 | xargs -0 chmod 0644 > /dev/null 2>&1
  # Ensure the correct SELinux user and type are set for all files
  chcon -R -u system_u -t puppet_etc_t ${ENVIRONMENTS_DIR} > /dev/null 2>&1
  echo 'Packaging artifact...' | output
  ARTIFACT_FILENAME="${ARTIFACTS_DIR}/${TIMESTAMP}.tgz"
  tar -C ${BASE_DIR} -czf ${ARTIFACT_FILENAME} environments/ --owner=puppet --group=puppet --selinux > /dev/null 2>&1
  if [[ $? == '0' ]]; then
    echo "Artifact successfully created at ${ARTIFACT_FILENAME}" | output SUCCESS && exit 0
  else
    echo "ERROR - Compressing artifact failed!" | output ERROR && exit 1
  fi
}

checkreqs
setupconf
runr10k
mergesecrets
package
