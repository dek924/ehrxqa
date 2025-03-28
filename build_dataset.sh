#!/bin/bash

# Capture the start time
start_time=$(date +%s)

# Read username and password (for PhysioNet)
read -p "Username: " USERNAME
read -s -p "Password: " PASSWORD

# Define directories and file names
MIMIC_CXR="https://physionet.org/files/mimic-cxr-jpg/2.0.0"
CHEST_IMAGENOME_BASE="https://physionet.org/files/chest-imagenome/1.0.0"
CHEST_IMAGENOME_SILVER="${CHEST_IMAGENOME_BASE}/silver_dataset"
CHEST_IMAGENOME_GOLD="$CHEST_IMAGENOME_BASE/gold_dataset"
CHEST_IMAGENOME_UTILS="$CHEST_IMAGENOME_BASE/utils/scene_postprocessing"
CHEST_IMAGENOME_SEMANTICS="$CHEST_IMAGENOME_BASE/semantics"
MIMIC_IV="https://physionet.org/files/mimiciv/2.2"

# Define wget parameters for readability
WGET_PARAMS="-r -N -c -np --user $USERNAME --password $PASSWORD"

# Helper function to download and extract files
download_and_extract() {
    local file_url=$1
    local destination_dir=$2
    local file_name=$(basename "$file_url")

    # Download the file
    wget $WGET_PARAMS "$file_url"

    # Extract if it's a zip file
    if [[ "$file_name" == *.zip ]]; then
        unzip -o "$destination_dir/$file_name" -d "$destination_dir" # -o: overwrite
    fi

    # Extract if it's a gzip file
    if [[ "$file_name" == *.gz ]]; then
        gzip -d "$destination_dir/$file_name"
    fi
}

# Download MIMIC-CXR metadata
download_and_extract "$MIMIC_CXR/mimic-cxr-2.0.0-metadata.csv.gz" "physionet.org/files/mimic-cxr-jpg/2.0.0"

# Download Chest Imagenome files
download_and_extract "$CHEST_IMAGENOME_SILVER/scene_graph.zip" "physionet.org/files/chest-imagenome/1.0.0/silver_dataset"
download_and_extract "$CHEST_IMAGENOME_GOLD/gold_attributes_relations_500pts_500studies1st.txt" "physionet.org/files/chest-imagenome/1.0.0/gold_dataset"
download_and_extract "$CHEST_IMAGENOME_GOLD/gold_bbox_coordinate_annotations_1000images.csv" "physionet.org/files/chest-imagenome/1.0.0/gold_dataset"
download_and_extract "$CHEST_IMAGENOME_UTILS/scenegraph_postprocessing.py" "physionet.org/files/chest-imagenome/1.0.0/utils/scene_postprocessing"
download_and_extract "$CHEST_IMAGENOME_SEMANTICS/attribute_relations_v1.txt" "physionet.org/files/chest-imagenome/1.0.0/semantics"
download_and_extract "$CHEST_IMAGENOME_SEMANTICS/label_to_UMLS_mapping.json" "physionet.org/files/chest-imagenome/1.0.0/semantics"
download_and_extract "$CHEST_IMAGENOME_SEMANTICS/objects_extracted_from_reports_v1.txt" "physionet.org/files/chest-imagenome/1.0.0/semantics"

# Download MIMIC-IV hosp modules
download_and_extract "$MIMIC_IV/hosp/admissions.csv.gz" "physionet.org/files/mimiciv/2.2/hosp"
download_and_extract "$MIMIC_IV/hosp/diagnoses_icd.csv.gz" "physionet.org/files/mimiciv/2.2/hosp"
download_and_extract "$MIMIC_IV/hosp/d_icd_diagnoses.csv.gz" "physionet.org/files/mimiciv/2.2/hosp"
download_and_extract "$MIMIC_IV/hosp/d_icd_procedures.csv.gz" "physionet.org/files/mimiciv/2.2/hosp"
download_and_extract "$MIMIC_IV/hosp/d_labitems.csv.gz" "physionet.org/files/mimiciv/2.2/hosp"
download_and_extract "$MIMIC_IV/hosp/labevents.csv.gz" "physionet.org/files/mimiciv/2.2/hosp"
download_and_extract "$MIMIC_IV/hosp/microbiologyevents.csv.gz" "physionet.org/files/mimiciv/2.2/hosp"
download_and_extract "$MIMIC_IV/hosp/patients.csv.gz" "physionet.org/files/mimiciv/2.2/hosp"
download_and_extract "$MIMIC_IV/hosp/prescriptions.csv.gz" "physionet.org/files/mimiciv/2.2/hosp"
download_and_extract "$MIMIC_IV/hosp/procedures_icd.csv.gz" "physionet.org/files/mimiciv/2.2/hosp"
download_and_extract "$MIMIC_IV/hosp/transfers.csv.gz" "physionet.org/files/mimiciv/2.2/hosp"

# Download MIMIC-IV icu modules
download_and_extract "$MIMIC_IV/icu/chartevents.csv.gz" "physionet.org/files/mimiciv/2.2/icu"
download_and_extract "$MIMIC_IV/icu/d_items.csv.gz" "physionet.org/files/mimiciv/2.2/icu"
download_and_extract "$MIMIC_IV/icu/icustays.csv.gz" "physionet.org/files/mimiciv/2.2/icu"
download_and_extract "$MIMIC_IV/icu/inputevents.csv.gz" "physionet.org/files/mimiciv/2.2/icu"
download_and_extract "$MIMIC_IV/icu/outputevents.csv.gz" "physionet.org/files/mimiciv/2.2/icu"

# Save currentdirectory
orig_dir=$(pwd)

# Change directory and run python script
if [ ! -f "physionet.org/files/chest-imagenome/1.0.0/silver_dataset/scene_tabular/attribute_relations_tabular.txt" ] || [ ! -f "physionet.org/files/chest-imagenome/1.0.0/silver_dataset/scene_tabular/bbox_objects_tabular.txt" ]; then
    cd "physionet.org/files/chest-imagenome/1.0.0/utils/scene_postprocessing"

    echo '{
        "SCENE_DIR": "../../silver_dataset/scene_graph",
        "OUTPUT_DIR": "../../silver_dataset/scene_tabular",
        "OUTPUT_TYPE": ["attributes", "objects"],
        "RDF_LEVEL": "study_id",
        "RESOURCE": "../../semantics/label_to_UMLS_mapping.json",
        "AGGREGATION": "last",
        "INCLUDE_SECTIONS": "all"
    }' > scenegraph_postprocessing_settings.json
    python scenegraph_postprocessing.py
    echo "Done with scene postprocessing"
fi

# Return to the original directory
cd "$orig_dir"

# Preprocessing and generate dataset
SAVE_DIR="dataset_builder/preprocessed_data/"
PREPROCESS_SCRIPTS=("preprocess_cohort.py" "preprocess_label.py")
SPLITS=("train" "valid" "test")

mkdir -p "$SAVE_DIR"

for split in "${SPLITS[@]}"; do
    if [ ! -f "${SAVE_DIR}/${split}_dataset.csv" ]; then
        for script in "${PREPROCESS_SCRIPTS[@]}"; do
            python "dataset_builder/${script}" \
                --mimic_cxr_jpg_dir "physionet.org/files/mimic-cxr-jpg/2.0.0/" \
                --chest_imagenome_dir "physionet.org/files/chest-imagenome/1.0.0/" \
                --save_dir "$SAVE_DIR"
        done
    fi
done

# DB preprocessing code
declare -A splits=( ["test"]=400 ["train"]=800 )  # Array of splits and their corresponding number of patients

for split in "${!splits[@]}"; do
    num_patient=${splits[$split]}
    
    echo "Processing $split split with $num_patient patients..."
    
    python dataset_builder/preprocess_db.py \
    --split "$split" \
    --mimic_iv_dir "physionet.org/files/mimiciv/2.2/" \
    --mimic_cxr_jpg_dir "physionet.org/files/mimic-cxr-jpg/2.0.0/" \
    --chest_imagenome_dir "physionet.org/files/chest-imagenome/1.0.0/" \
    --db_name mimic_iv_cxr \
    --out_dir "./database" \
    --deid \
    --timeshift \
    --current_time "2105-12-31 23:59:00" \
    --start_year 2100 \
    --time_span 5 \
    --cur_patient_ratio 0.1 \
    --num_patient $num_patient
done

echo "Database preprocessing complete."

# Answer generation code
for split in "${SPLITS[@]}"; do
    python dataset_builder/generate_answer.py \
        --mimic_iv_dir "physionet.org/files/mimiciv/2.2/" \
        --mimic_cxr_jpg_dir "physionet.org/files/mimic-cxr-jpg/2.0.0/" \
        --chest_imagenome_dir "physionet.org/files/chest-imagenome/1.0.0/" \
        --json_file_path "dataset/mimic_iv_cxr/_${split}.json" \
        --db_file_path "database/mimic_iv_cxr/${split}/mimic_iv_cxr.db" \
        --output_path "dataset/mimic_iv_cxr/${split}.json"
done

# Capture the end time
end_time=$(date +%s)

# Calculate the runtime
runtime=$((end_time - start_time))

# Display the runtime
echo "Script runtime: $runtime seconds"