# git bashem wywołujcie ten skrypt
projects=$(find . -maxdepth 1 -iname "*.project.json" -exec basename {} .project.json \;)
project_count=$(echo "$projects" | wc -l)

if [ -z "$projects" ]; then
    echo -e "\e[31mNie znaleziono żadnego pliku projektu!\e[0m"
    exit 1
elif [ $project_count -eq 1 ]; then
    project=$(echo "$projects")
    echo "Automatyczne uruchamianie jedynego projektu: $project"
    rojo sourcemap "$project.project.json" > sourcemap.json
    rojo serve "$project.project.json"
    exit 0
elif [ $# -eq 0 ]; then
    echo -e "\e[31mNie podałeś nazwy pliku projektu!\e[0m"
    echo -e "Użycie: bash serve.sh projekt\n"
    echo "Możliwe projekty: "
    echo "$projects"
    exit 1
fi

rojo sourcemap "$1.project.json" > sourcemap.json
rojo serve "$1.project.json"
