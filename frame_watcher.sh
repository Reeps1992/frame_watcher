#!/bin/bash

# Fonction pour réinitialiser le fichier de log
reset_log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Log reset due to application restart" > /var/log/restart_application.log
}

# Fonction pour vérifier et lancer la session screen si elle n'existe pas
check_and_launch_screen() {
    if screen -list | grep -q "\.QUIL"; then
        echo "Screen session 'QUIL' already exists. No need to launch." | tee -a /var/log/restart_application.log
    else
        echo "Screen session 'QUIL' not found. Launching a new screen session..." | tee -a /var/log/restart_application.log
        screen -S QUIL -dm bash -c '/bin/bash ./release_autorun.sh'

        # Vérifier si la commande s'est exécutée correctement
        if [ $? -eq 0 ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Application started successfully in new screen QUIL." | tee -a /var/log/restart_application.log
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Failed to start the application in screen." | tee -a /var/log/restart_application.log
        fi
    fi
}

# Fonction pour extraire la valeur de frame_number de la sortie de la session screen
get_frame_number() {
    # Capture la sortie de la session 'screen' dans un fichier temporaire
    screen -S QUIL -X hardcopy /tmp/screen_output.txt
    # Extrait la valeur de frame_number
    tail -n 100 /tmp/screen_output.txt | grep '"frame_number"' | tail -n 1 | jq '.frame_number'
}

# Fonction pour redémarrer l'application
restart_application() {
    reset_log  # Réinitialiser le fichier de log

    echo "$(date '+%Y-%m-%d %H:%M:%S') - Restarting the application in screen QUIL..." | tee -a /var/log/restart_application.log

    # Vérifier si le processus node existe avant de le tuer
    echo "Checking if node process exists..." | tee -a /var/log/restart_application.log
    pgrep -f "/home/user/ceremonyclient/node/node-2.0.1-linux-amd64" | tee -a /var/log/restart_application.log
    
    echo "Attempting to kill node process..." | tee -a /var/log/restart_application.log
    pkill -f "/home/user/ceremonyclient/node/node-2.0.1-linux-amd64"
    
    # Vérifier si le script autorun existe avant de le tuer
    echo "Checking if autorun script exists..." | tee -a /var/log/restart_application.log
    pgrep -f "/bin/bash ./release_autorun.sh" | tee -a /var/log/restart_application.log
    
    echo "Attempting to kill autorun script..." | tee -a /var/log/restart_application.log
    pkill -f "/bin/bash ./release_autorun.sh"

    sleep 2

    # Redémarrer l'application dans une nouvelle session screen nommée QUIL
    echo "Attempting to restart the application in a new screen session..." | tee -a /var/log/restart_application.log
    screen -S QUIL -dm bash -c '/bin/bash ./release_autorun.sh'

    # Vérifier si la commande s'est exécutée correctement
    if [ $? -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Application restarted successfully in screen QUIL." | tee -a /var/log/restart_application.log
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Failed to restart the application." | tee -a /var/log/restart_application.log
    fi
}

# Fonction pour surveiller l'évolution de frame_number
monitor_frame_number() {
    # Obtenir l'ancienne valeur de frame_number
    local old_frame_number=$(get_frame_number)
    echo "Old frame_number: $old_frame_number" | tee -a /var/log/restart_application.log

    local total_wait=300  # Temps total d'attente en secondes
    local interval=10  # Intervalle en secondes pour afficher le timer

    # Timer qui affiche toutes les 10 secondes le temps restant
    while [ $total_wait -gt 0 ]; do
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Time left before next check: $total_wait seconds" | tee -a /var/log/restart_application.log
        sleep $interval
        total_wait=$((total_wait - interval))
    done

    # Obtenir la nouvelle valeur de frame_number
    local new_frame_number=$(get_frame_number)
    echo "New frame_number: $new_frame_number" | tee -a /var/log/restart_application.log

    # Si frame_number n'a pas changé, redémarrer l'application
    if [ "$old_frame_number" == "$new_frame_number" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - frame_number hasn't changed in 300 seconds. Restarting application." | tee -a /var/log/restart_application.log
        restart_application
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - frame_number is increasing. No restart needed." | tee -a /var/log/restart_application.log
    fi
}

# Vérifier au démarrage si la session screen existe, sinon la lancer
check_and_launch_screen

# Boucle infinie pour surveiller en permanence
while true; do
    monitor_frame_number
done
