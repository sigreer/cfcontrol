#!/bin/bash


## Cloudflare Control Script for the management of domains using Cloudflare's API
if [[ -e ~/.env ]]; then
    source ~/.env
elif [[ -e "$PWD"/.env ]]; then
    source "$PWD"/.env
else
    echo "Please add an environment file to ~/.env or current directory."
    exit 0;
fi
if [[ -e ~/.secrets ]]; then
    source ~/.secrets
elif [[ -e "$PWD"/.secrets ]]; then
    source "$PWD"/.secrets
else
    echo "Please add an environment file to ~/.secrets or current directory."
    exit 0;
fi
echo "made it"


## Formatting and styles
BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
BOLD=$(tput bold)
RESET=$(tput sgr0)

function testFunction () {
    echo "Subdomain: $subdomain"
    echo "Site Domain: $sitedomain to $arecord"
    echo "API Key: $CF_API_KEY"
    echo "API Email: $CF_API_EMAIL"
    echo "Zone ID: ${zoneid}"
}

function getZone () {
zoneinfo=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${sitedomain}&status=active&account.id=${ACCOUNT_ID}&page=1&per_page=100&order=status&direction=desc&match=all" -H "X-Auth-Email: $CF_API_EMAIL" -H "X-Auth-Key: $CF_API_KEY" -H "Content-Type: application/json")
zoneid=$(echo $zoneinfo | jq '.result[].id' | tr -d '"')
}

function addsite () {
    curl -s -X POST -H "X-Auth-Key: $CF_API_KEY" -H "X-Auth-Email: $CF_API_EMAIL" -H "Content-Type: application/json" "https://api.cloudflare.com/client/v4/zones" --data "{\"account\":{\"id\":\"$ACCOUNT_ID\"},\"name\":\"$site\",\"jump_start\":true}"
}

function addSubDomainA () {
  curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${zoneid}/dns_records" -H "X-Auth-Email: $CF_API_EMAIL" -H "X-Auth-Key: $CF_API_KEY" -H "Content-Type: application/json" --data "{\"type\":\"A\",\"name\":\"$subdomain\",\"content\":\"$arecord\",\"ttl\":3600,\"priority\":10,\"proxied\":false}"
}

#echo "3"

function addsites () {
    for site in $(cat $importlist); do
        addsite
    done
}

#echo "4"

function addSubDomainAs () {
    for subdomain in $(cat $importlist); do
        addSubDomainA
    done
}

function addSubDomainCs () {
    for subdomain in $(cat $importlist); do
        addSubDomainC
    done
}

function usage () {
    printf "
 "$MAGENTA"
                   _                 _  __ _                
                  | |               | |/ _| |               
               ___| | ___  _   _  __| | |_| | __ _ _ __ ___ 
              / __| |/ _ \\| | | |/ _\` |  _| |/ _\` | \'__/ _ \\
             | (__| | (_) | |_| | (_| | | | | (_| | | |  __/
              \___|_|\___/ \\__,_|\\__,_|_| |_|\\__,_|_|  \\___|
               "$RED"============================================="$RESET"
              "$WHITE"C  O  N  T  R  O  L  "$RED"/"$BLUE" * "$RED"\\"$WHITE"  S  C  R  I  P  T"$RESET"
                  
                                               
    You need to specify parameters and arguments to use this script.
    
    Add an A record to a pre-existing site:"$RESET"
        "$MAGENTA"cfcontrol "$RESET""$RED"-A"$RESET""$CYAN" subdomain.sitedomain.co.uk"$RESET" "$CYAN"122.222.211.212"$RESET"
    
    Add a CNAME record to a pre-existing site:"$RESET"
        "$MAGENTA"cfcontrol "$RESET""$RED"-C"$RESET""$CYAN" subdomain.sitedomain.co.uk"$RESET" "$CYAN"target.domain.com"$RESET"
    
    Create a new site:"$RESET"
        "$MAGENTA"cfcontrol "$RESET""$RED"-S"$RESET""$CYAN" mynewsite.com"$RESET"
    
    You can bulk import any record type by using a .txt or .csv file after the parameter flag:"$RESET"
        "$MAGENTA"cfcontrol "$RESET""$RED"-A"$RESET""$CYAN" /home/subdomains.txt"$RESET"


"
}
#echo "5"

case "$1" in
        -A)
                newarecord="$2"
                subdomain=$(echo $newarecord | sed 's/\([a-zA-Z0-9_\-]\)\..*/\1/')
                sitedomain=$(echo $newarecord | cut -d . -f 2-)
                arecord="$3"
                echo $arecord is the IP. $subdomain is sub and $sitedomain is site
                getZone
                echo $sitedomain
                echo $ACCOUNT_ID
                echo $zoneid
                if [[ $2 = "*.txt" ]]; then
                    importlist="$2"
                    addSubDomainAs
                else
                    addSubDomainA
                fi
                exit 0
                ;;
        -C)
                subdomain=$(echo $newcrecord | sed 's/\([a-zA-Z0-9_\-]\)\..*/\1/')
                sitedomain=$(echo $newcrecord | cut -d . -f 2-)
                cnamerecord="$2"
                #addSubDomainC
                exit 0
                ;;
"" | * | ?)     
                usage
                ;;   
esac

exit