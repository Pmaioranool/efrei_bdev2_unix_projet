#!/bin/bash

# Création des logs
mkdir -p logs
echo "" >logs/process_suspects.log

# Récupération des informations sur les processus
ps aux | awk '{print $1, $2, $3, $9, $10, $11}' | while read -r user pid cpu start time name; do
    if [[ "$cpu" =~ ^[0-9]+([.][0-9]+)?$ ]] && [[ "$time" =~ ^([0-5]?[0-9]):([0-5][0-9])$ ]]; then
        if (($(echo "$cpu > 80" | bc -l))); then
            min=$(echo $time | awk -F: '{print $1}')
            sec=$(echo $time | awk -F: '{print $2}')
            total_time=$((min * 60 + sec))
            if ((total_time > 1)); then
                echo "anomalie $start, nom: $name, pid: $pid, utilisateur: $user, $cpu utilisé pendant $time" >>logs/process_suspects.log
            fi
        fi
    fi

    if [[ "$user" == "non_autorisé" ]]; then
        echo "anomalie $start, nom: $name, pid: $pid, utilisateur: $user, utilisateur non autorisé" >>logs/process_suspects.log
    fi
done

# Lecture des anomalies et traitement
while IFS= read -r line; do
    echo "Traitement de la ligne : $line" # Debug
    if [[ $line =~ anomalie\ ([0-9]{2}:[0-9]{2}),\ nom:\ ([^,]+),\ pid:\ ([0-9]+),\ utilisateur:\ ([^,]+),\ ([0-9]+(\.[0-9]+)?)\ utilisé\ pendant\ ([0-9]+):([0-9]{2}) ]]; then
        start="${BASH_REMATCH[1]}"
        name="${BASH_REMATCH[2]}"
        pid="${BASH_REMATCH[3]}"
        user="${BASH_REMATCH[4]}"
        cpu="${BASH_REMATCH[5]}"
        minutes="${BASH_REMATCH[7]}"

        # Affichage des informations
        echo "Utilisateur: $user"      # Debug
        echo "PID: $pid"               # Debug
        echo "CPU: $cpu%"              # Debug
        echo "Démarrage: $start"       # Debug
        echo "Durée: $minutes minutes" # Debug
        # Boucle pour gérer le choix de l'utilisateur
        while true; do
            echo "Choisissez une action :"
            echo "1. Tuer le processus"
            echo "2. Baisser la priorité"
            echo "3. Ignorer"
            read -r -p "Entrez votre choix (1/2/3): " choice </dev/tty

            echo "$choice"

            case "$choice" in
            1)
                echo "Vous avez choisi de tuer le processus $pid."
                kill "$pid" 2>/dev/null || echo "Erreur lors de la tentative de tuer le processus $pid."
                true
                break # Sortir de la boucle après l'action
                ;;
            2)
                echo "Vous avez choisi de baisser la priorité du processus $pid."
                renice 10 "$pid" 2>/dev/null || echo "Erreur lors de la tentative de baisser la priorité du processus $pid."
                true
                break
                ;;
            3)
                echo "Vous avez choisi d'ignorer."
                false
                break
                ;;
            *)
                echo "Choix invalide. Veuillez réessayer."
                true
                ;; # Rester dans la boucle pour redemander le choix
            esac
        done
    else
        echo "Ligne non reconnue : $line" # Debug
        continue
    fi
done <logs/process_suspects.log

# Date actuelle
date=$(date +"%Y-%m-%d %H:%M:%S")

# Compte d'anomalies
anomalies=$(grep "anomalie" logs/process_suspects.log | wc -l)

# Top 10 des processus consommateurs de CPU
top_processes=$(ps aux --sort=-%cpu | head -n 10)

# Création du rapport quotidien
{
    echo "Rapport quotidien - $date"
    echo "Nombre d'anomalies détectées : $anomalies"
    echo "Top 10 des processus consommant le plus de CPU :"
    echo "$top_processes"
    echo "---------------------------------------------"
} >>logs/daily_report.log
