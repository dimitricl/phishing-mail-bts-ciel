#!/bin/bash

echo "=========================================="
echo "  INSTALLATION PHISHING MAIL BTS CIEL"
echo "=========================================="

# 1. Vérifications
echo ""
echo "🔍 Vérification des prérequis..."
command -v python3 >/dev/null 2>&1 || { echo "❌ Python3 requis"; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "❌ Docker requis"; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo "❌ Docker Compose requis"; exit 1; }
echo "✅ Prérequis OK"

# 2. Configuration .env
echo ""
echo "⚙️  Configuration de l'environnement..."
if [ ! -f .env ]; then
    cp .env.example .env
    SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
    cat > .env << EOF
SECRET_KEY=$SECRET_KEY
SMTP_SERVER=localhost
SMTP_PORT=1025
BASE_URL=http://localhost:8080
TEMPLATES_DIR=templates
EOF
    echo "✅ Fichier .env créé avec secret key unique"
else
    echo "⚠️  .env existe déjà, conservation"
fi

# 3. Environnement virtuel Python
echo ""
echo "🐍 Installation de l'environnement Python..."
if [ ! -d venv ]; then
    python3 -m venv venv
    echo "✅ Environnement virtuel créé"
fi

source venv/bin/activate
echo "📦 Installation des dépendances..."
pip install -r requirements.txt --quiet 2>/dev/null || pip install -r requirements.txt --break-system-packages --quiet
echo "✅ Dépendances installées"

# 4. SSL
echo ""
echo "🔒 Génération des certificats SSL..."
mkdir -p ssl
if [ ! -f ssl/nginx-selfsigned.crt ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout ssl/nginx-selfsigned.key \
      -out ssl/nginx-selfsigned.crt \
      -subj "/C=FR/ST=Occitanie/L=Toulouse/O=Institut Limayrac/CN=localhost" \
      >/dev/null 2>&1
    echo "✅ Certificats SSL générés"
else
    echo "⚠️  Certificats existants, conservation"
fi

# 5. Docker
echo ""
echo "🐳 Démarrage des services Docker..."
docker-compose down >/dev/null 2>&1
docker-compose up -d
sleep 3
echo "✅ Docker démarré (Nginx + MailHog)"

# 6. Résumé
echo ""
echo "=========================================="
echo "  ✅ INSTALLATION TERMINÉE"
echo "=========================================="
echo ""
echo "🚀 Pour lancer l'application :"
echo "   source venv/bin/activate"
echo "   python3 app.py"
echo ""
echo "📧 Services disponibles :"
echo "   • Interface Flask :   http://localhost:5000"
echo "   • MailHog (emails) :  http://localhost:8025"
echo "   • Nginx (tracking) :  http://localhost:8080"
echo ""
echo "🧪 Tests de sécurité :"
echo "   ./run_integration_tests.sh"
echo ""
echo "📊 Statistiques des victimes :"
echo "   ./check_victimes.sh"
echo ""
echo "=========================================="
