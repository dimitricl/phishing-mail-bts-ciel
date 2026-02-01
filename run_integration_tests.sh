#!/bin/bash
# Script de tests d'intégration pour valider l'ensemble du système
# Teste : Flask, SMTP, Nginx, logs, rate-limiting

set -euo pipefail

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
FLASK_URL="http://localhost:5000"
NGINX_URL="https://localhost/prevention"
MAILHOG_URL="http://localhost:8025"
TEST_EMAIL="test@integration.local"
TEST_NAME="IntegrationTest"

# Compteurs
TESTS_PASSED=0
TESTS_FAILED=0

# Fonction pour afficher un résultat de test
test_result() {
    local test_name=$1
    local status=$2
    
    if [ "$status" -eq 0 ]; then
        echo -e "${GREEN}✅ PASS${NC} : $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ FAIL${NC} : $test_name"
        ((TESTS_FAILED++))
    fi
}

# Fonction pour exécuter un test avec timeout
run_test() {
    local test_name=$1
    shift
    timeout 10 "$@" > /dev/null 2>&1
    test_result "$test_name" $?
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   TESTS D'INTÉGRATION - PHISHING MAIL${NC}"
echo -e "${BLUE}========================================${NC}\n"

# ==================== TESTS PRÉLIMINAIRES ====================
echo -e "${YELLOW}[1/6]${NC} Tests préliminaires...\n"

# Test 1.1 : Python disponible
if command -v python3 &> /dev/null; then
    test_result "Python 3 installé" 0
else
    test_result "Python 3 installé" 1
fi

# Test 1.2 : Dossier templates existe
if [ -d "templates" ]; then
    test_result "Dossier templates/ existe" 0
else
    test_result "Dossier templates/ existe" 1
fi

# Test 1.3 : Fichier .env existe
if [ -f ".env" ]; then
    test_result "Fichier .env existe" 0
else
    test_result "Fichier .env existe" 1
fi

# Test 1.4 : Certificat SSL existe
if [ -f "ssl/nginx-selfsigned.crt" ]; then
    test_result "Certificat SSL existe" 0
else
    test_result "Certificat SSL existe" 1
fi

# ==================== TESTS DOCKER ====================
echo -e "\n${YELLOW}[2/6]${NC} Tests Docker...\n"

# Test 2.1 : Docker installé
if command -v docker &> /dev/null; then
    test_result "Docker installé" 0
else
    test_result "Docker installé" 1
fi

# Test 2.2 : Conteneur Nginx actif
if docker ps | grep -q "prevention-server"; then
    test_result "Conteneur Nginx actif" 0
else
    test_result "Conteneur Nginx actif" 1
fi

# Test 2.3 : Conteneur MailHog actif
if docker ps | grep -q "mailhog-smtp"; then
    test_result "Conteneur MailHog actif" 0
else
    test_result "Conteneur MailHog actif" 1
fi

# Test 2.4 : Healthcheck Nginx
NGINX_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' prevention-server 2>/dev/null || echo "unknown")
if [ "$NGINX_HEALTH" = "healthy" ]; then
    test_result "Healthcheck Nginx OK" 0
else
    test_result "Healthcheck Nginx OK" 1
fi

# ==================== TESTS RÉSEAU ====================
echo -e "\n${YELLOW}[3/6]${NC} Tests réseau...\n"

# Test 3.1 : Flask accessible
run_test "Flask répond (port 5000)" curl -f "$FLASK_URL"

# Test 3.2 : Nginx HTTP accessible
run_test "Nginx HTTP répond (port 8080)" curl -f http://localhost:8080

# Test 3.3 : Nginx HTTPS accessible
run_test "Nginx HTTPS répond (port 443)" curl -k -f "$NGINX_URL"

# Test 3.4 : MailHog API accessible
run_test "MailHog API répond (port 8025)" curl -f "$MAILHOG_URL/api/v2/messages"

# Test 3.5 : SMTP port ouvert
run_test "Port SMTP ouvert (1025)" nc -zv localhost 1025

# ==================== TESTS APPLICATIFS ====================
echo -e "\n${YELLOW}[4/6]${NC} Tests applicatifs...\n"

# Test 4.1 : Envoi d'email via Flask
SEND_RESPONSE=$(curl -s -X POST "$FLASK_URL/envoyer" \
    -d "email=$TEST_EMAIL" \
    -d "nom=$TEST_NAME" \
    -d "template=microsoft" \
    -w "%{http_code}" \
    -o /dev/null)

if [ "$SEND_RESPONSE" -eq 302 ] || [ "$SEND_RESPONSE" -eq 200 ]; then
    test_result "Envoi email via Flask" 0
else
    test_result "Envoi email via Flask" 1
fi

# Test 4.2 : Vérification de la réception dans MailHog
sleep 2  # Attente de la réception
MAILHOG_MESSAGES=$(curl -s "$MAILHOG_URL/api/v2/messages" | grep -c "$TEST_EMAIL" || echo 0)

if [ "$MAILHOG_MESSAGES" -gt 0 ]; then
    test_result "Email reçu dans MailHog" 0
else
    test_result "Email reçu dans MailHog" 1
fi

# Test 4.3 : Clic sur le lien de tracking
CLICK_RESPONSE=$(curl -k -s -w "%{http_code}" -o /dev/null "$NGINX_URL?victime=$TEST_NAME")

if [ "$CLICK_RESPONSE" -eq 200 ]; then
    test_result "Tracking des clics fonctionne" 0
else
    test_result "Tracking des clics fonctionne" 1
fi

# Test 4.4 : Vérification des logs Nginx
sleep 1
VICTIM_LOGGED=$(docker exec prevention-server grep -c "victime=$TEST_NAME" /var/log/nginx/access.log 2>/dev/null || echo 0)

if [ "$VICTIM_LOGGED" -gt 0 ]; then
    test_result "Logs Nginx enregistrent les victimes" 0
else
    test_result "Logs Nginx enregistrent les victimes" 1
fi

# ==================== TESTS DE SÉCURITÉ ====================
echo -e "\n${YELLOW}[5/6]${NC} Tests de sécurité...\n"

# Test 5.1 : Validation d'email invalide
INVALID_EMAIL_RESPONSE=$(curl -s -X POST "$FLASK_URL/envoyer" \
    -d "email=invalid_email" \
    -d "nom=Test" \
    -d "template=microsoft" \
    -w "%{http_code}" \
    -o /dev/null)

if [ "$INVALID_EMAIL_RESPONSE" -eq 302 ]; then
    test_result "Validation email fonctionne" 0
else
    test_result "Validation email fonctionne" 1
fi

# Test 5.2 : Nom avec caractères spéciaux rejeté
SPECIAL_CHARS_RESPONSE=$(curl -s -X POST "$FLASK_URL/envoyer" \
    -d "email=test@test.com" \
    -d "nom=<script>alert(1)</script>" \
    -d "template=microsoft" \
    -w "%{http_code}" \
    -o /dev/null)

if [ "$SPECIAL_CHARS_RESPONSE" -eq 302 ]; then
    test_result "Sanitization du nom fonctionne" 0
else
    test_result "Sanitization du nom fonctionne" 1
fi

# Test 5.3 : Template non autorisé rejeté
INVALID_TEMPLATE_RESPONSE=$(curl -s -X POST "$FLASK_URL/envoyer" \
    -d "email=test@test.com" \
    -d "nom=Test" \
    -d "template=../../../etc/passwd" \
    -w "%{http_code}" \
    -o /dev/null)

if [ "$INVALID_TEMPLATE_RESPONSE" -eq 302 ]; then
    test_result "Validation template fonctionne" 0
else
    test_result "Validation template fonctionne" 1
fi

# Test 5.4 : Headers de sécurité Nginx
SECURITY_HEADERS=$(curl -k -s -I "$NGINX_URL" | grep -i "strict-transport-security")

if [ -n "$SECURITY_HEADERS" ]; then
    test_result "Headers de sécurité HTTPS présents" 0
else
    test_result "Headers de sécurité HTTPS présents" 1
fi

# Test 5.5 : Rate limiting (optionnel, peut être long)
if [ "${SKIP_RATE_LIMIT_TEST:-0}" -eq 0 ]; then
    echo -e "${BLUE}ℹ️  Test de rate limiting (peut prendre 30s)...${NC}"
    
    RATE_LIMIT_429=0
    for i in {1..35}; do
        STATUS=$(curl -k -s -w "%{http_code}" -o /dev/null "$NGINX_URL?test=$i")
        if [ "$STATUS" -eq 429 ]; then
            RATE_LIMIT_429=1
            break
        fi
        sleep 0.1
    done
    
    test_result "Rate limiting fonctionne (429 Too Many Requests)" $((1 - RATE_LIMIT_429))
fi

# ==================== TESTS UNITAIRES PYTHON ====================
echo -e "\n${YELLOW}[6/6]${NC} Tests unitaires Python...\n"

if [ -f "test_phishing_server.py" ]; then
    if python3 -m pytest test_phishing_server.py -q > /dev/null 2>&1; then
        test_result "Tests unitaires Python" 0
    else
        test_result "Tests unitaires Python" 1
    fi
else
    test_result "Tests unitaires Python (fichier manquant)" 1
fi

# ==================== RÉSUMÉ ====================
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}   RÉSUMÉ DES TESTS${NC}"
echo -e "${BLUE}========================================${NC}\n"

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))

echo -e "${GREEN}✅ Tests réussis : $TESTS_PASSED / $TOTAL_TESTS${NC}"

if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}❌ Tests échoués : $TESTS_FAILED / $TOTAL_TESTS${NC}"
    echo -e "\n${YELLOW}💡 Consultez les logs pour plus de détails:${NC}"
    echo "   - tail -f logs/app.log"
    echo "   - docker logs prevention-server"
    exit 1
else
    echo -e "\n${GREEN}🎉 Tous les tests sont passés avec succès !${NC}"
    exit 0
fi
