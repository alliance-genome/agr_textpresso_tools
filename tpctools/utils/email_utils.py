import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from os import environ
import logging

logging.basicConfig(format='%(message)s')
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def send_email(subject, recipients, msg, sender_email, sender_password, reply_to):

    try:
        message = MIMEMultipart("alternative")
        message["Subject"] = subject
        message["From"] = sender_email
        message["To"] = recipients
        message.add_header('reply-to', reply_to)
        html_message = MIMEText(msg, "html")
        message.attach(html_message)

        server = smtplib.SMTP_SSL("smtp.gmail.com", 465)
        server.login(sender_email, sender_password)
        any_recipients_error = server.send_message(message)
        server.quit()

        if(len(any_recipients_error) > 0):
            error_message = ''
            for key in any_recipients_error:
                error_message = error_message + ' ' + key + ' ' + str(any_recipients_error[key]) + ' ;' + '\n'

            error_message = "Email sending unsuccessful for this recipients " + error_message
            return ("error", error_message)

        return ("success", "Email was successfully sent.")

    except smtplib.SMTPHeloError as e:
        return ("error", "The server didn't reply properly to the hello greeting. " + str(e))
    except smtplib.SMTPRecipientsRefused as e:
        return ("error", "The server rejected ALL recipients (no mail was sent). " + str(e))
    except smtplib.SMTPSenderRefused as e:
        return ("error", "The server didn't accept the sender's email. " + str(e))
    except smtplib.SMTPDataError as e:
        return ("error", "The server replied with an unexpected error. " + str(e))
    except Exception as e:
        return ("error", "Error occured while sending email. " + str(e))


def send_report(email_subject, email_message, email=None):

    email_recipients = email
    if email_recipients is None:
        if environ.get('CRONTAB_EMAIL'):
            email_recipients = environ['CRONTAB_EMAIL']
        else:
            return

    sender_email = None
    if environ.get('SENDER_EMAIL'):
        sender_email = environ['SENDER_EMAIL']
    sender_password = None
    if environ.get('SENDER_PASSWORD'):
        sender_password = environ['SENDER_PASSWORD']
    reply_to = sender_email
    if environ.get('REPLY_TO'):
        reply_to = environ['REPLY_TO']

    (email_status, message) = send_email(email_subject, email_recipients, email_message,
                                         sender_email, sender_password, reply_to)
    if email_status == 'error':
        logger.info("Failed sending email to " + email_recipients + ": " + message + "\n")
