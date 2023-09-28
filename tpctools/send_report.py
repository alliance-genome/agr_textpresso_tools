from tpctools.utils import email_utils
from os import environ

## process logs files here to generate a reasonal report

MOD = environ['MOD']

email_subject = f"{MOD} Textpresso Incremental Build Report"

email_message = "A message about how many new papers have been added in this build and any errors occurred etc etc"

email_utils.send_report(email_subject, email_message)

exit()