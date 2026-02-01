#!/bin/bash
# Script sécurisé pour lister les victimes ayant cliqué sur le lien de phishing
# Protégé contre l'injection de commandes

set -euo pipefail

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONTAINER_NAME="prevention-server"
LOG_FILE="/var/log/nginx/clicks.log"
FALLBACK_LOG="/var/log/nginx/access.log"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   RAPPORT DES VICTIMES DE PHISHING${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Vérification que le conteneur existe et tourne
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo -e "${RED}❌ Erreur: Le conteneur '$CONTAINER_NAME' n'est pas démarré${NC}"
    echo -e "${YELLOW}💡 Lancez: docker-compose up -d${NC}"
    exit 1
fi

# Fonction pour parser les logs de manière sécurisée
parse_victims() {
    local log_path=$1
    
    # Extraction sécurisée avec grep et awk (pas d'eval)
    docker exec "$CONTAINER_NAME" sh -c "
        if [ -f '$log_path' ]; then
            grep 'victime=' '$log_path' 2>/dev/null | \
            awk -F'victime=' '{print \$2}' | \
            awk '{print \$1}' | \
            sort | uniq -c | sort -rn
        fi
    " 2>/dev/null
}

# Tentative de lecture du log spécifique clicks.log
echo -e "${YELLOW}📊 Analyse des logs...${NC}\n"

VICTIMS=$(parse_victims "$LOG_FILE")

# Fallback sur access.log si clicks.log est vide
if [ -z "$VICTIMS" ]; then
    echo -e "${YELLOW}⚠️  Aucun clic détecté dans $LOG_FILE${NC}"
    echo -e "${YELLOW}⚠️  Vérification du log principal...${NC}\n"
    VICTIMS=$(parse_victims "$FALLBACK_LOG")
fi

# Affichage des résultats
if [ -z "$VICTIMS" ]; then
    echo -e "${GREEN}✅ Aucune victime détectée (ou logs vides)${NC}"
    echo -e "${YELLOW}💡 Cela peut signifier:${NC}"
    echo "   - Aucun employé n'a cliqué sur le lien"
    echo "   - Les logs ne sont pas encore générés"
    echo "   - Le paramètre 'victime=' est manquant dans l'URL"
else
    echo -e "${RED}⚠️  VICTIMES DÉTECTÉES:${NC}\n"
    echo "┌─────────┬─────────────────────────────────┐"
    echo "│ Clics   │ Nom de la victime               │"
    echo "├─────────┼─────────────────────────────────┤"
    
    # Affichage formaté avec limitation de la longueur
    echo "$VICTIMS" | while read -r count name; do
        # Limitation à 30 caractères pour éviter les débordements
        name_truncated=$(echo "$name" | cut -c1-30)
        printf "│ %-7s │ %-31s │\n" "$count" "$name_truncated"
    done
    
    echo "└─────────┴─────────────────────────────────┘"
    
    # Statistiques
    TOTAL_CLICKS=$(echo "$VICTIMS" | awk '{sum+=$1} END {print sum}')
    UNIQUE_VICTIMS=$(echo "$VICTIMS" | wc -l)
    
    echo ""
    echo -e "${BLUE}📈 STATISTIQUES:${NC}"
    echo "   • Nombre total de clics: $TOTAL_CLICKS"
    echo "   • Victimes uniques: $UNIQUE_VICTIMS"
fi

echo -e "\n${BLUE}========================================${NC}"
echo -e "${YELLOW}💡 COMMANDES UTILES:${NC}"
echo "   • Voir les logs en temps réel:"
echo "     docker logs -f $CONTAINER_NAME"
echo ""
echo "   • Afficher les 20 derniers clics:"
echo "     docker exec $CONTAINER_NAME tail -20 $LOG_FILE"
echo ""
echo "   • Réinitialiser les logs:"
echo "     docker exec $CONTAINER_NAME sh -c 'echo "" > $LOG_FILE'"
echo -e "${BLUE}========================================${NC}"
