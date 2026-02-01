# 🔐 Guide d'Audit de Sécurité - Projet Phishing Mail

> Checklist complète pour auditer et sécuriser l'application avant déploiement

---

## 📋 Table des matières

1. [Vulnérabilités corrigées](#vulnérabilités-corrigées)
2. [Tests de pénétration](#tests-de-pénétration)
3. [Hardening du système](#hardening-du-système)
4. [Monitoring et alertes](#monitoring-et-alertes)
5. [Plan de réponse aux incidents](#plan-de-réponse-aux-incidents)

---

## 1. Vulnérabilités Corrigées

### 🚨 CRITIQUE (Corrigé)

#### A. Injection de Template (SSTI)
**Ancien code** :
```python
content = template_content.format(nom=user_input, url=url)
```

**Risque** : Exécution de code arbitraire  
**Payload d'attaque** :
```python
nom = "{__import__('os').system('cat /etc/passwd')}"
```

**Correction** :
```python
from jinja2 import Environment, select_autoescape
env = Environment(autoescape=select_autoescape(['html']))
template = env.from_string(template_content)
content = template.render(nom=user_input, url=url)
```

**Test de validation** :
```bash
# Tentative d'injection
curl -X POST http://localhost:5000/envoyer \
  -d "email=test@test.com" \
  -d "nom={{7*7}}" \
  -d "template=microsoft"

# Vérifier que le nom reste littéral "{{7*7}}" et n'est pas calculé
```

---

#### B. Command Injection via logs
**Ancien script** :
```bash
docker exec prevention-server cat /var/log/nginx/access.log | grep "victime=" | awk -F'victime=' '{print $2}' | awk '{print $1}'
```

**Risque** : Si un nom contient `; rm -rf /`, injection de commande

**Correction** :
- Utilisation de `sh -c` avec guillemets sécurisés
- Pas d'eval ou de substitution de variables non échappées
- Limitation à 30 caractères pour l'affichage

**Test de validation** :
```bash
# Tentative d'injection
curl -k "https://localhost/prevention?victime=test;whoami"

# Vérifier que la commande n'est pas exécutée
./check_victimes.sh | grep "whoami"  # Ne doit rien afficher
```

---

#### C. Information Disclosure
**Ancien code** :
```python
except Exception as e:
    raise Exception(f"Échec SMTP sur {self.host}:{self.port} -> {str(e)}")
```

**Risque** : Exposition de l'infrastructure interne (host, port)

**Correction** :
```python
except smtplib.SMTPConnectError as e:
    logger.error(f"SMTP connection failed: {str(e)}")
    raise Exception("Impossible de se connecter au serveur SMTP")
```

**Test de validation** :
```bash
# Arrêter MailHog
docker stop mailhog-smtp

# Tenter un envoi
curl -X POST http://localhost:5000/envoyer -d "email=test@test.com" -d "nom=Test" -d "template=microsoft"

# Vérifier que l'erreur ne contient pas "localhost:1025"
```

---

### ⚠️ ÉLEVÉ (Corrigé)

#### D. Secret Key non persistante
**Ancien code** :
```python
app.secret_key = os.urandom(24)
```

**Risque** : Toutes les sessions Flask sont invalidées à chaque redémarrage

**Correction** :
```python
app.secret_key = os.getenv('SECRET_KEY', 'CHANGE_ME_IN_PRODUCTION')
```

**Test de validation** :
```bash
# Générer une clé
python3 -c "import secrets; print(secrets.token_hex(32))"

# Vérifier dans .env
grep "SECRET_KEY" .env

# Vérifier que la clé n'est pas la valeur par défaut
grep "CHANGE_ME" .env && echo "⚠️ Clé par défaut détectée !"
```

---

#### E. Validation d'Input insuffisante
**Ancien code** : Aucune validation de `email` et `nom`

**Risque** :
- XSS dans les logs
- Injection SQL (si BDD ajoutée)
- Crash de l'app (noms de 10 000 caractères)

**Correction** :
```python
from email_validator import validate_email, EmailNotValidError

# Validation email
valid = validate_email(target_email, check_deliverability=False)
target_email = valid.normalized

# Validation nom
if not re.match(r"^[a-zA-ZÀ-ÿ0-9\s\-']+$", name):
    raise ValueError("Caractères non autorisés")
```

**Test de validation** :
```bash
# Email invalide
curl -X POST http://localhost:5000/envoyer -d "email=not_an_email" -d "nom=Test" -d "template=microsoft"

# Nom avec caractères spéciaux
curl -X POST http://localhost:5000/envoyer -d "email=test@test.com" -d "nom=<script>alert(1)</script>" -d "template=microsoft"

# Les deux doivent être rejetés
```

---

### 🔵 MOYEN (Corrigé)

#### F. Absence de Rate Limiting
**Risque** : Attaque par déni de service (DoS)

**Correction** :
```nginx
limit_req_zone $binary_remote_addr zone=phishing_limit:10m rate=10r/s;
limit_req zone=phishing_limit burst=20 nodelay;
```

**Test de validation** :
```bash
# Envoyer 50 requêtes rapidement
for i in {1..50}; do curl -k -I https://localhost/prevention?test=$i; done | grep -c "429"

# Doit retourner au moins 15 codes 429
```

---

#### G. Headers de Sécurité manquants
**Risque** : Clickjacking, MITM

**Correction** :
```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
```

**Test de validation** :
```bash
curl -k -I https://localhost/prevention | grep -i "strict-transport"
curl -k -I https://localhost/prevention | grep -i "x-frame-options"
```

---

#### H. Logs sans rotation
**Risque** : Saturation du disque

**Correction** :
```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

**Test de validation** :
```bash
# Vérifier la config Docker
docker inspect prevention-server | grep -A 5 "LogConfig"
```

---

## 2. Tests de Pénétration

### 🎯 Scénarios d'attaque à tester

#### Scénario 1 : Path Traversal
**Objectif** : Lire `/etc/passwd` via le paramètre `template`

```bash
# Attaque
curl -X POST http://localhost:5000/envoyer \
  -d "email=test@test.com" \
  -d "nom=Test" \
  -d "template=../../../etc/passwd"

# Résultat attendu : Rejeté avec "Template non autorisé"
```

#### Scénario 2 : XSS Reflected
**Objectif** : Injecter du JavaScript dans les messages Flash

```bash
# Attaque
curl -X POST http://localhost:5000/envoyer \
  -d "email=test@test.com" \
  -d "nom=<img src=x onerror=alert(1)>" \
  -d "template=microsoft"

# Résultat attendu : Caractères échappés ou rejetés
```

#### Scénario 3 : SMTP Relay
**Objectif** : Utiliser le serveur SMTP comme relais ouvert

```bash
# Attaque
telnet localhost 1025
MAIL FROM: <attacker@evil.com>
RCPT TO: <victim@external.com>
DATA
Subject: Spam
Test
.
QUIT

# Résultat attendu : MailHog n'est qu'un serveur de test, pas de relay
```

#### Scénario 4 : DoS via emails massifs
**Objectif** : Saturer MailHog

```bash
# Attaque
for i in {1..1000}; do
  curl -X POST http://localhost:5000/envoyer \
    -d "email=victim$i@test.com" \
    -d "nom=Victim$i" \
    -d "template=microsoft" &
done

# Résultat attendu : Rate limiting bloque après 20 requêtes
```

---

## 3. Hardening du Système

### 🔒 Checklist de durcissement

#### Niveau Application
- [ ] `debug=False` en production
- [ ] Secret key de 32+ caractères en variable d'env
- [ ] Logs en mode `INFO` (pas `DEBUG`)
- [ ] Validation stricte de tous les inputs
- [ ] Timeouts sur toutes les requêtes réseau
- [ ] Pas de `eval()`, `exec()`, ou `pickle.loads()` dans le code

#### Niveau Docker
- [ ] Images Docker à jour (`docker pull nginx:alpine`)
- [ ] Scan des vulnérabilités : `docker scan nginx:alpine`
- [ ] Utilisateur non-root dans les conteneurs
- [ ] Volumes montés en `:ro` (read-only)
- [ ] Network isolation avec `networks:`

#### Niveau Nginx
- [ ] Certificat SSL valide (Let's Encrypt)
- [ ] TLS 1.3 uniquement
- [ ] Désactivation de SSLv3, TLS 1.0, TLS 1.1
- [ ] `server_tokens off;` (masque la version Nginx)
- [ ] `client_max_body_size 1M;`
- [ ] Logs en dehors du conteneur

#### Niveau Système (Ubuntu)
- [ ] Pare-feu actif : `sudo ufw enable`
- [ ] Fermer les ports inutiles : `sudo ufw deny 8025` (MailHog web)
- [ ] fail2ban configuré pour bloquer les IPs suspectes
- [ ] Mises à jour automatiques : `sudo apt install unattended-upgrades`
- [ ] SSH avec clés uniquement (pas de mot de passe)

---

## 4. Monitoring et Alertes

### 📊 Métriques à surveiller

#### Application
```bash
# Taux d'erreur
grep "ERROR" logs/app.log | wc -l

# Temps de réponse moyen
grep "Email sent" logs/app.log | tail -100

# Nombre d'envois par heure
grep "Tentative d'envoi" logs/app.log | grep "$(date +%H:)" | wc -l
```

#### Nginx
```bash
# Codes HTTP 4xx/5xx
docker exec prevention-server awk '{print $9}' /var/log/nginx/access.log | sort | uniq -c

# Top 10 IPs
docker exec prevention-server awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -10

# Taille des logs
du -sh logs/nginx/
```

#### Système
```bash
# CPU/RAM des conteneurs
docker stats --no-stream

# Espace disque
df -h | grep "/var/lib/docker"
```

### 🚨 Alertes critiques

Configurer des alertes si :
- Taux d'erreur > 5% sur 5 minutes
- Espace disque < 10%
- Plus de 100 requêtes 429 en 1 minute (DoS)
- Tentative d'accès à `/etc/passwd` dans les logs

---

## 5. Plan de Réponse aux Incidents

### 🚨 Incident : Injection détectée

1. **Isoler** : `docker stop prevention-server mailhog-smtp`
2. **Analyser** : `grep "injection" logs/app.log`
3. **Patcher** : Mettre à jour le code vulnérable
4. **Tester** : `./run_integration_tests.sh`
5. **Redémarrer** : `docker-compose up -d`

### 🚨 Incident : Logs saturés

1. **Vérifier** : `du -sh logs/`
2. **Nettoyer** :
   ```bash
   find logs/ -type f -mtime +7 -delete  # Supprime logs > 7 jours
   ```
3. **Configurer rotation** :
   ```bash
   # /etc/logrotate.d/phishing-mail
   /home/user/phishing-mail/logs/*.log {
       daily
       rotate 7
       compress
       delaycompress
       notifempty
   }
   ```

### 🚨 Incident : Certificat SSL expiré

1. **Vérifier** : `openssl x509 -in ssl/nginx-selfsigned.crt -noout -dates`
2. **Régénérer** :
   ```bash
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout ssl/nginx-selfsigned.key \
     -out ssl/nginx-selfsigned.crt
   ```
3. **Redémarrer** : `docker restart prevention-server`

---

## 📚 Ressources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CWE Top 25](https://cwe.mitre.org/top25/)
- [Nginx Security Controls](https://www.nginx.com/blog/nginx-security-controls/)
- [Docker Security Best Practices](https://docs.docker.com/develop/security-best-practices/)

---

**Dernière mise à jour** : Février 2026  
**Auteurs** : LURDE Nathan, CLAVERIE Dimitri, SUDRE Théo
