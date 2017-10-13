#!/usr/bin/env bash
# Deploy tar ball of the /etc/puppet/environments folder (including secrets) for deployment to puppet masters

# Options
DIR=$1

# Variables
PUPPETMASTER=${PUPPET_MASTER:-""}
REMOTECI=${REMOTECI:-""}
ARTIFACT=`ls ${DIR}/ | sort -nr | head -1`

# Purely cosmetic function to prettify output
# Set OUTPUT_LABEL to change the label
# Supports ERROR, SUCCESS, and WARN as arguments
function output() {
local label=${OUTPUT_LABEL:-$0}
local timestamp=$(date +%d/%m/%Y\ %H:%M)
local colour='\033[34m' # Blue
local reset='\033[0m'
case $1 in
ERROR) local colour='\033[31m' ;; # Red
SUCCESS) local colour='\033[32m' ;; # Green
WARN) local colour='\033[33m' ;; # Yellow
esac
while read line; do
echo -e "${colour}${label} [${timestamp}]${reset} ${line}"
done
}

# Check prerequisits
# Check user is root - currently disabled as script is now configured to run as un unpriv user
#[ $(id -u) != 0 ] && echo "ERROR - You must run this script as root!" | output ERROR && exit 1

for PUPPET in ${PUPPETMASTER} ; do

  # Copy artifact to puppet master
  echo "Attempting to copy ${ARTIFACT} to ${PUPPET}" | output
  scp -o StrictHostKeyChecking=no ${DIR}/${ARTIFACT} deployment@${PUPPET}:/tmp/ > /dev/null 2>&1
  if [[ $? == '0' ]]; then
    echo "${ARTIFACT}" successfully copied to ${PUPPET} | output SUCCESS
  else
    echo "Error copying ${ARTIFACT} to ${PUPPET}" | output ERROR && exit 1
  fi

  # SSH to puppet master, stop puppetmaster service, purge existing environments,
  # uncompress artifact and restart puppetmaster service then delete compressed artifact.

  # Delete temp environment folder if exists
  ssh deployment@${PUPPET} "sudo rm -rf /etc/puppet/temp_environments" #> /dev/null 2>&1
  [[ $? != '0' ]] && echo "Error deleting temp environments folder  ${PUPPET}" | output ERROR && exit 1
  # Create temp environments folder
  ssh deployment@${PUPPET} "sudo mkdir /etc/puppet/temp_environments" #> /dev/null 2>&1
  [[ $? != '0' ]] && echo "Error creating temp environments folder  ${PUPPET}" | output ERROR && exit 1
  # Extract tar to temp environment folder
  ssh -o StrictHostKeyChecking=no deployment@${PUPPET} "sudo tar -C /etc/puppet/temp_environments/ -xzf /tmp/${ARTIFACT} --selinux" > /dev/null 2>&1
  [[ $? != '0' ]] && echo "Error stopping puppetmaster service on ${PUPPET}" | output ERROR && exit 1
  # Stop puppet
  ssh -o StrictHostKeyChecking=no deployment@${PUPPET} "sudo systemctl stop puppetmaster-unicorn.service" > /dev/null 2>&1
  [[ $? != '0' ]] && echo "Error stopping puppetmaster service on ${PUPPET}" | output ERROR && exit 1
  # remove proper environments folder
  ssh deployment@${PUPPET} "sudo rm -rf /etc/puppet/environments" #> /dev/null 2>&1
  [[ $? != '0' ]] && echo "Error purging existing environments on  ${PUPPET}" | output ERROR && exit 1
  # move temp environments to proper envornments folder
  ssh -o StrictHostKeyChecking=no deployment@${PUPPET} "sudo mv /etc/puppet/temp_environments/environments /etc/puppet/environments" > /dev/null 2>&1
  [[ $? != '0' ]] && echo "Error extracting artifact on  ${PUPPET}" | output ERROR && exit 1
  # Delete Artifact
  ssh -o StrictHostKeyChecking=no deployment@${PUPPET} "sudo rm /tmp/${ARTIFACT}" > /dev/null 2>&1
  [[ $? != '0' ]] && echo "Error removing compressed version of artifact on  ${PUPPET}" | output ERROR && exit 1
  # Restart Puppet master
  ssh -o StrictHostKeyChecking=no deployment@${PUPPET} "sudo systemctl start puppetmaster-unicorn.service" > /dev/null 2>&1
  if [[ $? == '0' ]]; then
    echo "Puppet environment code and dependencies successfully deployed" | output SUCCESS
  else
    echo "Error restarting puppetmaster service on ${PUPPET}" | output ERROR && exit 1
  fi
done

# Copy artifact to remote ci server
for CI in ${REMOTECI} ; do
  echo "Attempting to copy ${ARTIFACT} to ${CI}" | output
  scp -o StrictHostKeyChecking=no ${DIR}/${ARTIFACT} deployment@${CI}:${DIR}/ > /dev/null 2>&1
  if [[ $? == '0' ]]; then
    echo "${ARTIFACT}" successfully copied to ${CI} | output SUCCESS
  else
    echo "Error copying ${ARTIFACT} to ${CI}" | output ERROR && exit 1
  fi
done

# Tidying up step to remove old Artifacts.  Currently set to keep the 3 most recently modified files.
ls -t ${DIR} | sed -e '1,3d' | xargs -d '\n' rm -f
