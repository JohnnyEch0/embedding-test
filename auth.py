import os
from openai import OpenAI
my_api_key = ""
path_to_key = os.path.join(os.path.expanduser("~"), ".tudai-api-key")
if os.path.exists(path_to_key):
    with open(path_to_key) as keyfile:
        my_api_key = keyfile.readline().strip()
if len(my_api_key) < 1:
    print("Error: The key file '.tudai-api-key' did not contain any key. Please make sure the file exists and contains only your API key.")
    exit(1)

client = OpenAI(base_url="https://llm.scads.ai/v1", api_key=my_api_key)
