import os
import re
import logging
from flask import Flask, render_template, request, flash, redirect, url_for
from email_validator import validate_email, EmailNotValidError
from phishing_server import PhishingTemplateSecure, PhishingEmail, SMTPSessionSecure

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

app = Flask(__name__)
app.secret_key = os.getenv('SECRET_KEY', os.urandom(24))

# Configuration
CONFIG = {
    "SMTP_SERVER": os.getenv("SMTP_SERVER", "localhost"),
    "SMTP_PORT": int(os.getenv("SMTP_PORT", "1025")),
    "BASE_URL": os.getenv("BASE_URL", "http://localhost:8080"),
    "TEMPLATES_DIR": os.getenv("TEMPLATES_DIR", "templates"),
    "MAX_NAME_LENGTH": 50,
    "ALLOWED_TEMPLATES": ["microsoft", "netflix", "support"]
}

# Regex pour valider le nom (alphanumeric + espaces uniquement)
NAME_REGEX = re.compile(r'^[a-zA-Z0-9\s\-\']{1,50}$')

@app.route('/')
def index():
    return render_template('formulaire.html', templates=CONFIG["ALLOWED_TEMPLATES"])

@app.route('/envoyer', methods=['POST'])
def envoyer():
    email = request.form.get('email', '').strip()
    nom = request.form.get('nom', '').strip()
    template_name = request.form.get('template', '').strip()
    
    print(f"--- Tentative d'envoi vers {email} ---")
    
    # Validation 1 : Email
    try:
        valid_email = validate_email(email, check_deliverability=False)
        email = valid_email.normalized
    except EmailNotValidError as e:
        print(f"❌ Erreur : Email invalide - {str(e)}")
        flash(f"Email invalide : {str(e)}", "error")
        return redirect(url_for('index'))
    
    # Validation 2 : Nom (regex)
    if not NAME_REGEX.match(nom):
        print(f"❌ Erreur : Caractères non autorisés dans le nom")
        flash("Le nom contient des caractères non autorisés", "error")
        return redirect(url_for('index'))
    
    if len(nom) > CONFIG["MAX_NAME_LENGTH"]:
        print(f"❌ Erreur : Nom trop long")
        flash(f"Le nom ne peut pas dépasser {CONFIG['MAX_NAME_LENGTH']} caractères", "error")
        return redirect(url_for('index'))
    
    # Validation 3 : Template autorisé
    if template_name not in CONFIG["ALLOWED_TEMPLATES"]:
        print(f"❌ Erreur : Template non autorisé : {template_name}")
        flash("Template non autorisé", "error")
        return redirect(url_for('index'))
    
    try:
        # Génération de l'URL de tracking
        url_clic = f"{CONFIG['BASE_URL']}/?victime={nom}"
        
        # Rendu du template avec Jinja2
        template_engine = PhishingTemplateSecure(CONFIG["TEMPLATES_DIR"])
        html_content = template_engine.get_content(
            f"{template_name}.html",
            nom=nom,
            url=url_clic
        )
        
        # Création de l'email
        email_obj = PhishingEmail(
            sender="security-alert@simulation-lab.local",
            receiver=email,
            subject="🔒 Alerte de sécurité : Action requise",
            html_body=html_content
        )
        
        # Envoi SMTP
        smtp_session = SMTPSessionSecure(
            CONFIG["SMTP_SERVER"],
            CONFIG["SMTP_PORT"]
        )
        smtp_session.send(email_obj)
        
        print(f"✅ Succès : Mail envoyé à {nom}")
        flash(f"Email de phishing envoyé avec succès à {email}", "success")
        
    except Exception as e:
        print(f"❌ Erreur lors de l'envoi: {str(e)}")
        flash(f"Erreur lors de l'envoi : {str(e)}", "error")
    
    return redirect(url_for('index'))

if __name__ == '__main__':
    print("🚀 Interface de Phishing lancée sur http://localhost:5000")
    app.run(debug=True, host='0.0.0.0', port=5000)
