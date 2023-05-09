#!/bin/bash

USAGE="Usage: $0 target.ip or target.ip/cidr"

function cleanup {
    echo -e "\n${red} Leaving..."
    if [ ! -z ${pid} ]; then
        kill -9 ${pid} 2>/dev/null
    fi
    exit 1
}

trap cleanup INT

# Parse command line arguments
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -h|--help)
    echo "${USAGE}"
    exit 0
    ;;
    *)
    # Check if the argument is a valid IP or IP with CIDR
    if ! echo "$1" | egrep -q '^([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?$'; then
        echo -e "${red} Invalid IP address or IP with CIDR: $1"
        exit 1
    fi
    TARGET="$1"
    shift
    ;;
esac
done

if [ -z "${TARGET}" ]; then
    echo "${USAGE}"
    exit 1
fi

BANNER="
    ____  ____  ____  _____ __  ______  ____  ______
   / __ \/ __ \/ __ \/ ___// / / / __ \/ __ \/_  __/
  / /_/ / / / / /_/ /\__ \/ /_/ / / / / / / / / /   
 / _, _/ /_/ / ____/___/ / __  / /_/ / /_/ / / /    
/_/ |_/_____/_/    /____/_/ /_/\____/\____/ /_/     
                                     by Shockz
"

echo -e "${BANNER}"

# Configurable options
timeout=60
timeoutStep=1
blue="\e[34m[*]\e[0m"
red="\e[31m[*]\e[0m"
green="\e[32m[*]\e[0m"
timestamp=$(date +"%Y-%m-%d_%H-%M")
output="output/${timestamp}"

function screenshot {
    screenshot=$1
    window=$2
    echo -e "${blue} Saving screenshot to ${screenshot}"
    import -window ${window} "${screenshot}"
}

function isAlive {
    pid=$1
    kill -0 $pid 2>/dev/null
    if [ $? -eq 1 ]; then
        echo -e "${red} Process died, failed to connect to ${TARGET}, NLA might be enabled on the server!"
    fi
}

function ocr {
	echo -e "${blue} Converting image to B/W and running OCR for ${h}"
	convert "/tmp/${h}.png" -grayscale Rec709Luminance -resample 300x300 -unsharp 6.8x2.69 -quality 100 "/tmp/${h}.png" 
	tesseract "/tmp/${h}.png" "${output}/${h}" --oem 1 --psm 3 batch.nochop 1>/dev/null 2>&1
	echo -e "${green} OCR output saved in: ${output}/${h}.txt"
}

mkdir -p "${output}"

echo -e "${blue} Finding hosts with RDP enabled and NLA disabled"

nmap_output=$(nmap -Pn -p 3389 -T4 -n --open --script 'rdp-enum-encryption' $TARGET)

str=$(echo "$nmap_output" | sed ':a;N;$!ba;s/\n/@@/g' | tr -d '[:space:]')
substr=($(echo $str | awk -F"Nmapscanreportfor" '{for(i=2;i<=NF;i++) print $i}'))

hosts=()

for i in "${substr[@]}"; do
  elem=$(echo $i | sed 's/://g')
  ip_address=$(echo "$elem" | cut -d'@' -f1)
  if echo "$elem" | grep -q "CredSSP(NLA)SUCCESS"; then
    if echo "$elem" | grep -q "SSLSUCCESS"; then
      hosts+=("$ip_address")
    fi
  else
    hosts+=("$ip_address")
  fi
done

if [ -z "$hosts" ]; then
    echo -e "${red} No active hosts were found with RDP enabled and NLA disabled in ${TARGET}"
    exit 1
fi

echo -e "${green} IP addresses to be processed that have RDP enabled and NLA disabled:"

# Table with IPs

echo "|-----------------------------------|"
echo "|HOST                 | PORT        |"
echo "|-----------------------------------|"
for host in "${hosts[@]}"; do
    printf "|%-21s| %-12s|\n" "$host" "3389"
done

echo "|-----------------------------------|"

echo -e "${green} IPs saved in ${output}/ips.txt"

echo "$hosts" > ${output}"/ips.txt"

for h in $hosts; do

    # Check if image and OCR files already exist
    if [ -f "${output}/${h}.png" ] && [ -f "${output}/${h}.txt" ]; then
        echo -e "${green} Skipping ${h}: Image and OCR output files already exist"
        continue
    fi

    # Launch rdesktop in the background
    echo -e "${blue} Initiating rdesktop connection to ${h}"
    echo "yes" | rdesktop -u "" -a 16 "${h}" &
    pid=$!

    # Get window id
    window=
    timer=0
    while true; do
        # Check to see if the process is still alive
        isAlive $pid

        # Get the window ID
        window=$(xdotool search --name "${h}")

        if [ ! "${window}" = "" ]; then
            echo -e "${blue} Got window id: ${window}"
            break
        fi
        timer=$(echo "${timer} + 0.1" | bc)
        sleep 0.1
    done

    # If the screen is all black delay timeoutStep seconds
    # Set the timeout to 30 seconds
    timeout=30
    startTime=$(date +%s)

    temp="/tmp/${h}.png"
    while true; do
        # Make sure the process didn't die
        isAlive $pid

        # Check if we've timed out
        elapsedTime=$(( $(date +%s) - ${startTime} ))
        if [ ${elapsedTime} -ge ${timeout} ]; then
            echo -e "${red} Timed out waiting for desktop to load"
            break
        fi

        # Screenshot the window and if the only one color is returned (black), give it chance to finish loading
        screenshot "${temp}" "${window}"
        colors=$(convert "${temp}" -colors 5 -unique-colors txt:- | grep -v ImageMagick)
        if [ $(echo "${colors}" | wc -l) -eq 1 ]; then
            echo -e "${blue} Waiting on desktop to load"
            sleep $timeoutStep
        else
            # Many colors should mean we've got a console loaded
            echo -e "${green} Console Loaded for ${h}"
            break
        fi
    done

    # Save image
    afterScreenshot="${output}/${h}.png"
    screenshot "${afterScreenshot}" "${window}"

    # Run OCR on saved image
    ocr "${h}"

    # Delete temp files
    rm ${temp}

    # Close the rdesktop window
    kill $pid
done

echo -e "${blue} Getting users"
for file in "${output}"/*.txt; do cat "${file}" | tr '\n' ' ' | grep -oaE '[[:alnum:]\.-]+\s*\\s*[[:alnum:]\.-]+' | sed 's/ //g' >> "${output}"/users.txt; done
echo -e "${green} Users saved in {output}/users.txt"