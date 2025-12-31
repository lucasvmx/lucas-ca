#!/bin/bash

# Diretório raiz da CA
CA_DIR="./DelcoreCA"

# Pastas de destino dentro da CA
CLIENTS_DIR="$CA_DIR/clients"
ISSUED_DIR="$CA_DIR/issued"

if [ ! -f "$CA_DIR/ca.conf" ]; then
  echo "Erro: Não encontrei a configuração da CA em $CA_DIR/ca.conf"
  echo "Execute primeiro o script create_root_ca.sh"
  exit 1
fi

if [ -z "$1" ]; then
  echo "Uso: $0 nome-do-cliente [email:usuario@exemplo.com]"
  echo "Exemplo: $0 joao joao@delcore.com"
  exit 1
fi

CLIENT_NAME="$1"
EMAIL="$2"

# Sufixo para evitar conflitos e identificar origem
CA_SUFFIX="delcore"

# Nome base dos arquivos
BASE_NAME="${CLIENT_NAME}-${CA_SUFFIX}"

# Cria pastas de destino, se não existirem
mkdir -p "$CLIENTS_DIR" "$ISSUED_DIR"

# Config temporária (será removida no final)
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

# 1. Gera chave privada
openssl genrsa -out "$CLIENTS_DIR/${BASE_NAME}.key" 2048 || { echo "Erro ao gerar chave"; exit 1; }

# 2. Gera CSR
openssl req -new -key "$CLIENTS_DIR/${BASE_NAME}.key" -out "/tmp/${BASE_NAME}.csr" -config "$CLIENT_CONF" || { echo "Erro ao gerar CSR"; exit 1; }

# 3. Assina com a CA raiz
openssl ca -config "$CA_DIR/ca.conf" \
    -extensions usr_cert \
    -days 730 \
    -notext \
    -md sha256 \
    -in "/tmp/${BASE_NAME}.csr" \
    -out "$CLIENTS_DIR/${BASE_NAME}.crt"

if [ $? -ne 0 ]; then
  echo "Erro ao assinar o certificado. Verifique a senha da CA."
  rm -f "/tmp/${BASE_NAME}.csr" "$CLIENT_CONF"
  exit 1
fi

# 4. Cópia do certificado público para pasta de emitidos (opcional, útil para distribuição)
cp "$CLIENTS_DIR/${BASE_NAME}.crt" "$ISSUED_DIR/"

# 5. Exporta para PKCS#12 (.p12) – arquivo principal para o usuário final
echo "Exportando para PKCS#12 (.p12)..."
openssl pkcs12 -export \
    -out "$CLIENTS_DIR/${BASE_NAME}.p12" \
    -inkey "$CLIENTS_DIR/${BASE_NAME}.key" \
    -in "$CLIENTS_DIR/${BASE_NAME}.crt" \
    -certfile "$CA_DIR/ca/certs/ca.cert.pem" \
    -name "$CLIENT_NAME" \
    -passout pass:   # usuário define senha ao importar (mais prático)

if [ $? -ne 0 ]; then
  echo "Erro ao exportar .p12"
  exit 1
fi

# 6. Limpeza de arquivos temporários
rm -f "/tmp/${BASE_NAME}.csr" "$CLIENT_CONF"

# 7. Permissões seguras
chmod 400 "$CLIENTS_DIR/${BASE_NAME}.key"          # só leitura para owner
chmod 444 "$CLIENTS_DIR/${BASE_NAME}.crt"          # legível por todos
chmod 444 "$CLIENTS_DIR/${BASE_NAME}.p12"          # legível por todos
chmod 444 "$ISSUED_DIR/${BASE_NAME}.crt"

echo ""
echo "=================================================================="
echo "Certificado cliente gerado com sucesso!"
echo ""
echo "Arquivos salvos em: $CLIENTS_DIR/"
echo "  • ${BASE_NAME}.key   → Chave privada (mantenha em local seguro!)"
echo "  • ${BASE_NAME}.crt   → Certificado público"
echo "  • ${BASE_NAME}.p12   → Arquivo para entregar ao usuário final"
echo ""
echo "Cópia pública também em: $ISSUED_DIR/${BASE_NAME}.crt"
echo ""
echo "Instruções para o usuário:"
echo "  - Entregue apenas o arquivo ${BASE_NAME}.p12"
echo "  - Peça para importar no navegador/sistema operacional"
echo "  - Definir uma senha forte durante a importação"
echo "=================================================================="