#!/bin/bash


## Cloudflare Control Script for the management of domains using Cloudflare's API
if [[ -e "${HOME}/.cfcontrol/.env" ]]; then
    # shellcheck source=./.env
    source "${HOME}/.config/cfcontrol/.env"
    elif [[ -e "${PWD}/.env" ]]; then
    source "${PWD}/.env"
else
    echo "Please add a .env file to ~/.config/cfcontrol/ or your current working directory."
    exit 1;
fi
echo ".env found"
if [[ -e "${HOME}/.config/cfcontrol/.secrets" ]]; then
    # shellcheck source=./.secrets
    source "${HOME}/.config/cfcontrol/.secrets"
    elif [[ -e "${PWD}/.secrets" ]]; then
    source "${PWD}/.secrets"
else
    echo "Please add a .secrets file to ~/.config/cfcontrol/ or your current working directory."
    exit 1;
fi
echo ".secrets found"


## Formatting and styles
#BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
BOLD=$(tput bold)
RESET=$(tput sgr0)

# function testFunction () {
#    echo "Subdomain: $subdomain"
#    echo "Site Domain: $sitedomain to $arecord"
#    echo "API Key: $CF_API_KEY"
#    echo "API Email: $CF_API_EMAIL"
#    echo "Zone ID: ${zoneid}"
#}

function getZone () {
    zoneinfo=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${sitedomain}&status=active&account.id=${ACCOUNT_ID}&page=1&per_page=100&order=status&direction=desc&match=all" \
        -H "X-Auth-Email: $CF_API_EMAIL" \
        -H "X-Auth-Key: $CF_API_KEY" \
    -H "Content-Type: application/json")
    zoneid=$(echo "$zoneinfo" | jq '.result[].id' | tr -d '"')
}

function addSite () {
    curl -s -X POST \
    -H "X-Auth-Key: $CF_API_KEY" \
    -H "X-Auth-Email: $CF_API_EMAIL" \
    -H "Content-Type: application/json" "https://api.cloudflare.com/client/v4/zones" \
    -d "{\
            \"account\":{\
                \"id\":\"$ACCOUNT_ID\"
                },\
            \"name\":\"$site\",\
            \"jump_start\":true\
    }"
}

function addSubDomainA () {
    fullcommand=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${zoneid}/dns_records" \
        -H "X-Auth-Email: $CF_API_EMAIL" \
        -H "X-Auth-Key: $CF_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"type\":\"A\",\
            \"name\":\"$subdomain\",\
            \"content\":\"$arecord\",\
            \"ttl\":3600,\
            \"priority\":10,\
            \"proxied\":$proxied\
        }"
    )
    echo "${BOLD}${GREEN}$fullcommand${RESET}"
    
    success=$(echo "$fullcommand" | sed /.*\(success\":true\).*/true/)
    [[ $success == "true" ]] && echo "The command completed successfully" \
    && echo "${YELLOW}${subdomain}${RESET} now points to ${YELLOW}${arecord}${RESET} with" \
    && [[ $proxied == "true" ]] && echo -e "${GREEN}proxy enabled${RESET}" || echo -e "${RED}proxy disabled${RESET}"
}

function addSubDomainC () {
    fullcommand=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${zoneid}/dns_records" \
        -H "X-Auth-Email: $CF_API_EMAIL" \
        -H "X-Auth-Key: $CF_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"type\":\"CNAME\",\
            \"name\":\"$subdomain\",\
            \"content\":\"$cnamerecord\",\
            \"ttl\":3600,\
            \"priority\":10,\
            \"proxied\":$proxied\
        }"
    )
    echo "$fullcommand"
    
    success=$(echo "$fullcommand" | sed /.*\(success\":true\).*/true/)
    [[ $success == "true" ]] && echo "The command completed successfully" \
    && echo "${subdomain} now points to ${arecord} with" \
    && [[ $proxied == "true" ]] && echo -e "proxy enabled" || echo -e "proxy disabled"
}

#function addSubDomainAtest () {
#    printf 'curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${zoneid}/dns_records" \
#    -H "X-Auth-Email: $CF_API_EMAIL" \
#    -H "X-Auth-Key: $CF_API_KEY" \
#    -H "Content-Type: application/json" \
#    -d "{
#        \"type\":\"A\",\
#        \"name\":\"'$subdomain'\",\
#        \"content\":\"'$arecord'\",\
#        \"ttl\":3600,\
#        \"priority\":10,\
#        \"proxied\":'$proxied'\
#    }"'
#}


#echo "3"

function addSites () {
    while IFS= read -r site; do
        addSite
    done < <(grep -v '^ *#' < "$importlist")
}

function addSubDomainAs () {
    while IFS= read -r subdomain; do
        addSubDomainA
    done < <(grep -v '^ *#' < "$importlist")
}

function addSubDomainCs () {
    while IFS= read -r subdomain; do
        addSubDomainC
    done < <(grep -v '^ *#' < "$importlist")
}

function usage() {
    printf "
%s
                   _                 _  __ _
                  | |               | |/ _| |
               ___| | ___  _   _  __| | |_| | __ _ _ __ ___
              / __| |/ _ \| | | |/ _\` |  _| |/ _\` | \'__/ _ \\
             | (__| | (_) | |_| | (_| | | | | (_| | | |  __/
              \___|_|\___/ \__,_|\__,_|_| |_|\__,_|_|  \___|
               %s=============================================
              %sC  O  N  T  R  O  L  %s/%s * %s\%s  S  C  R  I  P  T%s

    You need to specify parameters and arguments to use this script.

    Add an A record to a pre-existing site:
        %s cfcontrol %s-A%s subdomain.sitedomain.co.uk%s 122.222.211.212%s

    Add a CNAME record to a pre-existing site:
        %s cfcontrol %s-C%s subdomain.sitedomain.co.uk %s target.domain.com%s

    Use Cloudflare Proxy:
        %s cfcontrol %s-A%s subdomain.sitedomain.co.uk%s 122.222.211.212%s +proxy%s

    Create a new site:
        %s cfcontrol %s-S%s mynewsite.com%s

    You can bulk import any record type by using a .txt or .csv file after the parameter flag:
        %s cfcontrol %s-A%s /home/subdomains.txt%s


    %s" "$MAGENTA" "$RED" "$WHITE" "$RED" "$BLUE" "$RED" "$WHITE" "$RESET" \
    "$MAGENTA" "$RESET" "$RED" "$CYAN" "$RESET" "$MAGENTA" "$RESET" \
    "$RED" "$CYAN" "$RESET" "$MAGENTA" "$RESET" "$RED" "$CYAN" "$YELLOW" \
    "$RESET" "$MAGENTA" "$RESET" "$RED" "$RESET" "$MAGENTA" "$RESET" "$RED" \
    "$MAGENTA" "$RESET"
}

#echo "5"

case "$1" in
    -A)
        newarecord="$2"
        subdomain=$(echo "$newarecord" | sed 's/\([a-zA-Z0-9_\-]\)\..*/\1/')
        sitedomain=$(echo "$newarecord"| cut -d . -f 2-)
        arecord="$3"
        #echo $arecord is the IP. $subdomain is sub and $sitedomain is site
        getZone
        #echo $sitedomain
        #echo $ACCOUNT_ID
        #echo $zoneid
        if [[ $2 = "*.txt" ]]; then
            importlist="$2"
            addSubDomainAs
        else
            declare -V fullstring
            fullstring=( "$@" )
            proxied=$( [[ "${fullstring[*]}" =~ " +proxy" ]] && echo "true" || echo "false" )
            addSubDomainA
            
        fi
        
        exit 0
    ;;
    -C)
        subdomain=$(echo "$cnamerecord" | sed 's/\([a-zA-Z0-9_\-]\)\..*/\1/')
        sitedomain=$(echo "$cnamerecord" | cut -d . -f 2-)
        cnamerecord="$2"
        if [[ $2 =~ "txt" ]]; then
            importlist="$2"
            addSubDomainCs
        else
            addSubDomainC
        fi
        exit 0
    ;;
    -S)
        site="$1"
        if [[ $2 =~ "txt" ]]; then
            importlist="$2"
            addSites
        else
            addSite
        fi
        exit 0
    ;;
    
    "" | * )
        usage
    ;;
esac

exit