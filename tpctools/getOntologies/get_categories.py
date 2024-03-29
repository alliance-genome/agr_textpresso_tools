import urllib.request
import json
import time
from datetime import datetime 
import argparse
from os import rename

from get_sgd_specific_categories import create_obo_file
from tpctools.utils.okta_utils import get_authentication_token, generate_headers

API_URL = "https://curation.alliancegenome.org/api/"
PAGE_LIMIT = 1000

def get_category_data(mod, download_all=False):
    if download_all:
        download_all_ontologies(mod)

    id_prefix, species_name, filename_id = get_id_prefix_species_name(mod)
    now = time.asctime()
    token = get_authentication_token()
    headers = generate_headers(token)
    params = {
        "searchFilters": {
            "dataProviderFilter": {
                "dataProvider.sourceOrganization.abbreviation": {
                    "queryString": mod,
                    "tokenOperator": "OR"
                }
            }
        },
        "sortOrders": [],
        "aggregations": [],
        "nonNullFieldsTable": []
    }

    if mod == 'WB':
        generate_entity_list_from_a_team(mod, 'gene', params, id_prefix, species_name, filename_id, now, token, headers)
        generate_entity_list_from_a_team(mod, 'gene_synonym', params, 's' + id_prefix, species_name, filename_id, now, token, headers)
        generate_entity_list_from_a_team(mod, 'protein', params, id_prefix, species_name, filename_id, now, token, headers)
        generate_entity_list_from_a_team(mod, 'protein_synonym', params, 's' + id_prefix, species_name, filename_id, now, token, headers)
        # 2 hrs + ~45 min
        generate_entity_list_from_a_team(mod, 'allele', params, id_prefix, species_name, filename_id, now, token, headers)
    elif mod == 'MGI':
        generate_entity_list_from_a_team(mod, 'gene', params, id_prefix, species_name, filename_id, now, token, headers)
    elif mod == 'ZFIN':
        generate_entity_list_from_a_team(mod, 'gene', params, id_prefix, species_name, filename_id, now, token, headers)
        generate_entity_list_from_a_team(mod, 'allele', params, id_prefix, species_name, filename_id, now, token, headers)
        generate_entity_list_from_a_team(mod, 'fish', params, id_prefix, species_name, filename_id, now, token, headers)
    elif mod == 'FB':
        generate_entity_list_from_a_team(mod, 'gene', params, id_prefix, species_name, filename_id, now, token, headers)
    elif mod == 'SGD':
        generate_entity_list_from_a_team(mod, 'gene', params, id_prefix, species_name, filename_id, now, token, headers)
        generate_entity_list_from_a_team(mod, 'allele', params, id_prefix, species_name, filename_id, now, token, headers)
        create_obo_file('tppsc', 'Protein', "protein_saccharomyces_cerevisiae.obo")
        create_obo_file('tpssc', 'Strain', "strain_saccharomyces_cerevisiae.obo")


def generate_entity_list_from_a_team(mod, entity_type, params, id_prefix, species_name, filename_id, now, token, headers):
    if entity_type not in ["gene", "allele", "fish", "protein", "gene_synonym", "protein_synonym"]:
        return

    if entity_type.startswith("protein") and mod != "WB":
        return
    found_synonyms = set()
    entity_list_file = f"{entity_type}_{filename_id}.obo"
    with open(entity_list_file, "w") as f:
        entity_type_short = entity_type.split('_')[0]
        entity_type_short = "agm" if entity_type_short == "fish" else "gene" if entity_type_short == "protein" else entity_type_short
        tp_root_id = f"tp{entity_type[0]}{id_prefix}:0000000"
        root_name = entity_type.capitalize()
        root_name = root_name.replace("_synonym", " Synonym")
        write_obo_file_header(f, tp_root_id, root_name, species_name, now)

        current_page = 0
        records_printed = 0
        while True:
            url = f"{API_URL}{entity_type_short}/search?limit={PAGE_LIMIT}&page={current_page}"
            request_data_encoded = json.dumps(params).encode('utf-8')
            request = urllib.request.Request(url, data=request_data_encoded)
            request.add_header("Authorization", f"Bearer {token}")
            request.add_header("Content-type", "application/json")
            request.add_header("Accept", "application/json")

            with urllib.request.urlopen(request) as response:
                resp_obj = json.loads(response.read().decode("utf8"))

            if resp_obj['returnedRecords'] < 1:
                break

            for result in resp_obj['results']:
                entity_name = get_entity_name(entity_type, result, mod)
                if entity_name:
                    if mod != 'WB' or not entity_type.endswith("_synonym"):
                        records_printed += 1
                        tp_id = f"tp{entity_type[0]}{id_prefix}:{records_printed:07d}"
                        f.write(f"\n[Term]\nid: {tp_id}\nname: {entity_name}\nis_a: {tp_root_id} ! {root_name} ({species_name})\n")
                    
                if entity_type_short in ["gene", "allele"]:
                    if mod != 'WB' or entity_type.endswith("_synonym"):
                        synonymField = f"{entity_type_short}Synonyms"
                        if synonymField in result:
                            for s in result[synonymField]:
                                alias_name = s["displayText"]
                                if alias_name in found_synonyms:
                                    continue
                                found_synonyms.add(alias_name)
                                records_printed += 1
                                tp_id = f"tp{entity_type[0]}{id_prefix}:{records_printed:07d}"
                                if mod == "WB":
                                    if entity_type.startswith("protein"):
                                        alias_name = alias_name.upper()
                                    elif entity_type.startswith("gene"):
                                        alias_name = alias_name.lower()
                                f.write(f"\n[Term]\nid: {tp_id}\nname: {alias_name}\nis_a: {tp_root_id} ! {root_name} ({species_name})\n")                            
            current_page += 1
            print(f"Total {entity_type.capitalize()} Records Printed {records_printed} of {resp_obj['totalResults']}")


def get_entity_name(entity_type, result, mod=None):
    if entity_type == 'gene':
        gene_name = result['geneSymbol']['formatText']
        if mod and mod == 'WB':
            return gene_name.lower()
        return gene_name
    elif entity_type == 'protein':
        ## currently just for WB
        gene_name = result['geneSymbol']['formatText']
        return gene_name.upper()
    elif entity_type == 'allele':
        return result['alleleSymbol']['formatText']
    elif entity_type == 'fish':
        if result['subtype']['name'] != 'fish':
            return None
        return result['name']


def write_obo_file_header(f, tp_root_id, root_name, species_name, now):
    f.write("format-version: 1.2\n")
    f.write(f"date: {now}\n")
    f.write("saved-by: Textpresso\n")
    f.write("auto-generated-by: get_categories.py\n\n")
    f.write("[Term]\n")
    f.write(f"id: {tp_root_id}\n")
    f.write(f"name: {root_name} ({species_name})\n")

def download_all_ontologies(mod):
    urllib.request.urlretrieve("https://current.geneontology.org/ontology/go-basic.obo", "go.obo")
    urllib.request.urlretrieve("https://purl.obolibrary.org/obo/doid.obo", "doid.obo")
    urllib.request.urlretrieve("https://purl.obolibrary.org/obo/chebi.obo", "chebi.obo")
    urllib.request.urlretrieve("https://purl.obolibrary.org/obo/so.obo", "so.obo")

    if mod == 'WB':
        urllib.request.urlretrieve("https://purl.obolibrary.org/obo/wbbt.obo", "wbbt.obo")
        urllib.request.urlretrieve("https://purl.obolibrary.org/obo/wbls.obo", "wbls.obo")
        urllib.request.urlretrieve("https://purl.obolibrary.org/obo/pato.obo", "pato.obo")
        urllib.request.urlretrieve("https://purl.obolibrary.org/obo/wbphenotype.obo", "wbphenotype.obo")
    elif mod == 'ZFIN':
        urllib.request.urlretrieve("https://purl.obolibrary.org/obo/zfa.obo", "zfa.obo")
        urllib.request.urlretrieve("https://purl.obolibrary.org/obo/cl.obo", "cl.obo")
    elif mod == 'MGI':
        urllib.request.urlretrieve("https://purl.obolibrary.org/obo/emapa.obo", "emapa.obo")
        urllib.request.urlretrieve("https://purl.obolibrary.org/obo/ma.obo", "ma.obo")
    elif mod == 'FB':
        urllib.request.urlretrieve("https://purl.obolibrary.org/obo/fbbt/fly_anatomy.obo", "fly_anatomy.obo")
        urllib.request.urlretrieve("https://purl.obolibrary.org/obo/fbdv/fbdv-simple.obo", "fbdv_simple.obo")
        urllib.request.urlretrieve("https://purl.obolibrary.org/obo/fbcv/fbcv-simple.obo", "fbcv_simple.obo")


def get_id_prefix_species_name(mod):
    mod_info = {
        'SGD': ("sc", "S. cerevisiae", "saccharomyces_cerevisiae"),
        'WB': ("ce", "C. elegans", "caenorhabditis_elegans"),
        'MGI': ("mm", "M. musculus", "mus_musculus"),
        'ZFIN': ("dr", "D. rerio", "danio_rerio"),
        'FB': ("dm", "D. melanogaster", "drosophila_melanogaster"),
        'RGD': ("rn", "R. norvegicus", "rattus_norvegicus"),
        'XB': ("xl", "X. laevis", "xenopus_laevis")
    }
    return mod_info.get(mod, ("", "", ""))

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('-m', '--mod', action='store', type=str, help='MOD to dump',
                        choices=['SGD', 'WB', 'FB', 'ZFIN', 'MGI', 'RGD', 'XB'], required=True)
    parser.add_argument('-a', '--all', action='store_true', help="download all ontologies")
    args = parser.parse_args()
    get_category_data(args.mod, args.all)
    
