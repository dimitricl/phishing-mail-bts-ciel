import os
from flask import Flask, render_template, request, flash
# Import des classes depuis phishing_server.py
from phishing_server import PhishingTemplateSecure, PhishingEmail, SMTPSessionSecure

app = Flask(__name__)
app.secret_key = os.urandom(24)

# --- CONFIGURATION CENTRALISÉE ---
# On utilise un dictionnaire pour regrouper les paramètres
CONFIG = {
    "SMTP_SERVER": "localhost",
    "SMTP_PORT": 1025,
    "BASE_URL": "http://localhost:8080",
    "TEMPLATES_DIR": "templates"
}

@app.route('/', methods=['GET', 'POST'])
@app.route('/envoyer', methods=['POST'])
def index():
    templates_dispo = ["microsoft", "netflix", "support"]
    
    if request.method == 'POST':
        target_email = request.form.get('email')
        target_name = request.form.get('nom') # Correspond au 'name="nom"' de ton HTML
        selected_template = request.form.get('template')

        # FIX : On accède à la valeur via le dictionnaire CONFIG
        url_clic = f"{CONFIG['BASE_URL']}/?victime={target_name}"
        
        try:
            print(f"--- Tentative d'envoi vers {target_email} ---")
            
            # 2. Génération du contenu
            template_mgr = PhishingTemplateSecure(template_folder=CONFIG['TEMPLATES_DIR'])
            body = template_mgr.get_content(
                f"{selected_template}.html", 
                nom=target_name, 
                url=url_clic
            )
            
            if body is None:
                raise Exception(f"Template {selected_template}.html introuvable.")

            # 3. Création de l'objet Email
            email_obj = PhishingEmail(
                sender="security-alert@simulation-lab.local",
                receiver=target_email,
                subject="⚠️ Alerte de sécurité : Action requise",
                html_body=body
            )

            # 4. Envoi (Accès aux variables via CONFIG)
            # Utilisation directe car ta SMTPSession actuelle ne gère pas encore le 'with'
            session = SMTPSessionSecure(CONFIG['SMTP_SERVER'], CONFIG['SMTP_PORT'])
            session.send(email_obj)
            
            print(f"✅ Succès : Mail envoyé à {target_name}")
            flash(f"✅ Simulation envoyée avec succès à {target_name}", "success")
            
        except Exception as e:
            print(f"❌ Erreur : {str(e)}")
            flash(f"❌ Erreur lors de l'envoi : {str(e)}", "danger")
            
    return render_template('formulaire.html', templates=templates_dispo)

if __name__ == "__main__":
    if not os.path.exists("./ssl/nginx-selfsigned.crt"):
        print("⚠️ Attention : Certificat SSL manquant dans ./ssl/.")
    
    print("🚀 Interface de Phishing lancée sur http://localhost:5000")
    app.run(port=5000, debug=True)
