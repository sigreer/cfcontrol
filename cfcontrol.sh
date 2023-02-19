#!/bin/bash
## Cloudflare Control Script for the management of domains using Cloudflare's API
source ./.env
source ./.secrets

function testFunction () {
    echo "Subdomain: $subdomain"
    echo "Site Domain: $sitedomain to $arecord"
    echo "API Key: $CF_API_KEY"
    echo "API Email: $CF_API_EMAIL"
    echo "Zone ID: ${zoneid}"
}

function getZone () {
zoneinfo=$(curl -X GET "https://api.cloudflare.com/client/v4/zones?name=${sitedomain}&status=active&account.id=${ACCOUNT_ID}&page=1&per_page=100&order=status&direction=desc&match=all" -H "X-Auth-Email: $CF_API_EMAIL" -H "X-Auth-Key: $CF_API_KEY" -H "Content-Type: application/json")
zoneid=$(echo $zoneinfo | jq '.result[].id' | tr -d '"')
}

function addsite () {
    curl -X POST -H "X-Auth-Key: $CF_API_KEY" -H "X-Auth-Email: $CF_API_EMAIL" -H "Content-Type: application/json" "https://api.cloudflare.com/client/v4/zones" --data "{\"account\":{\"id\":\"$ACCOUNT_ID\"},\"name\":\"$site\",\"jump_start\":true}"
}

function addSubDomainA () {
  curl -X POST "https://api.cloudflare.com/client/v4/zones/${zoneid}/dns_records" -H "X-Auth-Email: $CF_API_EMAIL" -H "X-Auth-Key: $CF_API_KEY" -H "Content-Type: application/json" --data "{\"type\":\"A\",\"name\":\"$subdomain\",\"content\":\"$arecord\",\"ttl\":3600,\"priority\":10,\"proxied\":false}"
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
    echo "You need to specify parameters and arguments to use this script."
    echo ""
    echo "   To add a domain A record, use the -A flag followed by the fully-qualified domain and the IP"
    echo "       example:"
    echo "          cfcontrol -A subdomain.sitedomain.co.uk 122.222.211.212"
    echo ""
    echo "   To add a CNAME record, use the -C flag followed by the source and target records as FQDNs"
    echo "       exammple:"
    echo "          cfcontrol -C subdomain.sitedomain.co.uk target.domain.com"
    echo ""
    echo "   To add a new site, use the -S flag followed by the site master domain"
    echo "       example:"
    echo "          cfcontrol -S mynewsite.com"
    echo ""
    echo "   To bulk import records from a text or CSV file, add the filename after any flag"
    echo "       example:"
    echo "           cfcontrol -A domains.txt"
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