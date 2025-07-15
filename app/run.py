import config
import model
import classes

import logging
import logging.handlers
import os
import sys

from icecream import ic as print


# ----------------
# Gestione logger
# ----------------

LOGGER : logging.Logger = None

def init_logger() -> None:
    """Funzione che inizializza il logger
    """

    global LOGGER

    if not os.path.exists("./logs"):
        os.mkdir("./logs")

    LOGGER = logging.getLogger(config.APP_NAME)
    LOGGER.setLevel(config.LOG_LEVEL)
    formatter = logging.Formatter("%(asctime)s - {%(filename)s:%(lineno)d} - %(levelname)s - %(message)s", "%Y-%m-%d %H:%M:%S")
    logHandler = logging.handlers.TimedRotatingFileHandler(
        "./logs/Log.log",
        when="D",
        interval=1,
        encoding="utf-8"
    )
    logHandler.setLevel(config.LOG_LEVEL)
    logHandler.setFormatter(formatter)
    LOGGER.addHandler(logHandler)

    def handle_exception(exc_type, exc_value, exc_traceback):
        if issubclass(exc_type, KeyboardInterrupt):
            sys.__excepthook__(exc_type, exc_value, exc_traceback)
            return

        LOGGER.error("Uncaught exception", exc_info=(exc_type, exc_value, exc_traceback))

        """# Ottengo il template della mail
        MAIL_TEMPLATE = Model.get_mail_template("alert")

        # Prepara il corpo della mail
        mail_body = MAIL_TEMPLATE.format(
            alert_msg_primary=f"Si è verificato un errore non gestito: <strong>{exc_value}</strong>",
            alert_msg_secondary="Vedere il file Log.log allegato per maggiori informazioni"
        )

        GRAPH.send_mail(
            subject=f"Alert errore non gestito: {config.APP_NAME}",
            body=mail_body,
            mail_recipients=config.DEVELOPMENT_MAIL,
            attachment=("Log.log", "./logs/Log.log")
        )"""

        sys.exit(1)

    sys.excepthook = handle_exception
    
    # Aggiungo un handler per il log su console
    consoleHandler = logging.StreamHandler()
    consoleHandler.setLevel(config.LOG_LEVEL)
    consoleHandler.setFormatter(formatter)
    LOGGER.addHandler(consoleHandler)

    # Inizializzo gli oggetti globali
    model.LOGGER = LOGGER
    classes.LOGGER = LOGGER

    return



def main():
    """Funzione principale che inizializza il logger e gli oggetti globali
    """

    init_logger()
    LOGGER.info("Logger initialized successfully")

    # Inizializzo Elasticsearch
    model.init_sap_hana()
    model.init_elasticsearch()

    # Eseguo la query master su SAP HANA
    results = model.execute_master_query()
    for row in results:
        child_results = model.execute_child_query(row)
        model.upsert_to_elasticsearch(child_results)

if __name__ == "__main__":
    main()