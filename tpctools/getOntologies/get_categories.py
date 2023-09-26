import urllib.request
import json
import time
import argparse
from os import rename
from get_sgd_specific_categories import create_obo_file
from tpctools.utils.okta_utils import (
    get_authentication_token,
    generate_headers
)

parser = argparse.ArgumentParser()
parser.add_argument('--mod', dest='mod', type=str, help='Mod to procoess', required=True)
parser.add_argument('--page', dest='page_limit', type=str, help='Number of records retrieved at once. Defaults to 1000', required=False)
parser.add_argument('--all', dest='download_all', action='store_true', help='Download all prebuild ontologies in addition to mod ontologies.', required=False)
args = parser.parse_args()

if args.download_all:
    urllib.request.urlretrieve("http://current.geneontology.org/ontology/go-basic.obo", "go-basic.obo")
    urllib.request.urlretrieve("http://purl.obolibrary.org/obo/doid.obo", "doid.obo")
    urllib.request.urlretrieve("http://purl.obolibrary.org/obo/chebi.obo", "chebi.obo")
    urllib.request.urlretrieve("http://purl.obolibrary.org/obo/so.obo", "so.obo")
    urllib.request.urlretrieve("http://purl.obolibrary.org/obo/wbbt.obo", "wbbt.obo")


token = get_authentication_token()
headers = generate_headers(token)
mod = args.mod
if args.page_limit is None:
    page_limit = 1000
else:
    page_limit = args.page_limit
current_page = 0
records_printed = 0
ateam_site = "beta-curation.alliancegenome.org"
time = time.asctime()

if mod == 'SGD':
    id_prefix = 'sc'
    species_name = "S. cerevisiae"
elif mod == 'WB':
    id_prefix = 'ce'
    species_name = "C. elegans"
else:
    print("Mod not found... current options for --mod are SGD or WB")
    quit()

params = {"searchFilters":{"dataProviderFilter":{"dataProvider.sourceOrganization.abbreviation":{"queryString":mod,"tokenOperator":"OR"}}},"sortOrders":[],"aggregations":[],"nonNullFieldsTable":[]}

##Gene List Generation
f = open(f"gene_list_{mod}.obo", "w")
f.write("format-version: 1.2\n")
f.write(f"date: {time}\n")
f.write("saved-by: Textpresso\n")
f.write("auto-generated-by: get_categories.py\n\n")

f.write("[Term]\n")
f.write(f"id: tpg{id_prefix}:0000000\n")
f.write(f"name: Gene ({species_name})\n")

while True:
    url = f'https://alpha-curation.alliancegenome.org/api/gene/search?limit={page_limit}&page={current_page}'
    request_body = params
    request_data_encoded = json.dumps(request_body)
    request_data_encoded_str = str(request_data_encoded)
    request = urllib.request.Request(url=url, data=request_data_encoded_str.encode('utf-8'))
    request.add_header("Authorization", f"Bearer {token}")
    request.add_header("Content-type", "application/json")
    request.add_header("Accept", "application/json")
    with urllib.request.urlopen(request) as response:
        resp = response.read().decode("utf8")
        resp_obj = json.loads(resp)
    if resp_obj['returnedRecords'] < 1:
        break
    for result in resp_obj['results']:
        records_printed += 1
        f.write(f"\n[Term]\nid: tpg{id_prefix}:{records_printed:07d}\nname: {result['geneSymbol']['formatText']}\nis_a: tpg{id_prefix}:0000000 ! Gene ({species_name})\n")
    current_page += 1
    print (f"Total Gene Records Printed {records_printed} of {resp_obj['totalResults']}")
f.close()

##Allele List Generation
f = open(f"allele_list_{mod}.obo", "w")
f.write("format-version: 1.2\n")
f.write(f"date: {time}\n")
f.write("saved-by: Textpresso\n")
f.write("auto-generated-by: get_categories.py\n\n")

f.write("[Term]\n")
f.write(f"id: tpa{id_prefix}:0000000\n")
f.write(f"name: Allele ({species_name})\n")
current_page = 0
records_printed = 0

while True:
    url = f'https://alpha-curation.alliancegenome.org/api/allele/search?limit={page_limit}&page={current_page}'
    request_body = params
    request_data_encoded = json.dumps(request_body)
    request_data_encoded_str = str(request_data_encoded)
    request = urllib.request.Request(url=url, data=request_data_encoded_str.encode('utf-8'))
    request.add_header("Authorization", f"Bearer {token}")
    request.add_header("Content-type", "application/json")
    request.add_header("Accept", "application/json")
    with urllib.request.urlopen(request) as response:
        resp = response.read().decode("utf8")
        resp_obj = json.loads(resp)
    if resp_obj['returnedRecords'] < 1:
        break
    for result in resp_obj['results']:
        if 'alleleSymbol' in result:
            records_printed += 1
            f.write(f"\n[Term]\nid: tpa{id_prefix}:{records_printed:07d}\nname: {result['alleleSymbol']['formatText']}\nis_a: tpa{id_prefix}:0000000 ! Allele ({species_name})\n")
        else:
            print('Skipping entry...')
            print(result)
    current_page += 1
    print(f"Total Allele Records Printed {records_printed} of {resp_obj['totalResults']}")
f.close()

if mod == 'SGD':
    create_obo_file('tppsc', 'Protein',
                    "protein_saccharomyces_cerevisiae.obo")
    create_obo_file('tpssc', 'Strain',
                    "strain_saccharomyces_cerevisiae.obo")
    rename("allele_list_SGD.obo", "allele_saccharomyces_cerevisiae.obo")
    rename("gene_list_SGD.obo", "gene_saccharomyces_cerevisiae.obo")
