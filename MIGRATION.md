# 🔄 GUIDE DE MIGRATION - Passage à la version sécurisée

## 📦 Fichiers reçus

Vous avez reçu les fichiers suivants :

### **Code principal (à remplacer)**
- `app_secure.py` → Remplace `app.py`
- `phishing_server_secure.py` → Remplace `phishing_server.py`
- `nginx_secure.conf` → Remplace `nginx.conf`
- `docker-compose_secure.yml` → Remplace `docker-compose.yml`
- `check_victimes_secure.sh` → Remplace `check_victimes.sh`

### **Nouveaux fichiers**
- `requirements.txt` → Dépendances Python
- `.env.example` → Template de configuration
- `install.sh` → Script d'installation automatique
- `test_phishing_server.py` → Tests unitaires
- `run_integration_tests.sh` → Tests d'intégration

### **Documentation**
- `README.md` → Documentation complète
- `SECURITY_AUDIT.md` → Guide d'audit de sécurité

---

## 🚀 Étapes de Migration (30 minutes)

### ÉTAPE 1 : Sauvegarde (2 min)

```bash
# Créer un dossier de sauvegarde
mkdir -p backup_$(date +%Y%m%d)

# Sauvegarder les anciens fichiers
cp app.py backup_*/
cp phishing_server.py backup_*/
cp nginx.conf backup_*/
cp docker-compose.yml backup_*/
cp check_victimes.sh backup_*/

echo "✅ Sauvegarde créée dans backup_$(date +%Y%m%d)/"
```

### ÉTAPE 2 : Arrêt des services (1 min)

```bash
# Arrêter Docker
docker-compose down

# Arrêter Flask (si lancé)
pkill -f "python.*app.py"

echo "✅ Services arrêtés"
```

### ÉTAPE 3 : Remplacement des fichiers (2 min)

```bash
# Remplacer les fichiers Python
mv app_secure.py app.py
mv phishing_server_secure.py phishing_server.py

# Remplacer les configs
mv nginx_secure.conf nginx.conf
mv docker-compose_secure.yml docker-compose.yml
mv check_victimes_secure.sh check_victimes.sh

# Rendre les scripts exécutables
chmod +x install.sh check_victimes.sh run_integration_tests.sh

echo "✅ Fichiers remplacés"
```

### ÉTAPE 4 : Installation des dépendances (5 min)

```bash
# Lancer le script d'installation
./install.sh
```

Ce script va :
1. ✅ Vérifier Python 3.10+
2. ✅ Créer un environnement virtuel `venv/`
3. ✅ Installer Flask, Jinja2, email-validator, pytest
4. ✅ Générer une secret key sécurisée dans `.env`
5. ✅ Créer les dossiers `logs/`, `ssl/`, `templates/`

### ÉTAPE 5 : Configuration SSL (5 min)

```bash
# Générer des certificats auto-signés (valables 1 an)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/nginx-selfsigned.key \
  -out ssl/nginx-selfsigned.crt \
  -subj "/C=FR/ST=Occitanie/L=Toulouse/O=InstLimayrac/CN=localhost"

echo "✅ Certificats SSL générés"
```

**Note** : En production, utilisez Let's Encrypt avec Certbot.

### ÉTAPE 6 : Vérification des templates (2 min)

```bash
# Vérifier que vos templates existent
ls templates/

# Si absent, créer un template de test
cat > templates/microsoft.html << 'EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Microsoft 365 - Alerte</title>
</head>
<body>
    <h1>Bonjour {{ nom }},</h1>
    <p>Votre compte nécessite une vérification.</p>
    <a href="{{ url }}">Cliquer ici</a>
</body>
</html>
EOF

echo "✅ Templates vérifiés"
```

### ÉTAPE 7 : Tests (10 min)

```bash
# 1. Activer l'environnement virtuel
source venv/bin/activate

# 2. Lancer les tests unitaires
pytest test_phishing_server.py -v

# 3. Démarrer Docker
docker-compose up -d

# 4. Démarrer Flask (en arrière-plan)
nohup python app.py > logs/flask.log 2>&1 &

# 5. Attendre 5 secondes
sleep 5

# 6. Lancer les tests d'intégration
./run_integration_tests.sh

# Si tous les tests passent :
echo "✅ Migration réussie !"
```

### ÉTAPE 8 : Vérification manuelle (3 min)

```bash
# 1. Ouvrir l'interface web
xdg-open http://localhost:5000  # Linux
open http://localhost:5000       # macOS

# 2. Envoyer un email de test
# - Email: test@example.com
# - Nom: TestUser
# - Template: microsoft

# 3. Vérifier la réception dans MailHog
xdg-open http://localhost:8025  # Linux
open http://localhost:8025       # macOS

# 4. Cliquer sur le lien dans l'email

# 5. Vérifier les logs
./check_victimes.sh
```

---

## 🔍 Comparaison Avant/Après

### Sécurité

| Aspect | Avant | Après |
|--------|-------|-------|
| **Template Engine** | `str.format()` (vulnérable SSTI) | Jinja2 avec autoescape |
| **Validation Email** | Aucune | `email-validator` |
| **Validation Nom** | Aucune | Regex stricte |
| **Secret Key** | `os.urandom(24)` (non persistante) | Variable d'env `.env` |
| **Logs** | `print()` | `logging` module |
| **Rate Limiting** | Aucun | 10 req/sec (burst 20) |
| **Headers Sécurité** | Aucun | HSTS, X-Frame-Options, etc. |
| **Command Injection** | Vulnérable dans `check_victimes.sh` | Sécurisé |

### Performance

| Aspect | Avant | Après |
|--------|-------|-------|
| **Timeouts SMTP** | Aucun | 10 secondes |
| **Log Rotation** | Aucune | 10 Mo max, 3 fichiers |
| **Healthchecks Docker** | Aucun | Toutes les 30s |
| **Cache Templates** | Non | Jinja2 cache natif |

### Tests

| Type | Avant | Après |
|------|-------|-------|
| **Tests unitaires** | Aucun | 20+ tests avec pytest |
| **Tests intégration** | Manuels | Script automatisé |
| **Coverage** | 0% | Rapport HTML |

---

## 🐛 Dépannage

### Erreur : "Module 'jinja2' not found"

```bash
source venv/bin/activate
pip install -r requirements.txt
```

### Erreur : "Port 5000 already in use"

```bash
# Trouver le processus
lsof -i :5000

# Tuer le processus
kill -9 <PID>
```

### Erreur : "Docker daemon not running"

```bash
sudo systemctl start docker
```

### Tests échouent

```bash
# Vérifier les logs
tail -f logs/app.log
docker logs prevention-server
docker logs mailhog-smtp

# Redémarrer tout
docker-compose down
docker-compose up -d
python app.py
```

---

## 📊 Checklist Finale

Avant de considérer la migration comme terminée :

- [ ] Tous les tests unitaires passent (`pytest`)
- [ ] Tous les tests d'intégration passent (`./run_integration_tests.sh`)
- [ ] Flask démarre sans erreur (`python app.py`)
- [ ] Docker Compose démarre sans erreur (`docker-compose up -d`)
- [ ] Envoi d'email de test fonctionne
- [ ] Réception dans MailHog fonctionne
- [ ] Tracking des clics fonctionne (`./check_victimes.sh`)
- [ ] Logs sont créés dans `logs/`
- [ ] Certificats SSL sont générés dans `ssl/`
- [ ] `.env` contient une secret key unique

---

## 🎯 Prochaines Étapes (Améliorations)

Une fois la migration terminée, vous pouvez :

1. **Ajouter une base de données** (SQLite/PostgreSQL)
   - Stocker les victimes
   - Générer des statistiques
   - Historique des campagnes

2. **Créer une interface d'administration**
   - Dashboard avec graphiques
   - Gestion des templates
   - Export des rapports

3. **Implémenter une queue** (Redis + RQ)
   - Envois massifs (500+ emails)
   - Retry automatique en cas d'échec

4. **Déployer en production**
   - VPS (DigitalOcean, OVH)
   - Certificat Let's Encrypt
   - Domaine personnalisé

---

## 📞 Support

En cas de problème :
1. Consulter `README.md`
2. Consulter `SECURITY_AUDIT.md`
3. Vérifier les logs : `tail -f logs/app.log`
4. Ouvrir une issue sur le dépôt Git

---

**Bonne migration !** 🚀
