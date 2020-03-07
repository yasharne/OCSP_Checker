#!/bin/bash

URL=$1
PORT=$2

if [ "$#" -ne 2 ]; then
    echo "Illegal number of parameters, e.g: ocsp_checker.sh wikipedia.org 443"
    exit
fi

if [[ "$URL" =~ "http" ]]; then
    echo "Enter URL without http or https. e.g: wikipedia.org"
    exit
fi

DESTINATION_CERT_FILE=$URL.pem

#Getting destination certificate
openssl s_client -connect $URL:$PORT 2>&1 < /dev/null | sed -n '/-----BEGIN/,/-----END/p' > $DESTINATION_CERT_FILE

#Checking if the certificate has OCSP uri
OCSP_ADDRESS=$(openssl x509 -noout -ocsp_uri -in $DESTINATION_CERT_FILE)

CHAIN_CERT_FILE=$URL.chain.pem

#Getting the certificate chain
openssl s_client -showcerts -connect $URL:$PORT < /dev/null 2>&1 |  sed -n '/-----BEGIN/,/-----END/p' > $CHAIN_CERT_FILE

TMP_CHAIN_CERT_FILE=$CHAIN_CERT_FILE.tmp

#Removing the webpage certificate from the chain
grep -Fvxf $DESTINATION_CERT_FILE $CHAIN_CERT_FILE > $TMP_CHAIN_CERT_FILE
mv $TMP_CHAIN_CERT_FILE $CHAIN_CERT_FILE

#Adding the HEADER and the FOOTER
sed -i '1s/^/-----BEGIN CERTIFICATE-----\n/' $CHAIN_CERT_FILE
sed -i "\$a-----END CERTIFICATE-----" $CHAIN_CERT_FILE

#Checking if certificate is revoked the output will be eithe "good" or "revoked"
STATUS=$(openssl ocsp -noverify -issuer $CHAIN_CERT_FILE -cert $DESTINATION_CERT_FILE -text -url $OCSP_ADDRESS | grep $DESTINATION_CERT_FILE | awk -F " " '{print $2}')

