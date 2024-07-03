import json
import sys
from collections import defaultdict

def extract_public_api(api_json_path, output_json_path):
    with open(api_json_path, 'r') as file:
        data = json.load(file)
    
    api_structure = defaultdict(list)

    def traverse(item, current_context=None):
        if isinstance(item, dict):
            # Update context if the item is a public class, struct, or enum
            if 'key.kind' in item and item['key.kind'] in {'source.lang.swift.decl.class', 'source.lang.swift.decl.struct', 'source.lang.swift.decl.enum'}:
                if item.get('key.accessibility') == 'source.lang.swift.accessibility.public':
                    current_context = item.get('key.name', 'Unnamed Context')
                else:
                    current_context = None  # Reset context if not public

            # Check if item is a public function declaration
            if current_context and 'key.kind' in item and item['key.kind'].startswith('source.lang.swift.decl.function') and item.get('key.accessibility') == 'source.lang.swift.accessibility.public':
                function_info = {'name': item.get('key.name', 'Unnamed Function'), 'declaration': item.get('key.parsed_declaration', 'unknown declaration') }
                api_structure[current_context].append(function_info)
            
            # Recursively handle nested structures
            for key in item:
                traverse(item[key], current_context)
        elif isinstance(item, list):
            for sub_item in item:
                traverse(sub_item, current_context)

    traverse(data)
    
    # Convert defaultdict to a regular list of dictionaries
    api_list = [{'className': class_name, 'apiFunctions': functions} for class_name, functions in api_structure.items()]
    # Output the result as a JSON document
    with open(output_json_path, 'w') as outfile:
        json.dump(api_list, outfile, indent=2)

    print(f"Extracted public API. Output written to {output_json_path}")



if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python extract_public_api.py <input_api.json> <output_public_api.json>")
        sys.exit(1)

    input_api_json = sys.argv[1]
    output_public_api_json = sys.argv[2]

    extract_public_api(input_api_json, output_public_api_json)
