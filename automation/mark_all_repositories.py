import os

def mark_directory(name=None):
    current_path = os.getcwd()
    name = name or os.path.basename(current_path)
    bookmark_file = os.path.expanduser("~/.zsh_bookmarks")
    hash_line = f'hash -d {name}="{current_path}"'

    # Check if this name is already saved in the file
    if os.path.exists(bookmark_file):
        with open(bookmark_file, "r") as f:
            if any(f"hash -d {name}=" in line for line in f):
                print(f"⏭️  Skipped: ~{name} is already registered in your bookmarks.")
                return False

    # Append the hash command to the bookmarks file
    with open(bookmark_file, "a") as f:
        f.write(hash_line + "\n")

    # Activate it immediately for the current session (only works if running in a shell)
    os.system(f'hash -d {name}="{current_path}"')

    print(" ✅ Bookmark saved!")
    print(f"    Source: {current_path}")
    print(f"    Usage:  cd ~{name}")
    return True

def is_git_repo(directory):
    return os.path.isdir(os.path.join(directory, '.git'))

def bookmark_git_repos(parent_directories):
    total_added = 0
    total_skipped = 0
    for parent in parent_directories:
        for entry in os.listdir(parent):
            full_path = os.path.join(parent, entry)
            if os.path.isdir(full_path) and is_git_repo(full_path):
                # Use the folder name as the bookmark name
                os.chdir(full_path)
                if mark_directory(name=entry):
                    print(f"Bookmarked: {full_path}")
                    total_added += 1
                else:
                    total_skipped += 1
            else:
                print(f"Not a Git repository: {full_path}")
    print(f"\nSummary: {total_added} added, {total_skipped} skipped.")

if __name__ == "__main__":
    directories_to_check = [
        os.environ.get("REPO_DIR_1"),
        os.environ.get("REPO_DIR_2"),
        os.environ.get("REPO_DIR_3"),
    ]
    bookmark_git_repos(directories_to_check)
