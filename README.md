# 🎯 Phishing Mail - Sensibilisation BTS CIEL

> Application Flask pour campagnes de phishing éducatif  
> **BTS CIEL - Institut Limayrac 2026**

[![Python](https://img.shields.io/badge/Python-3.10+-blue.svg)](https://www.python.org/)
[![Flask](https://img.shields.io/badge/Flask-3.0-green.svg)](https://flask.palletsprojects.com/)
[![Security](https://img.shields.io/badge/Security-Enhanced-brightgreen.svg)]()

---

## 🚀 Installation Rapide

### Prérequis
- Python 3.10+
- Docker et Docker Compose
- Git

### Installation en une commande
```bash
git clone https://github.com/dimitricl/phishing-mail-bts-ciel.git
cd phishing-mail-bts-ciel
./setup.sh
```

### Lancement
```bash
source venv/bin/activate
python3 app.py
```

### Accès aux services
- **Interface Flask** : http://localhost:5000
- **MailHog (emails)** : http://localhost:8025
- **Nginx (tracking)** : http://localhost:8080

---

## 🔒 Sécurité

### Vulnérabilités corrigées
✅ **Injection de template (SSTI)** - Jinja2 avec autoescape  
✅ **Validation d'input** - email-validator + regex strict  
✅ **XSS Protection** - Caractères spéciaux bloqués  
✅ **Path Traversal** - Whitelist de templates  
✅ **Rate Limiting** - Nginx (10 req/sec)  
✅ **Headers de sécurité** - HSTS, X-Frame-Options, CSP  

### Tests de sécurité
```bash
# Lancer tous les tests
./run_integration_tests.sh

# Vérifier les victimes
./check_victimes.sh
```

---

## 📊 Structure du Projet
```
phishing-lab/
├── app.py                    # Application Flask sécurisée
├── phishing_server.py        # Module SMTP avec Jinja2
├── requirements.txt          # Dépendances Python
├── .env.example              # Configuration à copier
├── setup.sh                  # Installation automatique
├── docker-compose.yml        # Nginx + MailHog
├── nginx.conf                # Configuration Nginx
├── templates/                # Templates d'emails
│   ├── microsoft.html
│   ├── netflix.html
│   └── support.html
└── phishing-pages/           # Page de prévention
    └── index.html
```

---

## 🎮 Utilisation

### 1. Envoyer un email de test
```bash
curl -X POST http://localhost:5000/envoyer \
  -d "email=victim@example.com" \
  -d "nom=Jean Dupont" \
  -d "template=microsoft"
```

### 2. Consulter MailHog

Ouvrir http://localhost:8025

### 3. Vérifier les statistiques
```bash
./check_victimes.sh
```

---

## 🧪 Tests
```bash
# Tests unitaires
pytest test_phishing_server.py -v

# Tests d'intégration
./run_integration_tests.sh
```

---

## 👥 Auteurs

- **LURDE Nathan**
- **CLAVERIE Dimitri**
- **SUDRE Théo**

**Institut Limayrac - BTS CIEL 2026**

---

## 📜 Licence

Usage éducatif uniquement. Interdiction stricte d'utilisation malveillante.
