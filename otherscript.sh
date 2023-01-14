#!/bin/bash



while getopts "ai" options; do
    case ${options} in
      a)
       echo "7"
       ;;
      i)
       echo "8"
       ;;
    *)  echo "You need to specify a parameter"
       exit 0
       ;;
    "")
       echo "Nothing"
       exit 0
       ;;
      esac
      echo "12"
done
    echo "13"

    