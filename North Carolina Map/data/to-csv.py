import json
import csv

def convert_json_to_csv(json_path, csv_path):
    """
    Converts the landslide JSON data to a CSV file.
    """
    # Define the column headers for the CSV file
    headers = ["Slope", "Elevation", "Aspect", "PL", "PR", "V", "TWI", "SPI", "TRI"]
    
    # Read the JSON file
    with open(json_path, 'r') as f:
        data = json.load(f)['data']
    
    # The data arrays for the columns start from the second array (index 1)
    # data[0] contains IDs, which are skipped as per the column list.
    # The mapping is: Slope=data[1], Elevation=data[2], ..., TRI=data[10]
    column_data = data[1:10]

    # Transpose the data from columns to rows
    rows = zip(*column_data)
    
    # Write the data to a CSV file
    with open(csv_path, 'w', newline='') as f:
        writer = csv.writer(f)
        # Write the header row
        writer.writerow(headers)
        # Write the data rows
        writer.writerows(rows)
        
    print(f"Successfully converted '{json_path}' to '{csv_path}'")

if __name__ == '__main__':
    convert_json_to_csv('./landslides.json', './landslides.csv')
    convert_json_to_csv('./non-landslides.json', './non-landslides.csv')