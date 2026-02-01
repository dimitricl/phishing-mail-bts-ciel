#!/bin/bash
# Script de déploiement automatique - Migration vers version sécurisée
# Usage: ./deploy.sh

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_DIR="$PWD"
BACKUP_DIR="backup_$(date +%Y%m%d_%H%M%S)"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   DÉPLOIEMENT AUTOMATIQUE${NC}"
echo -e "${BLUE}   Projet Phishing Mail - Version Sécurisée${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Fonction pour afficher les étapes
step() {
    local step_num=$1
    local step_name=$2
    echo -e "\n${YELLOW}[ÉTAPE $step_num]${NC} $step_name"
    echo "----------------------------------------"
}

# Fonction pour vérifier les prérequis
check_prerequisites() {
    local all_ok=true
    
    # Python 3
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}❌ Python 3 n'est pas installé${NC}"
        all_ok=false
    else
        echo -e "${GREEN}✅ Python $(python3 --version | cut -d' ' -f2) détecté${NC}"
    fi
    
    # pip3
    if ! command -v pip3 &> /dev/null; then
        echo -e "${RED}❌ pip3 n'est pas installé${NC}"
        all_ok=false
    else
        echo -e "${GREEN}✅ pip installé${NC}"
    fi
    
    # Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker n'est pas installé${NC}"
        all_ok=false
    else
        echo -e "${GREEN}✅ Docker installé${NC}"
    fi
    
    # docker-compose
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}❌ docker-compose n'est pas installé${NC}"
        all_ok=false
    else
        echo -e "${GREEN}✅ docker-compose installé${NC}"
    fi
    
    # openssl
    if ! command -v openssl &> /dev/null; then
        echo -e "${RED}❌ openssl n'est pas installé${NC}"
        all_ok=false
    else
        echo -e "${GREEN}✅ openssl installé${NC}"
    fi
    
    if [ "$all_ok" = false ]; then
        echo -e "\n${RED}⚠️  Installez les prérequis manquants avant de continuer${NC}"
        exit 1
    fi
}

# ==================== ÉTAPE 1 : VÉRIFICATIONS ====================
step "1/9" "Vérification des prérequis"
check_prerequisites

# ==================== ÉTAPE 2 : SAUVEGARDE ====================
step "2/9" "Sauvegarde des anciens fichiers"

if [ -f "app.py" ]; then
    mkdir -p "$BACKUP_DIR"
    
    for file in app.py phishing_server.py nginx.conf docker-compose.yml check_victimes.sh; do
        if [ -f "$file" ]; then
            cp "$file" "$BACKUP_DIR/"
            echo -e "${GREEN}✅ $file sauvegardé${NC}"
        fi
    done
    
    echo -e "${GREEN}✅ Sauvegarde créée dans $BACKUP_DIR/${NC}"
else
    echo -e "${YELLOW}⚠️  Aucun fichier existant détecté (installation propre)${NC}"
fi

# ==================== ÉTAPE 3 : ARRÊT DES SERVICES ====================
step "3/9" "Arrêt des services existants"

# Arrêter Docker si en cours
if docker ps | grep -q "prevention-server\|mailhog"; then
    docker-compose down 2>/dev/null || true
    echo -e "${GREEN}✅ Conteneurs Docker arrêtés${NC}"
else
    echo -e "${YELLOW}⚠️  Aucun conteneur Docker actif${NC}"
fi

# Arrêter Flask si en cours
pkill -f "python.*app.py" 2>/dev/null || true
echo -e "${GREEN}✅ Processus Flask arrêtés${NC}"

# ==================== ÉTAPE 4 : REMPLACEMENT DES FICHIERS ====================
step "4/9" "Installation des nouveaux fichiers"

# Renommer les fichiers sécurisés
if [ -f "app_secure.py" ]; then
    mv app_secure.py app.py
    echo -e "${GREEN}✅ app.py mis à jour${NC}"
fi

if [ -f "phishing_server_secure.py" ]; then
    mv phishing_server_secure.py phishing_server.py
    echo -e "${GREEN}✅ phishing_server.py mis à jour${NC}"
fi

if [ -f "nginx_secure.conf" ]; then
    mv nginx_secure.conf nginx.conf
    echo -e "${GREEN}✅ nginx.conf mis à jour${NC}"
fi

if [ -f "docker-compose_secure.yml" ]; then
    mv docker-compose_secure.yml docker-compose.yml
    echo -e "${GREEN}✅ docker-compose.yml mis à jour${NC}"
fi

if [ -f "check_victimes_secure.sh" ]; then
    mv check_victimes_secure.sh check_victimes.sh
    chmod +x check_victimes.sh
    echo -e "${GREEN}✅ check_victimes.sh mis à jour${NC}"
fi

# Rendre les scripts exécutables
chmod +x install.sh run_integration_tests.sh 2>/dev/null || true

# ==================== ÉTAPE 5 : ENVIRONNEMENT VIRTUEL ====================
step "5/9" "Configuration de l'environnement virtuel Python"

if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo -e "${GREEN}✅ Environnement virtuel créé${NC}"
else
    echo -e "${GREEN}✅ Environnement virtuel existant${NC}"
fi

# Activation et installation des dépendances
source venv/bin/activate
pip install --upgrade pip --quiet
pip install -r requirements.txt --quiet

echo -e "${GREEN}✅ Dépendances Python installées${NC}"

# ==================== ÉTAPE 6 : CONFIGURATION ====================
step "6/9" "Génération de la configuration"

# Création du fichier .env si inexistant
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        
        # Génération d'une secret key unique
        SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")
        
        # Remplacement dans le fichier .env
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' "s/your_secret_key_here_change_me/$SECRET/g" .env
        else
            # Linux
            sed -i "s/your_secret_key_here_change_me/$SECRET/g" .env
        fi
        
        echo -e "${GREEN}✅ Fichier .env créé avec secret key unique${NC}"
    else
        echo -e "${RED}❌ .env.example manquant${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ Fichier .env existant${NC}"
fi

# Création des dossiers nécessaires
mkdir -p logs ssl templates phishing-pages

# ==================== ÉTAPE 7 : CERTIFICATS SSL ====================
step "7/9" "Génération des certificats SSL"

if [ ! -f "ssl/nginx-selfsigned.crt" ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout ssl/nginx-selfsigned.key \
      -out ssl/nginx-selfsigned.crt \
      -subj "/C=FR/ST=Occitanie/L=Toulouse/O=InstLimayrac/CN=localhost" \
      2>/dev/null
    
    echo -e "${GREEN}✅ Certificats SSL générés (valables 365 jours)${NC}"
else
    echo -e "${GREEN}✅ Certificats SSL existants${NC}"
fi

# ==================== ÉTAPE 8 : TEMPLATES ====================
step "8/9" "Vérification des templates"

if [ ! -f "templates/microsoft.html" ]; then
    echo -e "${YELLOW}⚠️  Aucun template détecté, création d'un template de démonstration${NC}"
    
    cat > templates/microsoft.html << 'EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Microsoft 365 - Alerte de sécurité</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 600px; margin: 50px auto; }
        .button { background: #0078d4; color: white; padding: 15px 30px; text-decoration: none; display: inline-block; }
    </style>
</head>
<body>
    <h1>Bonjour {{ nom }},</h1>
    <p>Votre compte Microsoft 365 nécessite une vérification urgente pour des raisons de sécurité.</p>
    <p>Cliquez sur le bouton ci-dessous pour vérifier votre identité :</p>
    <a href="{{ url }}" class="button">Vérifier mon compte</a>
    <p><small>Ceci est un email de simulation de phishing à des fins éducatives.</small></p>
</body>
</html>
EOF
    
    echo -e "${GREEN}✅ Template microsoft.html créé${NC}"
else
    echo -e "${GREEN}✅ Templates existants${NC}"
fi

# Vérification de la page de prévention
if [ ! -f "phishing-pages/index.html" ]; then
    cat > phishing-pages/index.html << 'EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Page de Prévention - Phishing détecté</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        .warning { color: #d93025; font-size: 48px; }
    </style>
</head>
<body>
    <div class="warning">⚠️ ATTENTION</div>
    <h1>Vous avez cliqué sur un lien de phishing</h1>
    <p>Ceci était un test de sensibilisation à la sécurité informatique.</p>
    <p>Dans un cas réel, vos données auraient pu être compromises.</p>
    <h2>Comment se protéger ?</h2>
    <ul style="text-align: left; max-width: 600px; margin: 0 auto;">
        <li>Vérifiez toujours l'adresse de l'expéditeur</li>
        <li>Ne cliquez pas sur des liens suspects</li>
        <li>Vérifiez l'URL avant de saisir des informations</li>
        <li>En cas de doute, contactez votre service IT</li>
    </ul>
</body>
</html>
EOF
    
    echo -e "${GREEN}✅ Page de prévention créée${NC}"
fi

# ==================== ÉTAPE 9 : DÉMARRAGE ====================
step "9/9" "Démarrage des services"

# Démarrer Docker
echo -e "${BLUE}Démarrage des conteneurs Docker...${NC}"
docker-compose up -d

# Attendre que les conteneurs soient prêts
sleep 5

# Vérifier l'état des conteneurs
if docker ps | grep -q "prevention-server" && docker ps | grep -q "mailhog"; then
    echo -e "${GREEN}✅ Conteneurs Docker démarrés${NC}"
else
    echo -e "${RED}❌ Échec du démarrage des conteneurs${NC}"
    docker-compose logs
    exit 1
fi

# Démarrer Flask en arrière-plan
echo -e "${BLUE}Démarrage de Flask...${NC}"
nohup python app.py > logs/flask.log 2>&1 &
FLASK_PID=$!

# Attendre que Flask soit prêt
sleep 3

if ps -p $FLASK_PID > /dev/null; then
    echo -e "${GREEN}✅ Flask démarré (PID: $FLASK_PID)${NC}"
else
    echo -e "${RED}❌ Échec du démarrage de Flask${NC}"
    cat logs/flask.log
    exit 1
fi

# ==================== RÉSUMÉ ====================
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}   DÉPLOIEMENT TERMINÉ${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${GREEN}✅ Tous les services sont opérationnels !${NC}\n"

echo -e "${YELLOW}ACCÈS AUX INTERFACES:${NC}"
echo "• Application Flask : http://localhost:5000"
echo "• MailHog (emails)  : http://localhost:8025"
echo "• Page prévention   : https://localhost/prevention (HTTPS)"
echo ""

echo -e "${YELLOW}COMMANDES UTILES:${NC}"
echo "• Voir les victimes  : ./check_victimes.sh"
echo "• Arrêter Docker     : docker-compose down"
echo "• Arrêter Flask      : kill $FLASK_PID"
echo "• Voir logs Flask    : tail -f logs/flask.log"
echo "• Voir logs Nginx    : docker logs prevention-server"
echo "• Lancer les tests   : ./run_integration_tests.sh"
echo ""

echo -e "${YELLOW}PROCHAINES ÉTAPES:${NC}"
echo "1. Ouvrir http://localhost:5000 dans votre navigateur"
echo "2. Envoyer un email de test"
echo "3. Vérifier la réception dans MailHog (http://localhost:8025)"
echo "4. Cliquer sur le lien dans l'email"
echo "5. Exécuter ./check_victimes.sh pour voir les statistiques"
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}🎉 BON PHISHING ÉDUCATIF !${NC}"
echo -e "${BLUE}========================================${NC}"
