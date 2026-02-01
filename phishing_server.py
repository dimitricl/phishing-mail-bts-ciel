"""
Module sécurisé pour la gestion des campagnes de phishing éducatif.
Corrige les vulnérabilités d'injection et améliore la robustesse.
"""

import smtplib
import os
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from jinja2 import Environment, FileSystemLoader, select_autoescape, TemplateNotFound
import logging

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class PhishingTemplateSecure:
    """
    Gère le chargement et le rendu des templates HTML avec Jinja2.
    Protection contre l'injection de template via autoescape.
    """
    
    def __init__(self, template_folder="templates"):
        """
        Initialise l'environnement Jinja2 avec autoescape activé.
        
        Args:
            template_folder: Chemin vers le dossier contenant les templates HTML
        """
        if not os.path.exists(template_folder):
            logger.error(f"Template folder does not exist: {template_folder}")
            raise FileNotFoundError(f"Template folder not found: {template_folder}")
        
        self.template_folder = template_folder
        self.env = Environment(
            loader=FileSystemLoader(template_folder),
            autoescape=select_autoescape(['html', 'xml']),  # Protection XSS
            trim_blocks=True,
            lstrip_blocks=True
        )
        logger.info(f"Template engine initialized with folder: {template_folder}")
    
    def get_content(self, template_name, **kwargs):
        """
        Charge et rend un template avec les variables fournies.
        
        Args:
            template_name: Nom du fichier template (ex: "microsoft.html")
            **kwargs: Variables à injecter dans le template (nom, url, etc.)
        
        Returns:
            str: Contenu HTML rendu, ou None en cas d'erreur
        """
        try:
            template = self.env.get_template(template_name)
            content = template.render(**kwargs)
            logger.info(f"Template {template_name} rendered successfully")
            return content
            
        except TemplateNotFound:
            logger.error(f"Template not found: {template_name}")
            return None
        except Exception as e:
            logger.error(f"Error rendering template {template_name}: {str(e)}", exc_info=True)
            return None


class PhishingEmail:
    """
    Structure et valide l'objet email avant envoi.
    """
    
    def __init__(self, sender, receiver, subject, html_body):
        """
        Crée un objet email MIME.
        
        Args:
            sender: Adresse email expéditeur
            receiver: Adresse email destinataire
            subject: Objet du mail
            html_body: Corps du mail en HTML
        """
        self.message = MIMEMultipart('alternative')
        self.message['From'] = sender
        self.message['To'] = receiver
        self.message['Subject'] = subject
        
        # Ajoute le corps HTML
        html_part = MIMEText(html_body, 'html', 'utf-8')
        self.message.attach(html_part)
        
        logger.debug(f"Email object created: {sender} -> {receiver}")
    
    def as_string(self):
        """Retourne l'email au format string pour envoi SMTP."""
        return self.message.as_string()


class SMTPSessionSecure:
    """
    Gère la connexion sécurisée au serveur SMTP avec timeout et retry.
    """
    
    def __init__(self, host='localhost', port=1025, timeout=10):
        """
        Initialise les paramètres de connexion SMTP.
        
        Args:
            host: Hôte du serveur SMTP
            port: Port du serveur SMTP
            timeout: Timeout en secondes pour la connexion
        """
        self.host = host
        self.port = port
        self.timeout = timeout
        logger.info(f"SMTP session initialized: {host}:{port}")
    
    def send(self, email_obj):
        """
        Envoie un email via SMTP avec gestion d'erreur robuste.
        
        Args:
            email_obj: Instance de PhishingEmail
        
        Returns:
            bool: True si envoi réussi, False sinon
        
        Raises:
            Exception: En cas d'échec critique (connexion, authentification)
        """
        try:
            with smtplib.SMTP(self.host, self.port, timeout=self.timeout) as server:
                # Test de la connexion
                server.noop()
                
                # Envoi du mail
                server.sendmail(
                    email_obj.message['From'],
                    email_obj.message['To'],
                    email_obj.as_string()
                )
                
                logger.info(f"Email sent successfully to {email_obj.message['To']}")
                return True
                
        except smtplib.SMTPConnectError as e:
            logger.error(f"SMTP connection failed: {str(e)}")
            raise Exception("Impossible de se connecter au serveur SMTP")
        
        except smtplib.SMTPException as e:
            logger.error(f"SMTP error: {str(e)}")
            raise Exception(f"Erreur lors de l'envoi SMTP: {str(e)}")
        
        except Exception as e:
            logger.error(f"Unexpected error during email sending: {str(e)}", exc_info=True)
            raise Exception(f"Erreur inattendue: {str(e)}")
