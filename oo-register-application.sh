#!/bin/bash
#oo-register-application.sh {gearProfile}{appDomain} [--appAdmins {appAdminsCSV}] [--developers {developersCSV}]
#SETUP
# Set the broker host variable below to the correct url for the broker and [OPTIONAL] set the logfile where to send stdout & stderr
# Set the internalUser to the user who will own authenticate to register the application
#
#PARAMETERS
#
#gearProfile: gear profile to be used in the application eg. small, medium
#appDomain: the domain of the application
#
#VARIABLES
#logFile: where the stderr and stdout get redirected to
#brokerhost: url of the OSE broker
#
#
#EXAMPLES
# ./oo-register-developer.sh Jsmith small
# ./oo-register-developer.sh Bnye medium
#
#

brokerhost="localhost"
internalUser="demo"
logfile=/var/log/openshift/broker/ose-utils.log


export status=-1

function usage {
  echo "Usage: oo-register-application.sh {gearProfile} {appDomain} [--appAdmins {appAdminsCSV}] [--developers {developersCSV}]"
}

function json {
  echo "{
        'returnCode':'$1',
        'returnDesc':'$2',
        'authenticationTokenId':'$3'

  }"

}

function exit_code {
  IFS=',' read -ra json <<< $1
  for section in ${json[*]}; do
      if [[ $section == *"exit_code"* ]]; then
      code=$(grep -o "[0-9]" <<< "$section")
      code=$(sed 's/ //g' <<< $code)
      echo "$code"
      export status=$code

      fi
  done
  if [ $status = -1 ];then
     export status=0
  fi
}

if [ "$#" -le 1 ]
  then
  usage
  json 255 "Invalid usage"
  exit 255
fi

gearProfile="$1"
appDomain="$2"
if [ -z ${gearProfile+x} ] || [ -z ${appDomain+x} ]
  then
  usage
  json 1 "gearProfile or appDomain not set" ""
  exit 1
fi
if [ -z ${3+x} ]
  then
  #no optional parameters provided
  sleep 0
elif [ "$3" != "--appAdmins" ] && [ "$3" != "--developers" ]
    then
    usage
    json 255 "Unrecognized flag $3" ""
    exit 255
elif [ "$3" = "--appAdmins" ]
  then
  appAdminCVS=$4
else [ "$3" = "--developers" ]
  developers=$4
fi

if [ "$5" = "--appAdmins" ]
  then
  appAdminCVS=$6
elif [ "$5" = "--developers" ]
  then
  developers=$6
fi

#1. Create internal Openshift user "$internalUser"
oo-admin-ctl-user -c -l $internalUser
if [ "$?" = "0" ]; then
  echo "The user $internalUser already exists!"

fi


#Create Token (expires a year from creation
TOKEN="$(oo-auth-token -l $internalUser -e "$(date -d "+year")")"


#2. Create application domain owned by internal Openshift user $internalUser
response=$( curl -k -H "Authorization: Bearer $TOKEN" -X POST https://$brokerhost/broker/rest/domains/ --data-urlencode name=$appDomain --data-urlencode allowed_gear_sizes=small)
exit_code $response

if [ $status != 0 ];then
    json 1 "Openshift API exit code $status"
    exit 1
fi


#4. grant edit access on the application domain to all employeeNums listed under appAdmins
IFS=',' read -ra admins <<< $appAdminCVS
echo ""
for employee in ${admins[*]}; do
    response=$(curl -k -H "Authorization: Bearer $TOKEN" -X PATCH https://$brokerhost/broker/rest/domains/$appDomain/members --data-urlencode role=admin --data-urlencode login=$employee)
    exit_code $response
    if [ $status != 0 ];then
        json 255 "Openshift API exit code $status"
        echo "2"
        exit 255
    fi
done

#5 Grant view access on application domain to all employees listed under developers

IFS=',' read -ra devs <<< $developers


for dev in ${devs[*]}; do
    response=$(curl -k -H "Authorization: Bearer $TOKEN" -X PATCH https://$brokerhost/broker/rest/domains/$appDomain/members --data-urlencode role=view --data-urlencode login=$dev)
    exit_code $response
    if [ $status != 0 ];then
        json 255 "Openshift API exit code $status"
        exit 255
    fi
done

json 0 "Success" $TOKEN
exit 0
