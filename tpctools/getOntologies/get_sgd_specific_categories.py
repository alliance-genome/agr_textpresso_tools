import requests
import time
species_name = "S. cerevisiae"
protein_url = "http://sgd-archive.yeastgenome.org/latest/Yeast_Proteins.txt"
strain_url = "http://sgd-archive.yeastgenome.org/latest/Yeast_Strains.txt"


def create_obo_file(id_prefix, data_type, filename):

    url = None
    if data_type == 'Protein':
        url = protein_url
    else:
        url = strain_url

    f = open(filename, "w")

    write_header(f, id_prefix, data_type)
    
    index = 0
    try:
        response = requests.get(url)
        if response.status_code == 200:
            records = response.text.split("\n")
            for record in records:
                if record and "\t" in record: 
                    pieces = record.split("\t")
                    name = pieces[1]
                    index += 1
                    f.write(f"\n[Term]\nid: {id_prefix}:{index:07d}\n")
                    f.write(f"name: {name}\n")
                    if len(pieces) >= 3 and pieces[2].strip():
                        synonyms = pieces[2].strip().split('|')
                        for s in synonyms:
                            f.write(f"synonym: \"{s}\" EXACT []\n")
                    f.write(f"is_a: {id_prefix}:0000000 ! {data_type} ({species_name})\n")
        else:
            print(f"Failed to retrieve content. Status code: {response.status_code}")
    except requests.exceptions.RequestException as e:
        print(f"An error occurred: {e}")

    f.close()


def write_header(f, id_prefix, data_type):

    now = time.asctime()
    f.write("format-version: 1.2\n")
    f.write(f"date: {now}\n")
    f.write("saved-by: Textpresso\n")
    f.write("auto-generated-by: get_sgd_specific_categories.py\n\n")

    f.write("[Term]\n")
    f.write(f"id: {id_prefix}:0000000\n")
    f.write(f"name: {data_type} ({species_name})\n")


if __name__ == "__main__":


    create_obo_file('tppsc', 'Protein',
                    "protein_saccharomyces_cerevisiae.obo")
    
    create_obo_file('tpssc', 'Strain',
                    "strain_saccharomyces_cerevisiae.obo")
