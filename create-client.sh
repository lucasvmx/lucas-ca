#!/bin/bash

# Script para gerar certificados cliente compatível com a estrutura flexível da CA

# Função para encontrar a pasta raiz da CA (procura ca.conf subindo diretórios)
find_ca_root() {
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/ca/ca.conf" ]]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

# Determina a pasta raiz da CA
if [[ -n "$1" && -f "$1/ca/ca.conf" ]]; then
  # Argumento passado e válido
  CA_ROOT="$(realpath "$1")"
  shift  # consome o argumento
elif [[ -n "$1" && "$1" == "-h" || "$1" == "--help" ]]; then
  echo "Uso: $0 [pasta/raiz/da/CA] nome-do-cliente [email]"
  echo ""
  echo "Exemplos:"
  echo "  $0 joao joao@delcore.com                     → procura automaticamente"
  echo "  $0 ./DelcoreCA joao                          → especifica o caminho"
  echo "  $0 /etc/pki/DelcoreCA maria maria@exemplo.com"
  echo ""
  exit 0
else
  # Procura automaticamente
  if CA_ROOT=$(find_ca_root); then
    echo "CA encontrada automaticamente em: $CA_ROOT"
  else
    echo "Erro: Não encontrei a pasta da CA (arquivo ca/ca.conf não localizado)."
    echo "Execute o script dentro ou próximo da pasta da CA, ou informe o caminho como primeiro argumento."
    exit 1
  fi
fi

# Pastas de trabalho
CLIENTS_DIR="$CA_ROOT/clients"
ISSUED_DIR="$CA_ROOT/issued"
CONFIG_FILE="$CA_ROOT/ca/ca.conf"

# Verifica existência das pastas
mkdir -p "$CLIENTS_DIR" "$ISSUED_DIR"

# Argumentos restantes: nome do cliente e email
if [[ -z "$1" ]]; then
  echo "Erro: Nome do cliente não informado."
  echo "Uso: $0 [pasta/da/CA] nome-do-cliente [email]"
  exit 1
fi

CLIENT_NAME="$1"
EMAIL="$2"

# Sufixo para identificar origem
CA_SUFFIX="delcore"
BASE_NAME="${CLIENT_NAME}-${CA_SUFFIX}"

# Arquivo temporário de configuração
CLIENT_CONF="/tmp/${BASE_NAME}.conf"

cat <<EOF > "$CLIENT_CONF"
[ req ]
default_bits        = 2048
distinguished_name  = req_distinguished_name
req_extensions      = req_ext
prompt              = no

[ req_distinguished_name ]
C                   = BR
ST                  = DF
O                   = Delcore
CN                  = $CLIENT_NAME
emailAddress        = ${EMAIL:-}

[ req_ext ]
extendedKeyUsage    = clientAuth
EOF

echo "Gerando certificado cliente para: $CLIENT_NAME"
echo "Arquivos serão salvos em: $CLIENTS_DIR/"

# 1. Chave privada
openssl genrsa -out "$CLIENTS_DIR/${BASE_NAME}.key" 2048 || { echo "Erro ao gerar chave privada"; exit 1; }

# 2. CSR
openssl req -new -key "$CLIENTS_DIR/${BASE_NAME}.key" -out "/tmp/${BASE_NAME}.csr" -config "$CLIENT_CONF" \
  || { echo "Erro ao gerar CSR"; exit 1; }

# 3. Assina com a CA
openssl ca -config "$CONFIG_FILE" \
    -extensions usr_cert \
    -days 730 \
    -notext \
    -md sha256 \
    -in "/tmp/${BASE_NAME}.csr" \
    -out "$CLIENTS_DIR/${BASE_NAME}.crt"

if [[ $? -ne 0 ]]; then
  echo "Erro ao assinar o certificado. Verifique a senha da CA."
  rm -f "/tmp/${BASE_NAME}.csr" "$CLIENT_CONF"
  exit 1
fi

# 4. Cópia para pasta de emitidos
cp "$CLIENTS_DIR/${BASE_NAME}.crt" "$ISSUED_DIR/"

# 5. Exporta .p12 (arquivo para distribuição)
echo "Exportando PKCS#12 (.p12)..."
openssl pkcs12 -export \
    -out "$CLIENTS_DIR/${BASE_NAME}.p12" \
    -inkey "$CLIENTS_DIR/${BASE_NAME}.key" \
    -in "$CLIENTS_DIR/${BASE_NAME}.crt" \
    -certfile "$CA_ROOT/ca/certs/ca.cert.pem" \
    -name "$CLIENT_NAME" \
    -passout pass:  # senha vazia na exportação → usuário define ao importar

if [[ $? -ne 0 ]]; then
  echo "Erro ao exportar .p12"
  exit 1
fi

# 6. Limpeza
rm -f "/tmp/${BASE_NAME}.csr" "$CLIENT_CONF"

# 7. Permissões
chmod 400 "$CLIENTS_DIR/${BASE_NAME}.key"
chmod 444 "$CLIENTS_DIR/${BASE_NAME}.crt"
chmod 444 "$CLIENTS_DIR/${BASE_NAME}.p12"
chmod 444 "$ISSUED_DIR/${BASE_NAME}.crt"

echo ""
echo "=================================================================="
echo "Certificado cliente gerado com sucesso!"
echo ""
echo "Pasta da CA: $CA_ROOT"
echo "Arquivos salvos em: $CLIENTS_DIR/"
echo "  • ${BASE_NAME}.key   → Chave privada (mantenha segura!)"
echo "  • ${BASE_NAME}.crt   → Certificado público"
echo "  • ${BASE_NAME}.p12   → Arquivo para entregar ao usuário"
echo ""
echo "Cópia pública em: $ISSUED_DIR/${BASE_NAME}.crt"
echo ""
echo "Instruções ao usuário:"
echo "  - Entregue apenas o arquivo ${BASE_NAME}.p12"
echo "  - Importe no navegador ou sistema operacional"
echo "  - Defina uma senha forte durante a importação"
echo "=================================================================="