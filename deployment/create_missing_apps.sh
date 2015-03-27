#!/bin/bash

dir=`pwd`

#Location of git project locally
cd /home/ewolinetz/git/middleware_TaxManager 

apps=$(diff -y --suppress-common-lines <( cat $dir/branches.list ) <( git branch -r --list ) | awk -F'>' '{print $2}' | sed 's/\t//g')

for app in $(echo $apps); do
  validname=$(echo $app | awk -F'/' '{print $2}' | tr -cd '[[:alnum:]]')
  echo $app will be created... as $validname
  #this is where rhc is already installed
  ssh dil-vm-osh-11.aircell.prod "rhc create-app -t JBOSSEAP -n taxmanager -a $validname -s --no-git --no-dns" | tee $dir/test_output.txt

  response=$(cat $dir/test_output.txt)
  rm -f $dir/test_output.txt

  if [[ ! -z `echo "$response" | grep "Your application '.*' is now available."` ]]; then
    echo "Success!"

  # Check that we got a success before we send an email and add the application to the list... 
    email=$(git log $app | sed -n '/Author:/{p; q;}' | awk -F'<' '{print $2}' | sed -e 's/>//g')
    echo "Send email to $email that their application is created!"
    #TODO: actually send email

    echo "$app" >> $dir/branches.list
  else
    echo "Application creation was unsuccessful: $response"
  fi
done

cd $dir
