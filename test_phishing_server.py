"""
Tests unitaires pour le module phishing_server_secure.py
Utilisation: pytest tests/test_phishing_server.py -v
"""

import pytest
from unittest.mock import Mock, patch, MagicMock
import os
import tempfile
import shutil
from phishing_server_secure import (
    PhishingTemplateSecure,
    PhishingEmail,
    SMTPSessionSecure
)


# ==================== FIXTURES ====================

@pytest.fixture
def temp_template_dir():
    """Crée un dossier temporaire avec des templates de test."""
    temp_dir = tempfile.mkdtemp()
    
    # Template simple
    with open(os.path.join(temp_dir, "test.html"), "w") as f:
        f.write("<html><body>Hello {{ nom }}, click <a href='{{ url }}'>here</a></body></html>")
    
    # Template avec script (doit être escapé)
    with open(os.path.join(temp_dir, "xss_test.html"), "w") as f:
        f.write("<html><body>{{ script_tag }}</body></html>")
    
    yield temp_dir
    
    # Cleanup
    shutil.rmtree(temp_dir)


@pytest.fixture
def template_manager(temp_template_dir):
    """Retourne une instance de PhishingTemplateSecure avec un dossier temporaire."""
    return PhishingTemplateSecure(template_folder=temp_template_dir)


# ==================== TESTS PhishingTemplateSecure ====================

def test_template_init_with_valid_folder(temp_template_dir):
    """Test d'initialisation avec un dossier valide."""
    manager = PhishingTemplateSecure(template_folder=temp_template_dir)
    assert manager.template_folder == temp_template_dir
    assert manager.env is not None


def test_template_init_with_invalid_folder():
    """Test d'initialisation avec un dossier inexistant."""
    with pytest.raises(FileNotFoundError):
        PhishingTemplateSecure(template_folder="/nonexistent/folder")


def test_get_content_with_valid_template(template_manager):
    """Test de rendu d'un template valide."""
    content = template_manager.get_content(
        "test.html",
        nom="Jean Dupont",
        url="https://example.com"
    )
    assert content is not None
    assert "Jean Dupont" in content
    assert "https://example.com" in content


def test_get_content_with_missing_template(template_manager):
    """Test avec un template inexistant."""
    content = template_manager.get_content("nonexistent.html", nom="Test")
    assert content is None


def test_get_content_xss_protection(template_manager):
    """Test de la protection contre l'injection XSS."""
    malicious_script = "<script>alert('XSS')</script>"
    content = template_manager.get_content(
        "xss_test.html",
        script_tag=malicious_script
    )
    
    # Le script doit être escapé (< devient &lt;)
    assert content is not None
    assert "<script>" not in content
    assert "&lt;script&gt;" in content or "alert" not in content


# ==================== TESTS PhishingEmail ====================

def test_email_creation():
    """Test de création d'un objet email."""
    email = PhishingEmail(
        sender="test@example.com",
        receiver="victim@example.com",
        subject="Test Subject",
        html_body="<html><body>Test</body></html>"
    )
    
    assert email.message['From'] == "test@example.com"
    assert email.message['To'] == "victim@example.com"
    assert email.message['Subject'] == "Test Subject"


def test_email_as_string():
    """Test de conversion de l'email en string."""
    email = PhishingEmail(
        sender="test@example.com",
        receiver="victim@example.com",
        subject="Test",
        html_body="<p>Test</p>"
    )
    
    email_str = email.as_string()
    assert isinstance(email_str, str)
    assert "From: test@example.com" in email_str
    assert "To: victim@example.com" in email_str


# ==================== TESTS SMTPSessionSecure ====================

def test_smtp_session_init():
    """Test d'initialisation de la session SMTP."""
    session = SMTPSessionSecure(host="smtp.test.com", port=587, timeout=5)
    assert session.host == "smtp.test.com"
    assert session.port == 587
    assert session.timeout == 5


@patch('smtplib.SMTP')
def test_smtp_send_success(mock_smtp):
    """Test d'envoi réussi d'un email."""
    # Mock du serveur SMTP
    mock_server = MagicMock()
    mock_smtp.return_value.__enter__.return_value = mock_server
    
    # Création de l'email
    email = PhishingEmail(
        sender="test@example.com",
        receiver="victim@example.com",
        subject="Test",
        html_body="<p>Test</p>"
    )
    
    # Envoi
    session = SMTPSessionSecure()
    result = session.send(email)
    
    # Vérifications
    assert result is True
    mock_smtp.assert_called_once_with('localhost', 1025, timeout=10)
    mock_server.sendmail.assert_called_once()


@patch('smtplib.SMTP')
def test_smtp_send_connection_error(mock_smtp):
    """Test d'échec de connexion SMTP."""
    import smtplib
    
    # Simule une erreur de connexion
    mock_smtp.side_effect = smtplib.SMTPConnectError(421, "Cannot connect")
    
    email = PhishingEmail(
        sender="test@example.com",
        receiver="victim@example.com",
        subject="Test",
        html_body="<p>Test</p>"
    )
    
    session = SMTPSessionSecure()
    
    with pytest.raises(Exception) as exc_info:
        session.send(email)
    
    assert "connexion" in str(exc_info.value).lower()


@patch('smtplib.SMTP')
def test_smtp_send_general_error(mock_smtp):
    """Test d'erreur générique SMTP."""
    import smtplib
    
    # Simule une erreur SMTP
    mock_server = MagicMock()
    mock_server.sendmail.side_effect = smtplib.SMTPException("SMTP Error")
    mock_smtp.return_value.__enter__.return_value = mock_server
    
    email = PhishingEmail(
        sender="test@example.com",
        receiver="victim@example.com",
        subject="Test",
        html_body="<p>Test</p>"
    )
    
    session = SMTPSessionSecure()
    
    with pytest.raises(Exception) as exc_info:
        session.send(email)
    
    assert "SMTP" in str(exc_info.value)


# ==================== TESTS D'INTÉGRATION ====================

def test_full_workflow(temp_template_dir):
    """Test du workflow complet: template -> email -> envoi (mocké)."""
    
    # 1. Création du template manager
    template_mgr = PhishingTemplateSecure(temp_template_dir)
    
    # 2. Rendu du template
    content = template_mgr.get_content(
        "test.html",
        nom="Victim Name",
        url="https://phishing.test/click"
    )
    assert content is not None
    
    # 3. Création de l'email
    email = PhishingEmail(
        sender="attacker@test.com",
        receiver="victim@test.com",
        subject="Urgent Action Required",
        html_body=content
    )
    assert email.message['Subject'] == "Urgent Action Required"
    
    # 4. Envoi (mocké)
    with patch('smtplib.SMTP') as mock_smtp:
        mock_server = MagicMock()
        mock_smtp.return_value.__enter__.return_value = mock_server
        
        session = SMTPSessionSecure()
        result = session.send(email)
        
        assert result is True
        mock_server.sendmail.assert_called_once()


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--cov=phishing_server_secure", "--cov-report=html"])
