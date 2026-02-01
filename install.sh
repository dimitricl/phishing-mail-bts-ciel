#!/bin/bash
set -e

echo "==================================="
echo "INSTALLATION PROJET PHISHING MAIL"
echo "==================================="

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Vérification de Python
echo -e "\n${YELLOW}[1/6]${NC} Vérification de Python..."
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python 3 n'est pas installé${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Python $(python3 --version) détecté${NC}"

# Vérification de pip
echo -e "\n${YELLOW}[2/6]${NC} Vérification de pip..."
if ! command -v pip3 &> /dev/null; then
    echo -e "${RED}❌ pip3 n'est pas installé${NC}"
    exit 1
fi
echo -e "${GREEN}✅ pip $(pip3 --version | cut -d' ' -f2) détecté${NC}"

# Création de l'environnement virtuel
echo -e "\n${YELLOW}[3/6]${NC} Création de l'environnement virtuel..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo -e "${GREEN}✅ Environnement virtuel créé${NC}"
else
    echo -e "${GREEN}✅ Environnement virtuel existant${NC}"
fi

# Activation de l'environnement virtuel
echo -e "\n${YELLOW}[4/6]${NC} Activation de l'environnement virtuel..."
source venv/bin/activate

# Installation des dépendances
echo -e "\n${YELLOW}[5/6]${NC} Installation des dépendances..."
pip install --upgrade pip > /dev/null
pip install -r requirements.txt

echo -e "${GREEN}✅ Dépendances installées${NC}"

# Génération de la secret key
echo -e "\n${YELLOW}[6/6]${NC} Configuration..."
if [ ! -f ".env" ]; then
    cp .env.example .env
    SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")
    sed -i "s/your_secret_key_here_change_me/$SECRET/g" .env
    echo -e "${GREEN}✅ Fichier .env créé avec secret key générée${NC}"
else
    echo -e "${GREEN}✅ Fichier .env existant${NC}"
fi

# Création des dossiers nécessaires
mkdir -p logs ssl templates

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ INSTALLATION TERMINÉE${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${YELLOW}PROCHAINES ÉTAPES:${NC}"
echo "1. Créez vos templates HTML dans ./templates/"
echo "2. Lancez Docker Compose: docker-compose up -d"
echo "3. Démarrez l'app Flask: source venv/bin/activate && python app_secure.py"
echo ""
echo -e "${YELLOW}COMMANDES UTILES:${NC}"
echo "- Tester l'app: pytest tests/"
echo "- Voir les logs: tail -f logs/app.log"
echo "- Vérifier les victimes: ./check_victimes.sh"
