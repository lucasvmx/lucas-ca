#!/bin/bash

# Script para criar a Autoridade Certificadora (CA) raiz em um local escolhido pelo usuário

# Função de ajuda
show_help() {
  echo "Uso: $0 [caminho/da/pasta/raiz_da_ca]"
  echo ""
  echo "Exemplos:"
  echo "  $0                              → pergunta interativamente"
  echo "  $0 ./MinhaCA                    → cria em ./MinhaCA"
  echo "  $0 /etc/pki/DelcoreCA           → cria em /etc/pki/DelcoreCA (precisa de sudo)"
  echo "  $0 ~/Documentos/DelcoreCA       → cria em pasta pessoal"
  echo ""
  exit 1
}

# Verifica se pediu ajuda
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  show_help
fi

# Determina o diretório raiz da CA
if [ -n "$1" ]; then
  CA_ROOT="$(realpath "$1")"   # usa o caminho passado
else
  # Pergunta interativamente
  echo "Onde você deseja criar a pasta raiz da sua Autoridade Certificadora?"
  read -p "Caminho (ex: ./DelcoreCA ou /etc/pki/DelcoreCA): " CA_ROOT
  CA_ROOT="$(realpath "$CA_ROOT")"
fi

# Verifica se o diretório já existe
if [ -d "$CA_ROOT" ]; then
  if [ "$(ls -A "$CA_ROOT" 2>/dev/null)" ]; then
    echo "Erro: A pasta $CA_ROOT já existe e não está vazia."
    echo "Escolha outro local ou remova o conteúdo existente."
    exit 1
  fi
fi

echo "Criando Autoridade Certificadora (CA) raiz em: $CA_ROOT"
echo "========================================================"

# Cria estrutura de diretórios
mkdir -p "$CA_ROOT/ca/private" "$CA_ROOT/ca/certs" "$CA_ROOT/ca/newcerts"
mkdir -p "$CA_ROOT/clients" "$CA_ROOT/servers" "$CA_ROOT/issued"

touch "$CA_ROOT/ca/index.txt"
echo 1000 > "$CA_ROOT/ca/serial"

# Arquivo de configuração da CA
CONFIG_FILE="$CA_ROOT/ca/ca.conf"

cat <<EOF > "$CONFIG_FILE"
[ ca ]
default_ca = CA_default

[ CA_default ]
dir             = ./ca
certs           = \$dir/certs
new_certs_dir   = \$dir/newcerts
database        = \$dir/index.txt
serial          = \$dir/serial
private_key     = \$dir/private/ca.key.pem
certificate     = \$dir/certs/ca.cert.pem
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

[ usr_cert ]
extendedKeyUsage = clientAuth
EOF

# Gera chave privada da CA (protegida por senha)
openssl genrsa -aes256 -out "$CA_ROOT/ca/private/ca.key.pem" 4096

echo "Chave privada gerada. Você será solicitado a digitar uma senha forte no próximo passo."

# Gera certificado raiz autoassinado (10 anos)
openssl req -config "$CONFIG_FILE" -new -x509 -days 3650 \
    -key "$CA_ROOT/ca/private/ca.key.pem" -sha256 \
    -extensions v3_ca -out "$CA_ROOT/ca/certs/ca.cert.pem"

# Protege arquivos sensíveis
chmod 400 "$CA_ROOT/ca/private/ca.key.pem"
chmod 700 "$CA_ROOT/ca/private"

echo ""
echo "=================================================================="
echo "CA Raiz criada com sucesso!"
echo ""
echo "Pasta raiz da CA: $CA_ROOT"
echo ""
echo "Arquivos importantes:"
echo "  Chave privada:     $CA_ROOT/ca/private/ca.key.pem"
echo "  Certificado raiz:  $CA_ROOT/ca/certs/ca.cert.pem   ← distribua este"
echo "  Configuração:      $CA_ROOT/ca/ca.conf"
echo ""
echo "Estrutura criada:"
echo "  $CA_ROOT/clients/   → para certificados cliente"
echo "  $CA_ROOT/servers/   → para certificados de servidor"
echo "  $CA_ROOT/issued/    → cópias de certificados públicos emitidos"
echo "=================================================================="
echo "Próximos passos:"
echo "  - Distribua apenas o arquivo ca.cert.pem para confiar nos clientes."
echo "  - Use os scripts create_client_cert.sh e create_server_cert.sh"
echo "    (ajustados para ler automaticamente a pasta raiz via variável ou argumento)."
echo ""