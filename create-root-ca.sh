#!/bin/bash

# Nome da pasta da CA (relativa ao diretório atual)
CA_DIR="./DelcoreCA"

echo "Criando Autoridade Certificadora (CA) raiz em $CA_DIR..."

# Cria a estrutura de diretórios
mkdir -p "$CA_DIR/ca/private" "$CA_DIR/ca/certs" "$CA_DIR/ca/newcerts"
touch "$CA_DIR/ca/index.txt"
echo 1000 > "$CA_DIR/ca/serial"

# Arquivo de configuração da CA (dentro da pasta DelcoreCA)
CONFIG_FILE="$CA_DIR/ca.conf"

cat <<EOF > "$CONFIG_FILE"
[ ca ]
default_ca = CA_default

[ CA_default ]
dir             = $CA_DIR/ca
certs           = \$dir/certs
new_certs_dir   = \$dir/newcerts
database        = \$dir/index.txt
serial          = \$dir/serial
private_key     = \$dir/private/DelcoreCA.key.pem
certificate     = \$dir/certs/DelcoreCA.cert.pem
default_days    = 3650
default_md      = sha256
policy          = policy_strict

[ policy_strict ]
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
default_bits        = 4096
distinguished_name  = req_distinguished_name
x509_extensions     = v3_ca
prompt              = no

[ req_distinguished_name ]
C                   = BR
ST                  = DF
O                   = Delcore
OU                  = TI
CN                  = Delcore CA Raiz

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
EOF

# Gera a chave privada da CA (protegida por senha)
openssl genrsa -aes256 -out "$CA_DIR/ca/private/DelcoreCA.key.pem" 4096
echo "Chave privada gerada. Digite uma senha forte quando solicitado no próximo passo."

# Gera o certificado raiz autoassinado (válido por 10 anos)
openssl req -config "$CONFIG_FILE" -new -x509 -days 3650 \
    -key "$CA_DIR/ca/private/DelcoreCA.key.pem" -sha256 \
    -extensions v3_ca -out "$CA_DIR/ca/certs/DelcoreCA.cert.pem"

# Protege a chave privada
chmod 400 "$CA_DIR/ca/private/DelcoreCA.key.pem"
chmod 500 "$CA_DIR/ca/private"

echo ""
echo "=================================================================="
echo "CA Raiz criada com sucesso em $CA_DIR/"
echo ""
echo "Arquivos importantes:"
echo "  Chave privada:   $CA_DIR/ca/private/DelcoreCA.key.pem  (protegida por senha)"
echo "  Certificado raiz: $CA_DIR/ca/certs/DelcoreCA.cert.pem  ← distribua este para confiar nos clientes"
echo "  Configuração:    $CA_DIR/ca.conf"
echo "=================================================================="
echo "Próximos passos:"
echo "  - Distribua o DelcoreCA.cert.pem para os clientes que precisarão confiar na CA."
echo "  - Use os outros scripts (create_server_cert.sh e create_client_cert.sh)"
echo "    ajustando os caminhos para apontar para $CA_DIR/ca.conf e $CA_DIR/ca/certs/DelcoreCA.cert.pem"
echo ""