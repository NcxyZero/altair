# Kiedy chcesz zrobić pulla mając niescommitowane zmiany
git pull --rebase --autostash

# Jeśli chcesz po prostu mieć stan jak na repo użyj:
# git reset --hard HEAD^
# git rebase --abort
# git stash drop
