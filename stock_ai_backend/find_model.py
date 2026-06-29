import os
def find_file(name, path):
    for root, dirs, files in os.walk(path):
        if name in files:
            return os.path.join(root, name)
    return None
target = "stock_model.h5"
found_path = find_file(target, "D:\\prediction\\stock_ai_backend")
if found_path:
    print(f"FOUND IT! Copy this path exactly: {found_path}")
else:
    print("The file 'stock_model.h5' does not exist in D:\\prediction\\stock_ai_backend")
