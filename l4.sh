#!/bin/bash

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m'
DOMAIN=$1
VERBOSE=$2

if [ -z "$DOMAIN" ]; then
  echo -e "${RED}Uso: $0 <dominio> [--v] ${NC}"
  exit 1
fi

BASE_DOMAIN=$(echo $DOMAIN | sed -E 's/\.[a-z\.]{2,}$//')
RESULT_DIR="${BASE_DOMAIN}_result"
mkdir -p "$RESULT_DIR"

if [ ! -d "$RESULT_DIR" ]; then
  echo -e "${RED}[!] Erro ao criar diretório de resultados: $RESULT_DIR${NC}"
  exit 1
else
  echo -e "${GREEN}[+] Diretório de resultados criado com sucesso: $RESULT_DIR${NC}"
fi

echo -e "${BLUE}[+] Coletando subdomínios para: ${YELLOW}$DOMAIN${NC}"

run_command() {
  CMD=$1
  DESC=$2

  if [ "$VERBOSE" == "--v" ]; then
    echo -e "${CYAN}[VERBOSE] Executando: $CMD ${NC}"
  fi

  eval "$CMD"
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}[!] Erro ao executar comando: $DESC ${NC}"
    exit 1
  fi
}
echo -e "${BLUE}[++] Rodando Subfinder para $DOMAIN ${NC}"
run_command "subfinder -d $DOMAIN -silent | tee $RESULT_DIR/subdomains_subfinder.txt" 
echo -e "${BLUE}[DONE] Subfinder completado para $DOMAIN ${NC}"
echo ""
echo -e "${BLUE}[++] Rodando Assetfinder para $DOMAIN ${NC}"
run_command "assetfinder --subs-only $DOMAIN | tee $RESULT_DIR/subdomains_assetfinder.txt" 
echo -e "${BLUE}[DONE] Assetfinder completado para $DOMAIN ${NC}"
echo ""
echo -e "${BLUE}[++] Rodando Findomain para $DOMAIN ${NC}"
run_command "findomain -t $DOMAIN -u $RESULT_DIR/subdomains_findomain.txt" 
echo -e "${BLUE}[DONE] Findomain completado para $DOMAIN ${NC}"
echo ""
#echo -e "${BLUE}[++] Rodando Gobuster para $DOMAIN ${NC}"
#run_command "gobuster vhost -u $DOMAIN -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -o $RESULT_DIR/subdomains_gobuster.txt" 
#echo -e "${BLUE}[DONE] Gobuster completado para $DOMAIN ${NC}"
echo ""
echo -e "${BLUE}[++] Rodando Amass para $DOMAIN ${NC}"
run_command "amass enum -d $DOMAIN -o $RESULT_DIR/subdomains_amass.txt -active -brute -timeout 5 "
echo -e "${BLUE}[DONE] Amass completado para $DOMAIN ${NC}"
echo ""
echo -e "${BLUE}[+] Filtrando subdomínios únicos...${NC}"
cat $RESULT_DIR/subdomains_*.txt | grep -E "^[a-zA-Z0-9.-]+\.$DOMAIN$" | sort -u | tee $RESULT_DIR/subdomains_all.txt

if [ ! -f "$RESULT_DIR/subdomains_all.txt" ]; then
  echo -e "${RED}[!] O arquivo subdomains_all.txt não foi criado corretamente. Verifique os comandos anteriores.${NC}"
  exit 1
else
  echo -e "${GREEN}[+] Subdomínios coletados e salvos em $RESULT_DIR/subdomains_all.txt${NC}"
  echo -e "${YELLOW}[+] Subdomínios encontrados:${NC}"
  cat "$RESULT_DIR/subdomains_all.txt"
fi

handle_redirects() {
  STATUS_CODE=$1
  URL=$2
  if [[ "$STATUS_CODE" =~ ^3[0-9]{2}$ ]]; then
    REDIRECT_URL=$(curl -s -I -L "$URL" | grep -i "Location" | awk '{print $2}' | tr -d '\r')
    echo "$URL [$STATUS_CODE] -> Redirects to $REDIRECT_URL" | tee -a "$RESULT_DIR/subdomains_redirects.txt"
  else
    echo "$URL [$STATUS_CODE]" | tee -a "$RESULT_DIR/subdomains_http.txt"
  fi
}

while read -r SUB; do
  HTTP_CODE=$(curl -o /dev/null --silent --head --connect-timeout 5 --write-out '%{http_code}' -L "http://$SUB")
  HTTPS_CODE=$(curl -o /dev/null --silent --head --connect-timeout 5 --write-out '%{http_code}' -L "https://$SUB")

  if [[ "$HTTP_CODE" =~ ^[0-9]{3}$ ]]; then
    handle_redirects "$HTTP_CODE" "http://$SUB"
  fi


  if [[ "$HTTPS_CODE" =~ ^[0-9]{3}$ ]]; then
    handle_redirects "$HTTPS_CODE" "https://$SUB"
  fi
done < "$RESULT_DIR/subdomains_all.txt"

cat "$RESULT_DIR/subdomains_http.txt" "$RESULT_DIR/subdomains_https.txt" 2>/dev/null | sort -u > "$RESULT_DIR/subdomains_active.txt"
echo -e "${BLUE}[++] Rodando Katana para subdomínios de $DOMAIN ${NC}"
run_command "katana -list $RESULT_DIR/subdomains_all.txt -depth 3 -jc -td -kf -silent -timeout 5| tee $RESULT_DIR/subdirectories_katana.txt" 
echo -e "${BLUE}[DONE] Katana completo ${NC}"
echo ""
echo -e "${BLUE}[++] Rodando Nuclei para subdomínios de $DOMAIN ${NC}"
run_command "nuclei -l $RESULT_DIR/subdomains_all.txt -etags common,vulnerabilities -o $RESULT_DIR/$DOMAIN\/_nuclei.txt -silent"
echo -e "${BLUE}[DONE] Nuclei completo ${NC}"
echo ""
echo -e "${BLUE}[+] Detectando tecnologias...${NC}"
run_command "httpx -l $RESULT_DIR/subdomains_all.txt -tech-detect -silent -o $RESULT_DIR/technologies.txt"
echo -e "${BLUE}[+] Testando quais subdomínios estão ativos...${NC}"
touch "$RESULT_DIR/subdomains_http.txt" "$RESULT_DIR/subdomains_https.txt"
grep "200" "$RESULT_DIR/subdomains_active.txt" > "$RESULT_DIR/subdomains_200.txt" 2>/dev/null
grep -v "200" "$RESULT_DIR/subdomains_active.txt" > "$RESULT_DIR/subdomains_non_200.txt" 2>/dev/null
grep -Fxv -f "$RESULT_DIR/subdomains_active.txt" "$RESULT_DIR/subdomains_all.txt" > "$RESULT_DIR/subdomains_no_response.txt" 2>/dev/null
echo -e "${GREEN}[+] Resultados organizados em $RESULT_DIR${NC}"
echo -e "${GREEN}[+] Subdomínios ativos salvos em $RESULT_DIR/subdomains_http.txt e $RESULT_DIR/subdomains_https.txt${NC}"
echo -e "${GREEN}[+] Resumo salvo em $RESULT_DIR/summary.txt${NC}"
echo "Subdomínios encontrados: $(wc -l < "$RESULT_DIR/subdomains_all.txt")" > "$RESULT_DIR/summary.txt"
echo "Subdomínios ativos: $(wc -l < "$RESULT_DIR/subdomains_active.txt")" >> "$RESULT_DIR/summary.txt"
echo "Subdomínios com resposta 200: $(wc -l < "$RESULT_DIR/subdomains_200.txt")" >> "$RESULT_DIR/summary.txt"
echo "Subdomínios com resposta diferente de 200: $(wc -l < "$RESULT_DIR/subdomains_non_200.txt")" >> "$RESULT_DIR/summary.txt"
echo "Subdomínios sem resposta: $(wc -l < "$RESULT_DIR/subdomains_no_response.txt")" >> "$RESULT_DIR/summary.txt"
echo ""
run_command "cat $RESULT_DIR/subdomains_all.txt"
echo ""
run_command "cat $RESULT_DIR/$DOMAIN\/_nuclei.txt"
echo ""
run_command "cat $RESULT_DIR/summary.txt
echo ""
