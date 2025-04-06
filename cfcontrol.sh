#!/bin/bash

## var declaration
declare proxy
declare output
declare zoneid

fullstring=( "$@" )
echo "${fullstring[*]}"
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

function fetchAccountId() {
    local url="https://api.cloudflare.com/client/v4/accounts"
    local response=$(curl -s -X GET "$url" \
        -H "X-Auth-Email: ${CF_API_EMAIL}" \
        -H "X-Auth-Key: ${CF_API_KEY}" \
        -H "Content-Type: application/json")
    ACCOUNT_ID=$(echo "$response" | jq -r '.result[0].id')
}

function addSite () {
    fetchAccountId
    output=$(curl -s -X POST \
    -H "X-Auth-Key: $CF_API_KEY" \
    -H "X-Auth-Email: $CF_API_EMAIL" \
    -H "Content-Type: application/json" "https://api.cloudflare.com/client/v4/zones" \
    -d "{\
        \"account\":{\
            \"id\":\"$ACCOUNT_ID\"\
            },\
        \"name\":\"$site\",\
        \"jump_start\":true\
    }"
)
results "$output"
}

addSubDomainA () {
    local subdomain="$1"
    local site="$2"
    local ip="$3"
    echo "IP:           $ip"
    echo "Sub-Domain:   $subdomain"
    echo "Site:         ${site}"
    getZone "$site"
    echo "Zone ID: ${zoneid}"
    output=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${zoneid}/dns_records" \
        -H "X-Auth-Email: ${CF_API_EMAIL}" \
        -H "X-Auth-Key: ${CF_API_KEY}" \
        -H "Content-Type: application/json" \
        -d '{
            "type":"A",
            "name":"'$subdomain'",
            "content":"'$ip'",
            "ttl":3600,
            "priority":10,
            "proxied":'$proxy'
            }'
    )
    thisrecord="arecord"
    output=$(echo "$output")
    results "$output"
}

function addSubDomainC () {
    local subdomain="$1"
    local site="$2"
    local cnamerecord="$3"
    getZone "$site"
    local url="https://api.cloudflare.com/client/v4/zones/${zoneid}/dns_records"
    output=$(curl -s -X POST "$url" \
        -H "X-Auth-Email: $CF_API_EMAIL" \
        -H "X-Auth-Key: $CF_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "type":"CNAME",
            "name":"'"$subdomain"'",
            "content":"'"$cnamerecord"'",
            "ttl":3600,
            "priority":10,
            "proxied":'"$proxy"'
        }'
    )
    thisrecord="cnamerecord"
    results "$output"
}

function listDnsRecords() {

    local domain="$2"
    local record_type="$1"
    getZone "$domain"
    local url="https://api.cloudflare.com/client/v4/zones/${zoneid}/dns_records"
    if [[ $debug -eq 1 ]]; then
        echo "DEBUG listDnsRecords:"
        echo "Zone ID: $zoneid"
    fi
    if [[ -n "$record_type" ]]; then
        url="${url}"
    fi

    output=$(curl -s -X GET "$url" \
        -H "X-Auth-Email: ${CF_API_EMAIL}" \
        -H "X-Auth-Key: ${CF_API_KEY}" \
        -H "Content-Type: application/json")

    # Parse JSON and convert to table
    echo "ID | TYPE | NAME | CONTENT | TTL | PROXIED"
    echo "-------------------------------------------"
    echo "$output" | jq -r '.result[] | "\(.id) | \(.type) | \(.name) | \(.content) | \(.ttl) | \(.proxied)"'
    echo ""
    echo ""
    echo "${output}"
}

proxyFlag() {
    if [[ "${fullstring[*]}" =~ "-proxy" ]]; then
      proxy=true
    else
      proxy=false
    fi
    echo "${fullstring[*]}"
    echo "Proxy:  ${proxy}"
}

formatting() {
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
}

getZone() {
    site=$1
    url="https://api.cloudflare.com/client/v4/zones?name=${site}&status=active&account.id=${ACCOUNT_ID}&page=1&per_page=100&order=status&direction=desc&match=all"
    output=$(curl -s -X GET "$url" \
        -H "X-Auth-Email: ${CF_API_EMAIL}" \
        -H "X-Auth-Key: ${CF_API_KEY}" \
    -H "Content-Type: application/json") 
    zoneid=$(echo "$output" | jq '.result[].id' | tr -d '"')
    echo "ZONE ID: ${zoneid}"
        if [[ $debug -eq 1 ]]; then
        echo DEBUG getZone:
        echo "Raw output:"
        echo "$output"
    fi
}

results() {
    output="${*}"
    echo "$output"
    success=$( [[ "$output" =~ "\"success\":true" ]] && echo "true" || echo "false" )
    proxyresult=$( [[ "$output" =~ "\"proxied\":true" ]] && echo "true" || echo "false" )
    if [[ $success == "true" ]]; then
        echo "The command completed successfully"
    else
        echo "The command did not complete successfully"
    fi
    if [[ $proxyresult == "true" ]]; then
        echo "${GREEN}Proxy enabled${WHITE}"
    fi
    if [[ "$thisrecord" == "arecord" || "$thisrecord" == "cnamerecord" ]]; then
        echo "${subdomain} now points to ${arecord}"
    fi
}

function sourceEnv() {
    ## Cloudflare Control Script for the management of domains using Cloudflare's API
    if [[ -e "${HOME}/.config/cfcontrol/.env" ]]; then
        # shellcheck source=./.env
        echo "Using ${HOME}/.config/cfcontrol/.env"
        source "${HOME}/.config/cfcontrol/.env"
    elif [[ -e "${HOME}/.cfcontrol/.env" ]]; then
        echo "Using ${HOME}/.cfcontrol/.env"
        source "${HOME}/.cfcontrol/.env"
    elif [[ -e "${PWD}/.env" ]]; then
        echo "Using ${PWD}/.env"
        source "${PWD}/.env"
    else
        echo "Did not find a .env file in ~/.config/cfcontrol/, ~/.cfcontrol/ or your current working directory."
        echo "Using defaults"
    fi
}



sourceSecrets() {
    local secretsfile="${SECRETS_FILE:-$HOME/.config/cfcontrol/.secrets}"
    local found=0
    fullstring=( "$@" )

    echo "Debug: Looking for secrets file at: $secretsfile"
    if [[ -e "$secretsfile" ]]; then
        echo "Debug: Found secrets file at: $secretsfile"
    else
        echo "Debug: Secrets file not found at: $secretsfile"
    fi

    # Check for -email and -apikey flags
    for ((i=0; i<${#fullstring[@]}; i++)); do
        if [[ "${fullstring[i]}" == "-email" && $((i+1)) -lt ${#fullstring[@]} ]]; then
            CF_API_EMAIL="${fullstring[i+1]}"
            echo "Debug: Email set from command line"
        elif [[ "${fullstring[i]}" == "-apikey" && $((i+1)) -lt ${#fullstring[@]} ]]; then
            CF_API_KEY="${fullstring[i+1]}"
            echo "Debug: API key set from command line"
        elif [[ "${fullstring[i]}" == "-secrets" && $((i+1)) -lt ${#fullstring[@]} ]]; then
            secretsfile="${fullstring[i+1]}"
            echo "Debug: Using custom secrets file: $secretsfile"
        fi
    done

    # If email and API key are not set, read from secrets file
    if [[ -z "$CF_API_KEY" || -z "$CF_API_EMAIL" ]]; then
        echo "Debug: API key or email not set, checking secrets files"
        # Try .secrets first
        if [[ -e "$secretsfile" ]]; then
            echo "Debug: Reading from $secretsfile"
            while read -r LINE; do
                if [[ $LINE != '#'* ]] && [[ $LINE == *'='* ]]; then
                    export "$LINE"
                    [[ $LINE == CF_API_KEY=* ]] && CF_API_KEY="${LINE#*=}"
                    [[ $LINE == CF_API_EMAIL=* ]] && CF_API_EMAIL="${LINE#*=}"
                fi
            done < "$secretsfile"
            found=1
            echo "Debug: Finished reading $secretsfile"
        elif [[ -e "${HOME}/.cfcontrol/.secrets" ]]; then
            echo "Debug: Reading from legacy location ${HOME}/.cfcontrol/.secrets"
            secretsfile="${HOME}/.cfcontrol/.secrets"
            while read -r LINE; do
                if [[ $LINE != '#'* ]] && [[ $LINE == *'='* ]]; then
                    export "$LINE"
                    [[ $LINE == CF_API_KEY=* ]] && CF_API_KEY="${LINE#*=}"
                    [[ $LINE == CF_API_EMAIL=* ]] && CF_API_EMAIL="${LINE#*=}"
                fi
            done < "$secretsfile"
            found=1
            echo "Debug: Finished reading legacy secrets file"
        fi
    fi

    # Prompt for credentials if still not set
    if [[ -z "$CF_API_KEY" || -z "$CF_API_EMAIL" ]]; then
        echo "No valid credentials file found in ~/.config/cfcontrol/.secrets or ~/.cfcontrol/.secrets"
        read -p "Would you like to enter your credentials now? (y/n): " choice
        if [[ "$choice" == "y" ]]; then
            read -p "Enter CF_API_KEY: " CF_API_KEY
            read -p "Enter CF_API_EMAIL: " CF_API_EMAIL
            mkdir -p "${HOME}/.config/cfcontrol"
            echo "CF_API_KEY=$CF_API_KEY" > "${HOME}/.config/cfcontrol/.secrets"
            echo "CF_API_EMAIL=$CF_API_EMAIL" >> "${HOME}/.config/cfcontrol/.secrets"
            export CF_API_KEY
            export CF_API_EMAIL
            echo "Credentials saved to ${HOME}/.config/cfcontrol/.secrets and exported."
        else
            echo "Exiting script."
            exit 1
        fi
    fi

    if [[ $debug -eq 1 ]]; then
        echo "sourceSecrets:"
        echo "CF_API_KEY is set: $([[ -n "$CF_API_KEY" ]] && echo "yes" || echo "no")"
        echo "CF_API_EMAIL is set: $([[ -n "$CF_API_EMAIL" ]] && echo "yes" || echo "no")"
    fi
}

# Example usage:
# sourceSecrets /path/to/your/secretsfile

testFunction() {
    sourceSecrets
    echo "fullstring: ${fullstring[@]}"
    echo "uncomment test values as required"
#    echo "Subdomain: $subdomain"
    echo "Site Domain: $sitedomain to $arecord"
    echo "API Key: $CF_API_KEY"
    echo "API Email: $CF_API_EMAIL"
    echo "Zone ID: ${zoneid}"
    
}

function headerGraphic() {
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
    " "$MAGENTA" "$RED" "$WHITE" "$RED" "$BLUE" "$RED" "$WHITE" "$RESET"
}

function usage() {
    headerGraphic
    printf "
    You need to specify parameters and arguments to use this script.

    Add an A record to a pre-existing site:
        %s cfcontrol %s-A%s subdomain.sitedomain.co.uk%s 122.222.211.212%s [flags]%s

    Add a CNAME record to a pre-existing site:
        %s cfcontrol %s-C%s subdomain.sitedomain.co.uk %starget.domain.com%s [flags]%s

    Create a new site:
        %s cfcontrol %s-S%s mynewsite.com%s [optional flags]%s

    You can bulk import any record type by using a .txt or .csv file after the -A or -C specifier:
        %s cfcontrol %s-A%s /home/subdomains.txt%s [flags]%s

    Return a list of recrods:
        %s cfcontrol %s-L%s sites
        %s cfcontrol %s-L%s dns%s <domain> %s[optional flags]%s

    Additional features and debugging can be enabled by appending flags to the end of your command:
        %s -proxy%s              Toggles Cloudflare Proxy (works with A and C records only)
        %s -overwrite%s          Overwrite (modify) record if it already exists        
        %s -debug%s              Enable debugging to the console
        %s -email%s   <email>%s    Enter your Cloudflare email credential as part of the command
        %s -apikey%s  <apikey>%s   Enter your Cloudflare API key as part of the command
        %s -secrets%s <file>%s     Specify path of file containing CF_API_EMAIL and CF_API_KEY

    %s" "$MAGENTA" "$RESET" "$RED" "$CYAN" "$WHITE" "$RESET" \
    "$MAGENTA" "$RESET" "$RED" "$CYAN" "$WHITE" "$RESET" \
    "$MAGENTA" "$RESET" "$RED" "$WHITE" "$RESET" \
    "$MAGENTA" "$RESET" "$RED" "$WHITE" "$RESET" \
    "$MAGENTA" "$RESET" "$RED" "$CYAN" "$RESET" \
    "$WHITE" "$RESET" \
    "$WHITE" "$RESET" \
    "$WHITE" "$RESET" \
    "$WHITE" "$CYAN" "$RESET" \
    "$WHITE" "$CYAN" "$RESET"
}

function handleARecord() {
    headerGraphic
    echo "A RECORD"
    if [[ "$2" =~ "*.txt" || "$2" =~ "*.csv" ]]; then
        local file="$2"
        local bulk=1
    else
        local fqdn="$2"
        local bulk=0
    fi
    if [[ $bulk -eq 1 ]]; then
        echo "Bulk file import specified."
        addSubDomainAs "$file"
    else
        local ip="$3"
        local subdomain=$(echo "$fqdn" | sed 's/\([a-zA-Z0-9_\-]\)\..*/\1/')
        local site=$(echo "$fqdn" | cut -d . -f 2-)
        echo "Single record specified."
        proxyFlag
        addSubDomainA "$subdomain" "$site" "$ip"
    fi
}

function handleCRecord() {
    local fqdn="$2"
    local cnamerecord="$3"
    local subdomain=$(echo "$fqdn" | sed 's/\([a-zA-Z0-9_\-]\)\..*/\1/')
    local site=$(echo "$fqdn" | cut -d . -f 2-)
    headerGraphic
    echo "CNAME RECORD"
    
    if [[ $debug -eq 1 ]]; then
        echo "DEBUG handleCRecord:"
        echo "cnamerecord=$cnamerecord"
        echo "subdomain=$subdomain"
        echo "site=$site"
    fi

    if [[ $2 =~ "txt" || $2 =~ "csv" ]]; then
        importlist="$2"
        echo "Bulk file import specified."
        addSubDomainCs
    else
        echo "Single record specified."
        proxyFlag
        addSubDomainC "$subdomain" "$site" "$cnamerecord"
    fi
}

function handleSite() {
    local site="$2"
    headerGraphic
    echo "SITE"
    if [[ $3 =~ "txt" || $3 =~ "csv" ]]; then
        importlist="$2"
        echo "Bulk file import specified."
        addSites
    else
        echo "Single record specified."
        addSite
    fi
}

handleListDnsRecords() {
    local domain="$3"
    local record_type="$2"
    headerGraphic
    echo "LIST DNS RECORDS"
    if [[ $debug -eq 1 ]]; then
        echo "DEBUG:"
        echo "domain=$domain"
        echo "record_type=$record_type"
    fi
    listDnsRecords "$record_type" "$domain"
}

function handleListSites() {
    headerGraphic
    echo "LIST SITES"
    # Add your logic to list sites here
}

function detectDebugFlag() {
    debug=0
    if [[ " ${fullstring[*]} " =~ " -debug " ]]; then
        debug=1
        echo "DEBUGGING IS ON"
    fi
    echo "detectDebugFlag ran"
    echo debug="$debug"
    echo fullstring="${fullstring[*]}"
}
formatting
sourceEnv
sourceSecrets "${fullstring[@]}"
detectDebugFlag "${fullstring[@]}"
case "$1" in
    -A)
        handleARecord "${fullstring[@]}"
        exit 0
    ;;
    -C)
        handleCRecord "${fullstring[@]}"
        exit 0
    ;;
    -S)
        handleSite "${fullstring[@]}"
        exit 0
    ;;
    -L)
        case "$2" in
            dns)
                handleListDnsRecords "${fullstring[@]}"
                ;;
            site)
                handleListSites "${fullstring[@]}"
                ;;
            *)
                echo "Invalid list type. Use 'dns' or 'site'."
                usage
                ;;
        esac
        exit 0
    ;;
    -test)
        testFunction "${fullstring[@]}"
        exit
    ;;
    "" | * )
        usage
    ;;
esac

exit