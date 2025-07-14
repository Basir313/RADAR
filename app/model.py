import logging
import config
import datetime
from elasticsearch import Elasticsearch
import classes

LOGGER : logging.Logger = None
ELASTIC : Elasticsearch = None
SAP_HANA : classes.SAP_HANA = None


def init_elasticsearch() -> Elasticsearch:
    """ Inizializza la connessione a Elasticsearch.

    Raises:
        ConnectionError: Se la connessione a Elasticsearch non è riuscita.

    Returns:
        Elasticsearch: L'istanza della connessione a Elasticsearch.
    """

    global ELASTIC

    ELASTIC = Elasticsearch(
        config.ELASTIC_HOST,
        basic_auth=(config.ELASTIC_USERNAME, config.ELASTIC_PASSWORD),
        verify_certs=False,  # Disabilita la verifica del certificato SSL (non consigliato in produzione)
        request_timeout=30,  # Aumenta il timeout
        retry_on_timeout=True,
        max_retries=3
    )

    if not ELASTIC.ping():
        LOGGER.error("Elasticsearch connection failed")
        raise ConnectionError("Could not connect to Elasticsearch")

    elastic_info = ELASTIC.info()
    LOGGER.debug(f"Elasticsearch info: {elastic_info}")
    if 'version' in elastic_info:
        LOGGER.info(f"Elasticsearch version: {elastic_info['version']['number']}")
    else:
        LOGGER.warning("Elasticsearch version information not found in response")

    return ELASTIC


def init_sap_hana() -> classes.SAP_HANA:
    """ Inizializza la connessione a SAP HANA.

    Returns:
        classes.SAP_HANA: L'istanza della connessione a SAP HANA.
    """

    global SAP_HANA

    SAP_HANA = classes.SAP_HANA(
        host = config.SAP_HANA_HOST,
        port = config.SAP_HANA_PORT,
        user = config.SAP_HANA_USER,
        password = config.SAP_HANA_PASSWORD
    )
    SAP_HANA.connect()

    return SAP_HANA


def execute_master_query() -> list:
    """ Esegue la query master su SAP HANA.
    Raises:
        ConnectionError: Se la connessione a SAP HANA non è stata inizializzata.
    Returns:
        list: Una lista di dizionari contenenti i risultati della query master.
    """

    if not SAP_HANA:
        raise ConnectionError("SAP HANA connection not initialized")

    try:
        # Eseguo la query master
        results = SAP_HANA.execute(config.SAP_HANA_MASTER_QUERY)
        LOGGER.info(f"Master query executed successfully, retrieved {len(results)} records")
        return results
    except Exception as e:
        LOGGER.error(f"Error executing master query: {e}")
        raise


def execute_child_query(row: dict) -> tuple:
    """ Esegue la query figlia su SAP HANA per un dato record.

    Args:
        row (dict): Il record da cui estrarre i parametri per la query figlia.

    Raises:
        ConnectionError: Se la connessione a SAP HANA non è stata inizializzata.

    Returns:
        tuple: Un tuple contenente il codice, il nome e i risultati della query figlia.
    """

    if not SAP_HANA:
        raise ConnectionError("SAP HANA connection not initialized")

    code = row.get("Code", None)
    name = row.get("Name", None)
    query = row.get("U_KAI_FUNCTION", None)

    assert code is not None, "CODE cannot be None"
    assert name is not None, "NAME cannot be None"
    assert query is not None, "U_KAI_FUNCTION cannot be None"
    
    LOGGER.info(f"Executing child query {query!r} for CODE: {code!r}, NAME: {name!r}")
    try:
        # Eseguo la query figlia
        results = SAP_HANA.execute(query)
        LOGGER.info(f"Child query executed successfully for CODE: {code!r}, NAME: {name!r}, retrieved {len(results)} records")
        return code, name, results
    except Exception as e:
        LOGGER.error(f"Error executing child query for CODE: {code!r}, NAME: {name!r}: {e}")
        raise


def upsert_to_elasticsearch(child_results: tuple) -> None:
    """ Inserisce o aggiorna i risultati della query figlia in Elasticsearch.

    Args:
        child_results (tuple): Un tuple contenente il codice, il nome e i risultati della query figlia.
    
    Raises:
        Exception: Se non viene trovata una chiave comune per identificare i documenti.
        ConnectionError: Se la connessione a Elasticsearch non è stata inizializzata.
    """

    if not ELASTIC:
        raise ConnectionError("Elasticsearch connection not initialized")

    # Code rappresenta l'indice dei risultati
    # Name invece rappresenta la versione leggibile agli umani dell'indice
    # Results è la lista dei risultati della query figlia da upsertare su Elasticsearch
    code, name, results = child_results
    code = code.lower()  # Assicuro che il codice sia in minuscolo per coerenza con gli indici Elasticsearch
    
    if not results:
        LOGGER.warning(f"No results to upsert for CODE: {code!r}, NAME: {name!r}")
        return
    
    # Creo l'indice con metadati se non esiste
    try:
        if not ELASTIC.indices.exists(index=code):
            create_index_with_metadata(
                index_name=code,
                display_name=name,
                custom_metadata={
                    "sap_code": code.upper(),
                    "last_sync": datetime.datetime.now().isoformat(),
                    "record_count": len(results),
                    "data_source": "SAP HANA Child Query"
                }
            )
        else:
            # Aggiorno i metadati dell'indice esistente
            update_index_metadata(code, {
                "last_sync": datetime.datetime.now().isoformat(),
                "record_count": len(results)
            })
    except Exception as e:
        LOGGER.error(f"Error managing index {code}: {e}")
        # Continuo comunque con l'upsert anche se i metadati falliscono
    
    # Preparo i documenti da upsertare
    actions = []
    # Per trovare l'identificativo univoco di ogni documento, cerco un campo che contenga "Code"
    common_key = None
    
    for result in results:
        # Identifico la chiave comune che contiene "Code"
        if common_key is None:
            common_key = next((key for key in result if "Code" in key), None)
            if common_key:
                LOGGER.debug(f"Using common key: {common_key!r} for CODE: {code!r}, NAME: {name!r}")
        
        if common_key is None:
            raise Exception(f"No common key found in results for CODE: {code!r}, NAME: {name!r}")
        
        # Verifico che il documento abbia effettivamente la chiave identificativa
        if common_key not in result:
            LOGGER.warning(f"Document missing key {common_key!r} for CODE: {code!r}, NAME: {name!r}, skipping")
            continue
        
        # Preparo le operazioni per il bulk API (formato NDJSON alternato: azione, documento)
        actions.append({
            "update": {
                "_index": code,
                "_id": str(result[common_key])  # Converto in stringa per sicurezza
            }
        })
        actions.append({
            "doc": result,
            "doc_as_upsert": True
        })

    try:
        # Eseguo il bulk upsert usando il parametro 'operations'
        if actions:
            response = ELASTIC.bulk(
                operations=actions,
                refresh='wait_for',  # Attendo che i documenti siano visibili per la ricerca
                timeout='30s',       # Timeout per l'operazione
                request_timeout=60   # Timeout per la richiesta HTTP
            )
            
            if response.get('errors', False):
                # Log dettagliato degli errori
                error_items = [item for item in response.get('items', []) 
                             if 'update' in item and item['update'].get('error')]
                LOGGER.error(f"Errors occurred during bulk upsert for CODE: {code!r}, NAME: {name!r}")
                for error_item in error_items:
                    error_detail = error_item['update']['error']
                    LOGGER.error(f"Error details: {error_detail}")
            else:
                successful_ops = len([item for item in response.get('items', []) 
                                    if 'update' in item and item['update'].get('result') in ['created', 'updated']])
                LOGGER.info(f"Successfully upserted {successful_ops} documents to index {code} for NAME: {name!r}")
                LOGGER.debug(f"Bulk operation took {response.get('took', 0)}ms")
        else:
            LOGGER.warning(f"No valid actions to perform for CODE: {code!r}, NAME: {name!r}")
            
    except Exception as e:
        LOGGER.error(f"Error during bulk upsert for CODE: {code!r}, NAME: {name!r}: {e}")
        raise


def search(index: str, query: dict) -> list:
    """ Esegue una ricerca su un indice specifico in Elasticsearch.

    Args:
        index (str): Il nome dell'indice su cui eseguire la ricerca.
        query (dict): Il corpo della query di ricerca.

    Returns:
        list: I risultati della ricerca.
        
    Raises:
        ConnectionError: Se la connessione a Elasticsearch non è stata inizializzata.
    """
    
    if not ELASTIC:
        raise ConnectionError("Elasticsearch connection not initialized")

    try:
        # In Elasticsearch v8, usa direttamente i parametri invece di 'body'
        response = ELASTIC.search(index=index, **query)
        return response.get('hits', {}).get('hits', [])
    except Exception as e:
        LOGGER.error(f"Error executing search on index {index}: {e}")
        raise


def create_index_with_metadata(index_name: str, display_name: str, custom_metadata: dict = None) -> None:
    """Crea un indice con metadati custom.
    
    Args:
        index_name (str): Nome dell'indice
        display_name (str): Nome leggibile dell'indice  
        custom_metadata (dict): Metadati aggiuntivi
        
    Raises:
        ConnectionError: Se la connessione a Elasticsearch non è stata inizializzata.
    """
    
    if not ELASTIC:
        raise ConnectionError("Elasticsearch connection not initialized")
    
    # Preparo i metadati di base
    metadata = {
        "display_name": display_name,
        "created_at": datetime.datetime.now().isoformat(),
        "created_by": "SAP-Elastic-App",
        "source": "SAP-HANA"
    }
    
    # Aggiungo metadati custom se forniti
    if custom_metadata:
        metadata.update(custom_metadata)
    
    # Configurazione dell'indice con metadati
    index_body = {
        "settings": {
            "index": {
                "number_of_shards": 1,
                "number_of_replicas": 0
            }
        },
        "mappings": {
            "properties": {
                # Mapping dinamico per gestire automaticamente i tipi di campo
            },
            "_meta": metadata
        }
    }
    
    try:
        if not ELASTIC.indices.exists(index=index_name):
            ELASTIC.indices.create(index=index_name, body=index_body)
            LOGGER.info(f"Index {index_name} created with metadata: {metadata}")
        else:
            LOGGER.debug(f"Index {index_name} already exists")
    except Exception as e:
        LOGGER.error(f"Error creating index {index_name}: {e}")
        raise


def get_index_metadata(index_name: str) -> dict:
    """Recupera i metadati di un indice.
    
    Args:
        index_name (str): Nome dell'indice
        
    Returns:
        dict: Metadati dell'indice, dizionario vuoto se non trovati
        
    Raises:
        ConnectionError: Se la connessione a Elasticsearch non è stata inizializzata.
    """
    
    if not ELASTIC:
        raise ConnectionError("Elasticsearch connection not initialized")
    
    try:
        mappings = ELASTIC.indices.get_mapping(index=index_name)
        metadata = mappings.get(index_name, {}).get('mappings', {}).get('_meta', {})
        return metadata
    except Exception as e:
        LOGGER.error(f"Error retrieving metadata for index {index_name}: {e}")
        return {}


def update_index_metadata(index_name: str, new_metadata: dict) -> None:
    """Aggiorna i metadati di un indice esistente.
    
    Args:
        index_name (str): Nome dell'indice
        new_metadata (dict): Nuovi metadati da aggiungere/aggiornare
        
    Raises:
        ConnectionError: Se la connessione a Elasticsearch non è stata inizializzata.
    """
    
    if not ELASTIC:
        raise ConnectionError("Elasticsearch connection not initialized")
    
    try:
        # Recupero i metadati esistenti
        current_metadata = get_index_metadata(index_name)
        
        # Unisco i metadati esistenti con quelli nuovi
        current_metadata.update(new_metadata)
        current_metadata["last_updated"] = datetime.datetime.now().isoformat()
        
        # Aggiorno i metadati tramite put_mapping
        mapping_body = {
            "_meta": current_metadata
        }
        
        ELASTIC.indices.put_mapping(index=index_name, body=mapping_body)
        LOGGER.info(f"Metadata updated for index {index_name}: {new_metadata}")
        
    except Exception as e:
        LOGGER.error(f"Error updating metadata for index {index_name}: {e}")
        raise


def list_indices_with_metadata() -> dict:
    """Lista tutti gli indici con i loro metadati.
    
    Returns:
        dict: Dizionario con indici e relativi metadati
        
    Raises:
        ConnectionError: Se la connessione a Elasticsearch non è stata inizializzata.
    """
    
    if not ELASTIC:
        raise ConnectionError("Elasticsearch connection not initialized")
    
    try:
        indices = ELASTIC.cat.indices(format="json")
        result = {}
        
        for index_info in indices:
            index_name = index_info['index']
            # Escludo indici di sistema che iniziano con '.'
            if not index_name.startswith('.'):
                metadata = get_index_metadata(index_name)
                result[index_name] = {
                    'metadata': metadata,
                    'docs_count': int(index_info.get('docs.count', 0)) if index_info.get('docs.count') != 'null' else 0,
                    'size': index_info.get('store.size', '0b'),
                    'health': index_info.get('health', 'unknown'),
                    'status': index_info.get('status', 'unknown')
                }
        
        return result
    except Exception as e:
        LOGGER.error(f"Error listing indices: {e}")
        return {}


def get_index_display_name(index_name: str) -> str:
    """Recupera il nome leggibile di un indice dai suoi metadati.
    
    Args:
        index_name (str): Nome dell'indice
        
    Returns:
        str: Nome leggibile dell'indice, o il nome originale se non trovato
    """
    
    try:
        metadata = get_index_metadata(index_name)
        return metadata.get('display_name', index_name)
    except Exception as e:
        LOGGER.error(f"Error getting display name for index {index_name}: {e}")
        return index_name