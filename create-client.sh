#!/bin/bash

# Diretório da CA (relativo ao local de execução do script)
CA_DIR="./DelcoreCA"

# Define o nome da CA
CA_NAME="delcore"

if [ ! -f "$CA_DIR/ca.conf" ]; then
  echo "Erro: Não encontrei a configuração da CA em $CA_DIR/ca.conf"
  echo "Certifique-se de que a CA foi criada com o script create_root_ca.sh"
  exit 1
fi

if [ -z "$1" ]; then
  echo "Uso: $0 nome-do-cliente [email:usuario@exemplo.com]"
  echo "Exemplo: $0 joao joao@exemplo.com"
  exit 1
fi

CLIENT_NAME=$1
EMAIL=$2

# Arquivo de configuração temporário para o cliente
CLIENT_CONF="$CLIENT_NAME.conf"

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

# 1. Gera chave privada do cliente
openssl genrsa -out "$CLIENT_NAME-$CA_NAME.key" 2048

# 2. Gera CSR (Certificate Signing Request)
openssl req -new -key "$CLIENT_NAME-$CA_NAME.key" -out "$CLIENT_NAME-$CA_NAME.csr" -config "$CLIENT_CONF"

# 3. Assina o certificado com a CA raiz (será solicitada a senha da CA)
openssl ca -config "$CA_DIR/ca.conf" \
    -extensions usr_cert \
    -days 730 \
    -notext \
    -md sha256 \
    -in "$CLIENT_NAME-$CA_NAME.csr" \
    -out "$CLIENT_NAME-$CA_NAME.crt"

# 4. Exporta para formato PKCS#12 (.p12) – ideal para importar em navegadores e apps
echo "Exportando para PKCS#12 (.p12)..."
openssl pkcs12 -export \
    -out "$CLIENT_NAME-$CA_NAME.p12" \
    -inkey "$CLIENT_NAME-$CA_NAME.key" \
    -in "$CLIENT_NAME-$CA_NAME.crt" \
    -certfile "$CA_DIR/ca/certs/DelcoreCA.cert.pem" \
    -name "$CLIENT_NAME"

# 5. Limpeza de arquivos intermediários
rm "$CLIENT_NAME-$CA_NAME.csr" "$CLIENT_CONF"

# 6. Define permissões seguras
chmod 400 "$CLIENT_NAME-$CA_NAME.key"
chmod 444 "$CLIENT_NAME-$CA_NAME.crt" "$CLIENT_NAME-$CA_NAME.p12"

echo ""
echo "=================================================================="
echo "Certificado cliente gerado com sucesso!"
echo ""
echo "Arquivos criados:"
echo "  • $CLIENT_NAME-$CA_NAME.key   → Chave privada (mantenha extremamente segura!)"
echo "  • $CLIENT_NAME-$CA_NAME.crt   → Certificado público"
echo "  • $CLIENT_NAME-$CA_NAME.p12   → Pacote para importação em navegadores/apps"
echo ""
echo "Instruções para o usuário final:"
echo "  - Importe o arquivo $CLIENT_NAME-$CA_NAME.p12 no navegador ou aplicativo."
echo "  - Será solicitada uma senha de exportação (defina uma forte ao importar)."
echo "  - Após importado, o navegador usará automaticamente esse certificado ao acessar sites com mTLS."
echo "=================================================================="