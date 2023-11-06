from tpctools.utils import email_utils
from os import environ, path

logfile = "/tmp/incremental_build.log"
indexCountFile = "/data/textpresso/luceneindex_new/cc.cfg"


def send_report():

    MOD = environ['MOD']
    email_subject = f"{MOD} Textpresso Incremental Build Report"

    email_message = compose_message()

    email_utils.send_report(email_subject, email_message)

def compose_message():

    f = open(logfile)
    total_pdf_count = None
    total_cas1_count = None
    total_cas2_count = None
    total_indexed = None
    empty_cas1_files = None
    empty_cas1_files = None
    new_papers = []
    for line in f:
        if line.startswith("Total new PDF file(s):"):
            total_pdf_count = line.strip().replace("Total new PDF file(s):", "")
        if line.startswith("Total new CAS-1 file(s):"):
            total_cas1_count = line.strip().replace("Total new CAS-1 file(s):", "")
        if line.startswith("Empty CAS-1 file(s):"):
            empty_cas1_files = line.strip().replace("Empty CAS-1 file(s):", "")
        if line.startswith("Total new CAS-2 file(s):"):
            total_cas2_count = line.strip().replace("Total new CAS-2 file(s):", "")
        if line.startswith("Empty CAS-2 file(s):"):
            empty_cas2_files = line.strip().replace("Empty CAS-2 file(s):", "")
        if "tpcas-2_new" in line and 'AGRKB:' in line:
            ref_curie = line.strip().split('/')[-1].split('.tpcas')[0]
            new_papers.append(ref_curie) 
    f.close()

    if path.exists(indexCountFile):
        f = open(indexCountFile)
        for line in f:
            pieces = line.strip().split(' ')
            total_indexed = pieces[-1]
    else:
        total_indexed = total_cas2_count

    rows = ""
    for (label, count) in [('PDF downloaded', total_pdf_count),
                           ('CAS-1 files generated', total_cas1_count),
                           ('Empty CAS-1 files', empty_cas1_files),
                           ('CAS-2 files generated', total_cas2_count),
                           ('Empty CAS-2 files', empty_cas2_files),
                           ('New Papers added into index', total_indexed)]:
        rows = rows + f"<tr><th style='text-align:left' width='300'>{label}</th><td width='100'>{count}</td></tr>"
    email_message = "<table></tbody>" + rows + "</tbody></table>"
    email_message = email_message + "<p>The logfile is available at /tmp/incremental_build.log</p>"
    email_message = email_message + "<p>The full-text files for the following papers have just been added to Textpresso."
    email_message = email_message + "<p>" + "<br>".join(new_papers) + "<p>" 
    return email_message	


if __name__ == "__main__":
    
    send_report()
