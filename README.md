# 🎯 Projet Phishing Mail - Version Sécurisée

> Application Flask pour campagnes de phishing éducatif  
> BTS CIEL - Cybersécurité, Informatique et réseaux, Électronique

[![Python](https://img.shields.io/badge/Python-3.10+-blue.svg)](https://www.python.org/)
[![Flask](https://img.shields.io/badge/Flask-3.0-green.svg)](https://flask.palletsprojects.com/)
[![Security](https://img.shields.io/badge/Security-Enhanced-brightgreen.svg)]()

---

## 📋 Qu'est-ce qui a été corrigé ?

### 🔒 Sécurité
- ✅ **Injection de template** : Remplacement de `.format()` par Jinja2 avec autoescape
- ✅ **Validation d'input** : Regex strictes pour email et nom (email-validator)
- ✅ **Secret key persistante** : Variable d'environnement au lieu de `os.urandom(24)`
- ✅ **Info leak** : Pas d'exposition des détails SMTP dans les erreurs
- ✅ **Command injection** : Script `check_victimes.sh` sécurisé (pas d'eval)
- ✅ **Rate limiting** : Nginx configuré (10 req/sec avec burst de 20)
- ✅ **Headers de sécurité** : HSTS, X-Frame-Options, CSP, etc.

### 🏗️ Architecture
- ✅ **Logging structuré** : `logging` module au lieu de `print()`
- ✅ **Gestion d'erreurs** : Try-catch robuste avec messages explicites
- ✅ **Healthchecks Docker** : Monitoring automatique des conteneurs
- ✅ **Log rotation** : Limite de 10 Mo par fichier (3 fichiers max)
- ✅ **Type hints** : Documentation du code améliorée

### 🧪 Tests
- ✅ **Tests unitaires** : pytest avec mocks de smtplib
- ✅ **Tests d'intégration** : Workflow complet template → email → envoi
- ✅ **Coverage** : Rapport de couverture de code HTML

---

## 🚀 Installation (Migration depuis l'ancienne version)

### Étape 1 : Sauvegarde

```bash
# Sauvegarde de l'ancien code
cp app.py app_old.py.bak
cp phishing_server.py phishing_server_old.py.bak
cp nginx.conf nginx_old.conf.bak
cp docker-compose.yml docker-compose_old.yml.bak
```

### Étape 2 : Installation des nouveaux fichiers

```bash
# Remplacer les anciens fichiers
mv app_secure.py app.py
mv phishing_server_secure.py phishing_server.py
mv nginx_secure.conf nginx.conf
mv docker-compose_secure.yml docker-compose.yml
mv check_victimes_secure.sh check_victimes.sh

# Rendre les scripts exécutables
chmod +x install.sh check_victimes.sh
```

### Étape 3 : Lancer le script d'installation

```bash
./install.sh
```

Ce script va :
1. ✅ Vérifier Python 3.10+
2. ✅ Créer un environnement virtuel `venv/`
3. ✅ Installer les dépendances (Flask, Jinja2, email-validator, pytest)
4. ✅ Générer une secret key sécurisée dans `.env`
5. ✅ Créer les dossiers `logs/`, `ssl/`, `templates/`

### Étape 4 : Générer les certificats SSL

```bash
mkdir -p ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/nginx-selfsigned.key \
  -out ssl/nginx-selfsigned.crt \
  -subj "/C=FR/ST=Occitanie/L=Toulouse/O=InstLimayrac/CN=localhost"
```

### Étape 5 : Créer vos templates HTML

Exemple de template `templates/microsoft.html` :

```html
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Microsoft 365 - Alerte de sécurité</title>
</head>
<body>
    <h1>Bonjour {{ nom }},</h1>
    <p>Votre compte Microsoft 365 nécessite une vérification urgente.</p>
    <a href="{{ url }}" style="background: #0078d4; color: white; padding: 10px 20px; text-decoration: none;">
        Vérifier mon compte
    </a>
    <p><small>Ceci est un email de simulation de phishing à des fins éducatives.</small></p>
</body>
</html>
```

---

## 🎮 Utilisation

### Démarrage complet

```bash
# 1. Activer l'environnement virtuel
source venv/bin/activate

# 2. Démarrer les conteneurs Docker (Nginx + MailHog)
docker-compose up -d

# 3. Vérifier que les conteneurs sont actifs
docker ps

# 4. Lancer l'application Flask
python app.py
```

L'application est accessible sur : **http://localhost:5000**

### Envoi d'un email de test

1. Ouvrir http://localhost:5000
2. Remplir le formulaire :
   - **Email** : `victim@example.com`
   - **Nom** : `Jean Dupont`
   - **Template** : `microsoft`
3. Cliquer sur "Envoyer"
4. Consulter MailHog : http://localhost:8025

### Vérification des victimes

```bash
./check_victimes.sh
```

Affichage exemple :
```
========================================
   RAPPORT DES VICTIMES DE PHISHING
========================================

⚠️  VICTIMES DÉTECTÉES:

┌─────────┬─────────────────────────────────┐
│ Clics   │ Nom de la victime               │
├─────────┼─────────────────────────────────┤
│ 3       │ Jean Dupont                     │
│ 2       │ Marie Martin                    │
│ 1       │ Pierre Durand                   │
└─────────┴─────────────────────────────────┘

📈 STATISTIQUES:
   • Nombre total de clics: 6
   • Victimes uniques: 3
```

---

## 🧪 Tests

### Lancer tous les tests

```bash
# Tests unitaires avec coverage
pytest test_phishing_server.py -v --cov=phishing_server --cov-report=html

# Ouvrir le rapport HTML
xdg-open htmlcov/index.html  # Linux
open htmlcov/index.html       # macOS
```

### Tests manuels avec curl

```bash
# Test de l'endpoint d'envoi
curl -X POST http://localhost:5000/envoyer \
  -d "email=test@example.com" \
  -d "nom=TestUser" \
  -d "template=microsoft"

# Test du rate limiting (doit retourner 429 après 30 requêtes)
for i in {1..35}; do
  curl -I https://localhost/prevention?victime=test$i -k
done | grep "429"
```

---

## 📊 Monitoring et Logs

### Visualiser les logs en temps réel

```bash
# Logs de l'application Flask
tail -f logs/app.log

# Logs Nginx (clics)
docker exec prevention-server tail -f /var/log/nginx/clicks.log

# Logs Nginx (accès)
docker exec prevention-server tail -f /var/log/nginx/access.log
```

### Statistiques Nginx

```bash
# Nombre total de requêtes
docker exec prevention-server wc -l /var/log/nginx/access.log

# Top 10 des IPs
docker exec prevention-server awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -10
```

---

## 🔐 Checklist de Sécurité (Production)

Avant de déployer en production :

- [ ] Changer la `SECRET_KEY` dans `.env`
- [ ] Désactiver `debug=True` dans `app.py`
- [ ] Configurer un certificat SSL valide (Let's Encrypt)
- [ ] Protéger l'interface MailHog avec un reverse proxy + auth
- [ ] Configurer un pare-feu (UFW) pour bloquer les ports non nécessaires
- [ ] Mettre en place une BDD (SQLite/PostgreSQL) pour tracker les victimes
- [ ] Configurer une queue (Redis + RQ) pour les envois massifs
- [ ] Activer fail2ban pour bloquer les IPs suspectes
- [ ] Scanner les images Docker avec `trivy` ou `docker scan`
- [ ] Configurer des backups automatiques des logs

---

## 🛠️ Dépannage

### Erreur : "Template not found"

```bash
# Vérifier que le dossier templates/ existe
ls -la templates/

# Vérifier les permissions
chmod 755 templates/
chmod 644 templates/*.html
```

### Erreur : "SMTP connection failed"

```bash
# Vérifier que MailHog est actif
docker ps | grep mailhog

# Tester la connexion SMTP
telnet localhost 1025
```

### Erreur : "Port 443 already in use"

```bash
# Trouver le processus qui utilise le port
sudo lsof -i :443

# Arrêter Nginx système (si installé)
sudo systemctl stop nginx
```

---

## 📚 Structure du Projet

```
phishing-mail/
├── app.py                      # Application Flask sécurisée
├── phishing_server.py          # Module de gestion des emails (Jinja2)
├── requirements.txt            # Dépendances Python
├── .env                        # Variables d'environnement (SECRET_KEY)
├── .env.example                # Template de configuration
├── install.sh                  # Script d'installation automatique
├── check_victimes.sh           # Script de reporting sécurisé
├── docker-compose.yml          # Orchestration Docker (Nginx + MailHog)
├── nginx.conf                  # Configuration Nginx sécurisée
├── test_phishing_server.py     # Tests unitaires avec pytest
├── logs/
│   ├── app.log                 # Logs Flask
│   └── nginx/                  # Logs Nginx
├── ssl/
│   ├── nginx-selfsigned.crt    # Certificat SSL
│   └── nginx-selfsigned.key    # Clé privée SSL
├── templates/
│   ├── formulaire.html         # Interface web
│   ├── microsoft.html          # Template phishing Microsoft
│   ├── netflix.html            # Template phishing Netflix
│   └── support.html            # Template phishing Support IT
└── phishing-pages/
    └── index.html              # Page de prévention (cible du lien)
```

---

## 📖 Concepts Approfondis (Pour aller plus loin)

### 1. Injection de Template (SSTI)

**Ancien code (vulnérable)** :
```python
content = template_content.format(nom=user_input)
```

**Problème** : Si `user_input = "{__import__('os').system('rm -rf /')}"`, exécution de code arbitraire.

**Nouveau code (sécurisé)** :
```python
from jinja2 import Environment, select_autoescape
env = Environment(autoescape=select_autoescape(['html']))
template = env.from_string(template_content)
content = template.render(nom=user_input)  # Autoescaping activé
```

### 2. Rate Limiting avec Nginx

```nginx
# Limite 10 requêtes/seconde par IP avec burst de 20
limit_req_zone $binary_remote_addr zone=phishing_limit:10m rate=10r/s;
limit_req zone=phishing_limit burst=20 nodelay;
```

**Test** :
```bash
for i in {1..50}; do curl -I https://localhost/prevention -k; done | grep "429"
```

### 3. OWASP Top 10 Applicables

- **A03:2021 – Injection** : Corrigé par Jinja2 + validation email/nom
- **A05:2021 – Security Misconfiguration** : Headers de sécurité Nginx
- **A07:2021 – Identification and Authentication Failures** : Secret key persistante

---

## 📝 TODO (Améliorations futures)

- [ ] Implémenter une base de données SQLite/PostgreSQL
- [ ] Ajouter une interface d'administration (stats, graphiques)
- [ ] Configurer un système de queue (Redis + RQ) pour envois massifs
- [ ] Ajouter des tests de charge (Locust)
- [ ] Créer un rapport PDF automatique (ReportLab)
- [ ] Intégrer une API REST pour les webhooks
- [ ] Dockeriser aussi l'application Flask

---

## 👥 Auteurs

- **LURDE Nathan**
- **CLAVERIE Dimitri**
- **SUDRE Théo**

**Institut Limayrac - BTS CIEL 2026**

---

## 📜 Licence

Ce projet est à usage éducatif uniquement. Toute utilisation malveillante est strictement interdite.

---

## 🆘 Support

En cas de problème :
1. Vérifier les logs : `tail -f logs/app.log`
2. Consulter la documentation : [Flask](https://flask.palletsprojects.com/), [Nginx](https://nginx.org/en/docs/)
3. Ouvrir une issue sur le dépôt Git
