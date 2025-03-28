#!/bin/bash

create_k8s_user() {
    local USERNAME=$1
    local GROUPS=$2

    KEY_FILE="${USERNAME}.key"
    CSR_FILE="${USERNAME}.csr"
    CRT_FILE="${USERNAME}.crt"
    CSR_NAME="${USERNAME}-csr"

    openssl genrsa -out "${KEY_FILE}" 2048
    openssl req -new -key "${KEY_FILE}" -out "${CSR_FILE}" -subj "/CN=${USERNAME}${GROUPS}"

    cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${CSR_NAME}
spec:
  request: $(cat ${CSR_FILE} | base64 | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages:
  - client auth
EOF

    kubectl certificate approve ${CSR_NAME}
    kubectl get csr ${CSR_NAME} -o jsonpath='{.status.certificate}' | base64 --decode > "${CRT_FILE}"
    kubectl config set-credentials "${USERNAME}" --client-key="${KEY_FILE}" --client-certificate="${CRT_FILE}" --embed-certs=true
    kubectl config set-context "${USERNAME}-context" --cluster=$(kubectl config current-context | cut -d/ -f2) --user="${USERNAME}"
}

create_k8s_user developer-user "/O=developers"
create_k8s_user security-user "/O=security,O=developers"
create_k8s_user devops-admin-user "/O=devops"
