#!/bin/bash

# Script per avviare il container radar-backend in modalità incrementale
# Richiama l'API REST del frontend RADAR

# Configurazione
FRONTEND_HOST="radar.eurotec.loc"
FRONTEND_PORT="443"
API_ENDPOINT="/api/container/start"
BASE_URL="https://${FRONTEND_HOST}:${FRONTEND_PORT}${API_ENDPOINT}"

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funzione per stampare messaggi colorati
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Funzione per verificare che il frontend sia raggiungibile
check_frontend() {
    print_info "Verifico che il frontend RADAR sia raggiungibile su ${FRONTEND_HOST}:${FRONTEND_PORT}..."
    
    if ! curl -s --connect-timeout 5 "http://${FRONTEND_HOST}:${FRONTEND_PORT}/" > /dev/null; then
        print_error "Frontend RADAR non raggiungibile su ${FRONTEND_HOST}:${FRONTEND_PORT}"
        print_error "Assicurati che il frontend sia avviato e accessibile"
        exit 1
    fi
    
    print_success "Frontend RADAR raggiungibile"
}

# Funzione per avviare il container in modalità incrementale
start_incremental_container() {
    print_info "Avvio container radar-backend in modalità INCREMENTALE..."
    
    # Prepara il payload JSON per la modalità incrementale
    local payload=$(cat <<EOF
{
    "environment": {
        "UPDATE_MODE": "INCREMENTAL",
        "EXECUTION_TIME": "$(date --iso-8601=seconds)"
    }
}
EOF
)
    
    print_info "Invio richiesta all'API: ${BASE_URL}"
    print_info "Payload: ${payload}"
    
    # Effettua la chiamata API
    local response=$(curl -k -s -w "\n%{http_code}" \
        -H "Content-Type: application/json" \
        -X POST \
        -d "${payload}" \
        "${BASE_URL}")
    
    # Estrae il codice di stato HTTP
    local http_code=$(echo "${response}" | tail -n1)
    local response_body=$(echo "${response}" | head -n -1)
    
    print_info "Codice di risposta HTTP: ${http_code}"
    print_info "Risposta del server:"
    echo "${response_body}" | jq . 2>/dev/null || echo "${response_body}"
    
    # Controlla il risultato
    if [ "${http_code}" = "200" ]; then
        # Analizza la risposta JSON
        local success=$(echo "${response_body}" | jq -r '.success' 2>/dev/null)
        local message=$(echo "${response_body}" | jq -r '.message' 2>/dev/null)
        local container_name=$(echo "${response_body}" | jq -r '.container_name' 2>/dev/null)
        
        if [ "${success}" = "true" ]; then
            print_success "Container avviato con successo!"
            print_success "Nome container: ${container_name}"
            print_success "Messaggio: ${message}"
            return 0
        else
            print_error "Errore nell'avvio del container: ${message}"
            return 1
        fi
    else
        print_error "Errore HTTP ${http_code} nella chiamata API"
        print_error "Risposta del server: ${response_body}"
        return 1
    fi
}

# Funzione per monitorare lo stato del container (opzionale)
monitor_container() {
    local container_name="$1"
    
    if [ -z "${container_name}" ]; then
        print_warning "Nome container non fornito, impossibile monitorare"
        return 0
    fi
    
    print_info "Monitoraggio stato container ${container_name}..."
    
    # Monitora per massimo 5 minuti (300 secondi)
    local max_wait=300
    local elapsed=0
    local check_interval=10
    
    while [ ${elapsed} -lt ${max_wait} ]; do
        # Ottieni lo stato del container
        local status_response=$(curl -s "http://${FRONTEND_HOST}:${FRONTEND_PORT}/api/container/status/${container_name}")
        local container_status=$(echo "${status_response}" | jq -r '.status' 2>/dev/null)
        
        case "${container_status}" in
            "running")
                print_info "Container in esecuzione... (${elapsed}s)"
                ;;
            "exited")
                local exit_code=$(echo "${status_response}" | jq -r '.exit_code' 2>/dev/null)
                if [ "${exit_code}" = "0" ]; then
                    print_success "Container completato con successo (exit code: ${exit_code})"
                else
                    print_error "Container terminato con errore (exit code: ${exit_code})"
                fi
                return ${exit_code}
                ;;
            "error"|"null")
                print_error "Errore nel monitoraggio del container"
                return 1
                ;;
            *)
                print_info "Stato container: ${container_status} (${elapsed}s)"
                ;;
        esac
        
        sleep ${check_interval}
        elapsed=$((elapsed + check_interval))
    done
    
    print_warning "Timeout raggiunto nel monitoraggio (${max_wait}s)"
    return 0
}

# Funzione per fare il prune dei container radar-backend vecchi
prune_old_containers() {
    print_info "Controllo container radar-backend da eliminare (mantengo solo gli ultimi 20)..."
    
    # Ottieni tutti i container radar-backend (running e stopped) ordinati per data di creazione (più recenti prima)
    local containers=$(docker ps -a --filter "ancestor=radar-backend:latest" --format "table {{.ID}}\t{{.Names}}\t{{.CreatedAt}}\t{{.Status}}" --no-trunc | grep -v "CONTAINER ID" | sort -k3 -r)
    
    if [ -z "$containers" ]; then
        print_info "Nessun container radar-backend trovato"
        return 0
    fi
    
    # Conta i container totali
    local total_containers=$(echo "$containers" | wc -l)
    print_info "Trovati ${total_containers} container radar-backend totali"
    
    if [ $total_containers -le 20 ]; then
        print_info "Numero di container (${total_containers}) <= 20, nessun prune necessario"
        return 0
    fi
    
    # Calcola quanti container eliminare
    local containers_to_delete=$((total_containers - 20))
    print_warning "Elimino i ${containers_to_delete} container più vecchi..."
    
    # Ottieni gli ID dei container da eliminare (gli ultimi nella lista ordinata)
    local containers_to_remove=$(echo "$containers" | tail -n $containers_to_delete | awk '{print $1}')
    
    local deleted_count=0
    local failed_count=0
    
    echo "$containers_to_remove" | while read -r container_id; do
        if [ -n "$container_id" ]; then
            local container_info=$(echo "$containers" | grep "$container_id" | head -n1)
            local container_name=$(echo "$container_info" | awk '{print $2}')
            local container_status=$(echo "$container_info" | awk '{print $4}')
            
            print_info "Eliminando container: ${container_name} (${container_id:0:12}) - Status: ${container_status}"
            
            if docker rm -f "$container_id" >/dev/null 2>&1; then
                print_success "✓ Container ${container_name} eliminato"
                ((deleted_count++))
            else
                print_error "✗ Errore nell'eliminazione del container ${container_name}"
                ((failed_count++))
            fi
        fi
    done
    
    # Mostra statistiche finali usando subshell per leggere le variabili
    local final_count=$(docker ps -a --filter "ancestor=radar-backend:latest" --format "{{.ID}}" | wc -l)
    print_success "Prune completato. Container rimanenti: ${final_count}"
    
    if [ $failed_count -gt 0 ]; then
        print_warning "Alcuni container non sono stati eliminati (${failed_count} fallimenti)"
    fi
}

# Funzione per fare il prune anche delle immagini dangling (opzionale)
prune_dangling_images() {
    print_info "Controllo immagini dangling da eliminare..."
    
    local dangling_images=$(docker images -f "dangling=true" -q)
    
    if [ -z "$dangling_images" ]; then
        print_info "Nessuna immagine dangling trovata"
        return 0
    fi
    
    local image_count=$(echo "$dangling_images" | wc -l)
    print_info "Trovate ${image_count} immagini dangling, le elimino..."
    
    if docker rmi $dangling_images >/dev/null 2>&1; then
        print_success "✓ ${image_count} immagini dangling eliminate"
    else
        print_warning "Alcune immagini dangling non sono state eliminate"
    fi
}

# Modifica la funzione principale per includere il prune
main() {
    echo "=================================================="
    echo "   Avvio Container RADAR Backend - INCREMENTALE"
    echo "=================================================="
    echo ""
    
    # Verifica dipendenze
    if ! command -v curl &> /dev/null; then
        print_error "curl non trovato. Installa curl per continuare."
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_warning "jq non trovato. L'output JSON potrebbe non essere formattato correttamente."
    fi
    
    # Verifica che Docker sia disponibile
    if ! command -v docker &> /dev/null; then
        print_error "Docker non trovato. Installa Docker per continuare."
        exit 1
    fi
    
    # Fai il prune dei container vecchi PRIMA di avviare il nuovo
    prune_old_containers
    
    # Opzionalmente, pulisci anche le immagini dangling
    prune_dangling_images
    
    # Verifica che il frontend sia raggiungibile
    check_frontend
    
    # Avvia il container
    start_incremental_container
    local start_result=$?
    
    if [ ${start_result} -eq 0 ]; then
        # Estrae il nome del container dalla risposta precedente se disponibile
        local container_name=$(curl -s -H "Content-Type: application/json" -X POST -d '{"environment":{"UPDATE_MODE":"INCREMENTAL"}}' "${BASE_URL}" | jq -r '.container_name' 2>/dev/null)
        echo ""
        print_info "Per monitorare manualmente il container, visita:"
        print_info "http://${FRONTEND_HOST}:${FRONTEND_PORT}/monitor"
    fi
    
    echo ""
    echo "=================================================="
    exit ${start_result}
}

# Controlla se lo script è stato chiamato direttamente
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi