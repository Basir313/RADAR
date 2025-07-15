# RADAR Backend Kubernetes Deployment

Questa cartella contiene tutti i file necessari per deployare l'applicazione RADAR Backend in un ambiente Kubernetes.

## Struttura dei File

- `namespace.yaml` - Crea il namespace dedicato per l'applicazione
- `configmap.yaml` - Contiene le variabili di configurazione non sensibili
- `secret.yaml` - Contiene le credenziali e informazioni sensibili
- `pvc.yaml` - Persistent Volume Claim per i log dell'applicazione
- `rbac.yaml` - Service Account e permessi RBAC
- `service.yaml` - Servizio Kubernetes per esporre l'applicazione
- `deployment.yaml` - Deployment principale dell'applicazione
- `cronjob.yaml` - CronJob per esecuzioni programmate (opzionale)
- `ingress.yaml` - Ingress per accesso esterno (opzionale)
- `deploy.sh` - Script di deployment automatizzato
- `cleanup.sh` - Script per rimuovere tutte le risorse

## Prerequisiti

1. **Cluster Kubernetes** funzionante
2. **kubectl** configurato per accedere al cluster
3. **Docker image** della tua applicazione disponibile nel registry
4. **Ingress Controller** (se vuoi usare l'Ingress)

## Configurazione Richiesta

### 1. Aggiornare le Credenziali

Modifica il file `secret.yaml` e inserisci le tue credenziali:

```bash
# Per codificare le credenziali in base64:
echo -n "your_username" | base64
echo -n "your_password" | base64
```

Oppure usa la sezione `stringData` per inserire i valori in chiaro.

### 2. Aggiornare l'Immagine Docker

Nel file `deployment.yaml` e `cronjob.yaml`, sostituisci:
```yaml
image: radar-backend:latest
```
con il nome e tag della tua immagine Docker effettiva.

### 3. Configurare il Dominio (per Ingress)

Nel file `ingress.yaml`, sostituisci:
```yaml
host: radar-backend.your-domain.com
```
con il tuo dominio effettivo.

## Deployment

### Deployment Automatico

Usa lo script di deployment:

```bash
cd k8s
chmod +x deploy.sh
./deploy.sh
```

### Deployment Manuale

```bash
# 1. Applica i file in ordine
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml
kubectl apply -f pvc.yaml
kubectl apply -f rbac.yaml
kubectl apply -f service.yaml
kubectl apply -f deployment.yaml

# 2. Opzionale: CronJob
kubectl apply -f cronjob.yaml

# 3. Opzionale: Ingress
kubectl apply -f ingress.yaml
```

## Verifica del Deployment

```bash
# Controlla lo stato di tutti i pod
kubectl get pods -n radar-backend

# Controlla i log dell'applicazione
kubectl logs -f deployment/radar-backend -n radar-backend

# Controlla tutti i servizi
kubectl get all -n radar-backend
```

## Caratteristiche

### Sicurezza
- Namespace dedicato per isolamento
- Service Account con permessi RBAC limitati
- Secrets per credenziali sensibili
- ConfigMap per configurazioni non sensibili

### Persistenza
- PVC per salvare i log dell'applicazione
- Volume mount per la cartella `/usr/src/app/logs`

### Monitoraggio
- Liveness probe per riavvio automatico in caso di problemi
- Readiness probe per traffico solo quando l'app è pronta
- Resource limits per gestione risorse

### Scalabilità
- Deployment configurabile per più repliche
- Service per load balancing
- Ingress per accesso esterno

### Scheduling
- CronJob opzionale per esecuzioni programmate
- Configurabile con schedule cron personalizzato

## Personalizzazioni

### Cambiare lo Schedule del CronJob

Modifica il campo `schedule` in `cronjob.yaml`:
```yaml
schedule: "0 */2 * * *"  # Ogni 2 ore
schedule: "0 9 * * *"    # Ogni giorno alle 9:00
schedule: "0 0 * * 0"    # Ogni domenica a mezzanotte
```

### Configurare Resource Limits

Modifica le risorse in `deployment.yaml`:
```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "500m"
  limits:
    memory: "1Gi"
    cpu: "1000m"
```

### Abilitare TLS per Ingress

Decommentare la sezione TLS in `ingress.yaml` e configurare i certificati.

## Troubleshooting

### Pod non si avvia
```bash
kubectl describe pod <pod-name> -n radar-backend
kubectl logs <pod-name> -n radar-backend
```

### Problemi di connettività
```bash
kubectl get endpoints -n radar-backend
kubectl describe service radar-backend-service -n radar-backend
```

### Problemi di storage
```bash
kubectl get pvc -n radar-backend
kubectl describe pvc radar-backend-logs -n radar-backend
```

## Cleanup

Per rimuovere tutte le risorse:

```bash
chmod +x cleanup.sh
./cleanup.sh
```

Oppure manualmente:
```bash
kubectl delete namespace radar-backend
```

## Note Importanti

1. **Backup**: Assicurati di fare backup dei log prima di eliminare il PVC
2. **Secrets**: Non committare mai i secrets con credenziali reali nel repository
3. **Image Registry**: Assicurati che l'immagine Docker sia accessibile dal cluster
4. **Storage Class**: Verifica che la storage class "standard" sia disponibile nel tuo cluster
5. **Ingress Controller**: Assicurati di avere un ingress controller installato se usi l'Ingress
